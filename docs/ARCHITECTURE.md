# Architecture

WardAxis is one multiplatform SwiftUI app (macOS, iOS/iPadOS, tvOS) plus local SwiftPM packages and a management server. The app uses three patterns:

1. **Coordinator** for navigation (`AppCoordinator`)
2. **`@Observable`** for state (no `ObservableObject`)
3. **DI container** for services (`AppContainer`)

Logic that an extension or the future agent must share lives in the `WardAxis*` packages, not in the app target.

---

## Layer diagram

```
        ┌────────────────────────────────────────────────┐
        │        Features (SwiftUI views + VMs)          │
        │  RootView, HomeView, SettingsView, ...         │
        └───────────────┬────────────────────────────────┘
                        │ reads via @Environment
                        ▼
        ┌───────────────────────┐  ┌──────────────────────┐
        │  AppCoordinator       │  │  RouteResolver       │
        │  @Observable          │◀─│  Route → View        │
        │  navigation state     │  │  (no state)          │
        └───────────┬───────────┘  └──────────────────────┘
                    │
                    ▼
        ┌────────────────────────────────────────────────┐
        │           AppContainer   @Observable           │
        │  alertManager · logReaderService ·             │
        │  hapticFeedback · telemetry ·                  │
        │  configurationService                          │
        └───────────────┬────────────────────────────────┘
                        │ each slot is a Sendable protocol
                        ▼
   ┌──────────────────────────┐   ┌───────────────────────────────┐
   │ App services             │   │ Packages                      │
   │ AlertManager             │   │ WardAxisTelemetry             │
   │ LogReaderService         │   │ WardAxisManagement            │
   │ HapticFeedbackService    │   │   └─ WardAxisManagementAPI    │
   └──────────────────────────┘   └───────────────────────────────┘
```

Every arrow points down. Views do not reach into services they do not own. Services do not know which view called them.

---

## Coordinator pattern

[`Source/Shared/Navigation/AppCoordinator.swift`](../Source/Shared/Navigation/AppCoordinator.swift) holds all navigation state. It does not build views.

| State | Purpose |
|---|---|
| `navigationPath` | Push path of the Home tab |
| `settingsNavigationPath` | Push path of the Settings tab |
| `selectedTab` | `.home` or `.settings` |
| `presentedSheet`, `presentedFullScreenCover` | Modal routes |
| `appPhase` | `.splash` or `.main` |
| `tabsWithUnsavedChanges`, `blockedTabSwitch` | A tab with unsaved changes holds a tab switch until it confirms |

Main methods: `navigate(to:presentation:)`, `push(_:in:)`, `pop(in:)`, `popToRoot(in:)`, `present(_:)`, `presentFullScreen(_:)`, `dismiss()`, `switchTab(to:)`, `completeSplash()`, `reset()`, `handleDeepLink(_:)`.

`Route` ([`Route.swift`](../Source/Shared/Navigation/Route.swift)) is a pure value:

```swift
enum Route: Hashable, Sendable {
    case splash
    case main
    case home
    case settings
    case help
    case permissions
    case commonActions
    case logs
    case componentsGallery
    case alertsTest
}
```

`Route.id` is `String(reflecting: self)`, for `.sheet(item:)` and `.fullScreenCover(item:)`.

| Concern | File | Rule |
|---|---|---|
| Presentation policy | [`RoutePresentation.swift`](../Source/Shared/Navigation/RoutePresentation.swift) | `defaultPresentation`: `.splash` is a full-screen cover, `.settings` and `.permissions` are sheets, all others push. Callers can override it at `navigate(to:presentation:)` |
| View construction | [`RouteResolver.swift`](../Source/Shared/Navigation/RouteResolver.swift) | The only place that maps a `Route` to a view. `componentsGallery` and `alertsTest` resolve to their views in DEBUG and to `EmptyView` in Release |
| Deep links | `AppCoordinator.handleDeepLink(_:)` | Hosts `settings`, `home` (tab switch), `help`, `permissions` (navigate). Other hosts return `false` |

Call site:

```swift
@Environment(\.coordinator) private var coordinator

Button(L.Settings.title) {
    coordinator.navigate(to: .settings)
}
```

`RootView` shows `SplashView` in `.splash` and the tab view in `.main`. The tab view sends selection changes through `switchTab(to:)`, so a tab with unsaved changes can hold the switch.

---

## State with `@Observable`

Do not use `ObservableObject` or `@Published`. Every observable type uses `@Observable`:

```swift
@MainActor @Observable
final class AlertManager: AlertManagerProtocol {
    private(set) var currentAlert: InAppAlert?
    func show(_ alert: InAppAlert) { ... }
    func dismiss() { ... }
}
```

`@Observable` works with plain `var` properties and takes part in SwiftUI invalidation when a view body reads them. With `@MainActor` it satisfies Swift 6 strict concurrency.

---

## Dependency injection with `AppContainer`

[`AppContainer`](../Source/Shared/Core/Container/AppContainer.swift) owns every long-lived service. `Application.init` creates it once:

```swift
@main
struct Application: App {
    @State private var coordinator = AppCoordinator()
    @State private var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
#if DEBUG
        Log.configure(for: .debug)
#else
        Log.configure(for: .release)
#endif
        _container = State(initialValue: AppContainer.production())
    }

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
                .environment(\.appContainer, container)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            container.configurationService.sceneDidChange(isForeground: phase != .background)
        }
    }
}
```

| Factory | Use | Implementations |
|---|---|---|
| `AppContainer.production()` | The app | Real services |
| `AppContainer.preview(configurationService:)` | SwiftUI previews (DEBUG) | Mocks; pass a `MockConfigurationService` to show a configuration |
| `AppContainer.testing()` | Unit tests (DEBUG) | Mocks |
| `AppContainer.placeholder()` | Default value of `@Environment(\.appContainer)` | DEBUG: `testing()`. Release: real services that never connect (no server URL, no cache, no identity) |

The `appContainer` environment value is non-optional. Mocks live in the app target, not the test target, so previews can use them.

### Why a container instead of singletons?

`AGENTS.md` forbids the Singleton pattern. The container gives one place to look up a service, swap implementations for tests, and reason about lifetime. The only recorded singleton is `FileLogHandler.shared`; see the [Logger README](../Source/Shared/Logger/README.md).

---

## Service convention

Each service is a `Sendable` protocol, a concrete type and a mock.

| Where the service lives | Use when | Example |
|---|---|---|
| `Source/Shared/Services/<Name>/` | Only the app uses it | `AlertManagerProtocol`, `AlertManager`, `InAppAlert` |
| A `WardAxis*` package | An extension or the agent needs it too | `ConfigurationServiceProtocol` in `WardAxisManagement` |

`AppContainer` stores each one as `any <Name>Protocol`, so call sites depend on the abstraction. App mocks are in `Source/Shared/Mocks/`, except `MockAlertManager` and `MockHapticFeedbackService`, which sit next to their implementations. Package doubles are in the `WardAxisManagementTestSupport` product.

---

## Packages

| Package | Products | Depends on | Content |
|---|---|---|---|
| `WardAxisTelemetry` | `WardAxisTelemetry` | none | `Log` over `os.Logger`, categories, signposter, file sink, `TelemetryService`. See [LOGGING.md](LOGGING.md) |
| `WardAxisManagementAPI` | `WardAxisAPIClient`, `WardAxisAPIServer`, `WardAxisAPIFixtures` | swift-openapi-generator, swift-openapi-runtime | The OpenAPI contract and the code generated from it; golden configuration frames for tests |
| `WardAxisManagement` | `WardAxisManagement`, `WardAxisManagementTestSupport` | `WardAxisTelemetry`, `WardAxisAPIClient` | Endpoint configuration, configuration feed, client identity, Keychain storage |

Each package has its own `swift test` suite. The Xcode scheme does not run them; see [TESTING.md](TESTING.md#package-tests).

The canonical contract is `Packages/WardAxisManagementAPI/Sources/WardAxisAPIServer/openapi.yaml`. The client target's `openapi.yaml` is a symlink to it. The contract declares one operation, `GET /config/stream`, with the `mutualTLS` security scheme, under the server URL `/v1`.

---

## Endpoint configuration

`APIConfiguration` (`WardAxisManagement/Endpoint/`) gives the validated server base URL.

| Step | Source | Rule |
|---|---|---|
| Host | `API_BASE_URL` build setting → `APIBaseURL` key in `Resources/Info.plist` | Debug: `http://127.0.0.1:8080` (`Configurations/app/app-debug.xcconfig`). Release: `https://api.invalid` placeholder (`app-release.xcconfig`) |
| Scheme | `APIConfiguration.resolve(rawValue:requiresHTTPS:)` | `https` always. `http` only to a loopback host and only when `requiresHTTPS` is `false` (DEBUG) |
| Refused parts | Same | Credentials, query, fragment, and any path other than `/` |
| Path prefix | The contract's `servers` URL | `/v1`; the spec is its only source |

`APIConfigurationError` holds no part of the value, so it is safe to log.

`APIRedirectRefusal` is a `URLSessionTaskDelegate` that refuses every HTTP redirect, so a 3xx cannot replay a request or the client identity to another host. No app code uses it yet.

---

## Configuration feed

`ConfigurationService` (`WardAxisManagement/Feed/`) keeps the live configuration from the server's `GET /v1/config/stream` WebSocket and keeps the last good copy on disk.

Trust boundary: the TLS handshake. The device authenticates with its TLS client certificate only. The service sends no `Authorization` header and no other credential.

| Part | Role |
|---|---|
| `ConfigurationServiceProtocol` | `configuration`, `isIdentityRejected`, `enrollmentDidChange(to:)`, `sceneDidChange(isForeground:)`; `AnyObject`, `Sendable` |
| `ConfigurationService` | `@MainActor @Observable`; one connection loop; follows the enrollment state and the scene phase |
| `EnrollmentState` | `.restoring`, `.unenrolled`, `.enrolled(EnrollmentID)` |
| `ClientIdentityProvider` | `KeychainClientIdentityProvider(label:accessGroup:)` reads a `SecIdentity` by label from the data protection keychain. `NoClientIdentityProvider` returns `nil` |
| `ConfigurationStreamRequest` | Builds the upgrade request. Only `https`, sent as `wss`, for every host and build |
| `ConfigurationStreamTransport` / `URLSessionWebSocketTransport` | One ephemeral `URLSession` per connection |
| `ConfigurationCloseRoute` | The only place that names close codes |
| `ReconnectBackoff` | The delay before every reconnect |
| `ConfigurationFrameDecoder` / `ConfigurationLimits` | Decode a frame with the generated `ConfigMessage`; refuse an oversize or deep payload first |
| `ConfigurationCacheProtocol` / `FileConfigurationCache` / `NoConfigurationCache` | Offline copy; `NoConfigurationCache` keeps nothing |
| `ManagedConfiguration` | `version` (`Int64`) and `values` (`[String: ConfigurationValue]`) |

### Current state in the app

| Input | Value today | Effect |
|---|---|---|
| Identity provider | `NoClientIdentityProvider` in `AppContainer.production()` | No enrollment flow exists yet, so the feed never connects |
| Enrollment | `RootView.onAppear` reports `.unenrolled` | The service also deletes a cache left by an earlier enrollment |
| Scene | `Application` forwards `scenePhase` | Background closes the connection; foreground reconnects |
| Base URL in Debug | `http://127.0.0.1:8080` | `ConfigurationStreamRequest` refuses cleartext, so the feed stays idle in Debug too |

### Transport

| Challenge or frame | Handling |
|---|---|
| Server trust | `performDefaultHandling`: system evaluation, ATS rules included |
| Client certificate | The device `ClientIdentity` credential |
| Any other challenge (for example HTTP Basic) | Cancelled |
| Binary frame | Dropped; the contract sends text frames only |
| Message size | `maximumMessageSize` is 256 KiB |

### Close routing

| Signal | Route | Action |
|---|---|---|
| Client certificate rejected, close `1008`, handshake `401` or `403` | `identityRejected` | Stop. `isIdentityRejected` becomes `true` until the enrollment changes |
| Close `1000`, `1001`, `1011` | `reconnect` | Reconnect for a new snapshot after the backoff delay |
| Any other close code (for example `1013`), other handshake status, connection failure | `backOff` | Reconnect after the backoff delay |

### Reconnect rule

- Delay: base 1 s, doubled each attempt, 60 s cap, full jitter, 250 ms floor.
- Every reconnect waits, so a server that repeats a close cannot cause a reconnect storm.
- Reset: only a heartbeat that follows the snapshot, on a connection open for at least 25 s.

### Frame limits

- At most 256 KiB per frame or cache file, nesting depth 32, and 1024 entries.
- `ConfigurationLimits.isWithinBounds` runs a strict pre-scan before any decode. It refuses NUL bytes, bad escapes, raw control bytes and unbalanced brackets. A looser scan would let the decoder see nesting that the scan missed.

### Cache rules

- Location: `<Application Support>/<bundle identifier>/Configuration/configuration.json`; under Caches on tvOS. A missing or unsafe bundle identifier gives `NoConfigurationCache`.
- File protection `completeUntilFirstUserAuthentication`, so a prewarmed launch can read it.
- The directory is excluded from backup, because the server can resend it.
- The file holds the schema version, the configuration version and the values. It has no credential field.
- The service applies the cached copy before the first network attempt. Unenrollment deletes it.

Evidence: `ConfigurationServiceTests`, `ConfigurationWireTests`, `ConfigurationCacheTests`, `ReconnectBackoffTests` and `ConfigurationContractTests` in `Packages/WardAxisManagement/Tests/`.

---

## Secure storage

`WardAxisManagement/SecureStorage/` keeps one secret value per Keychain item. No app code uses it yet; it is the storage for the enrollment work.

| Part | Role |
|---|---|
| `SecurePayload` | `Codable`, `Sendable`, `Equatable` value to store |
| `SecureItemStoreProtocol<Value>` | Synchronous `load()`, `save(_:)`, `delete()` |
| `KeychainItemStore<Value>` | One generic-password item at a `KeychainItemLocation(service:account:accessGroup:)` |
| `UnavailableItemStore<Value>` | Keeps nothing |
| `SecureItemVault<Value>` | Actor; serializes store calls off the main actor and fences writes by generation |
| `ErasePendingMarkerProtocol` | `FileErasePendingMarker`, `VolatileErasePendingMarker` |

Keychain item attributes (from `KeychainQuery`):

| Attribute | Value | Why |
|---|---|---|
| Keychain | Data protection keychain (`kSecUseDataProtectionKeychain`) | The legacy macOS file keychain ignores the accessibility class |
| Accessibility | `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | Background extensions can read it after the first unlock; never restored to another device |
| Synchronizable | `false` | Never synced through iCloud Keychain |
| Access group | `KeychainItemLocation.accessGroup`, or the process default when `nil` | The app and its extensions share one item |

Generation fencing: the caller gives every write and erase a generation from one increasing counter. A write at or below the highest erased generation is dropped. An older write does not replace a newer item. The final content depends only on which generations wrote and erased, not on call order.

Erase-pending marker: an empty file, `<Application Support>/<bundle identifier>/Vault/erase-pending` (under Caches on tvOS). The vault sets it before an erase deletes and clears it when a delete or a newer save covers the item. `resumePendingErase()` finishes an erase that a previous launch could not complete. A missing or unsafe bundle identifier gives `VolatileErasePendingMarker`, which lasts for one process.

Evidence: `KeychainItemStoreTests` and `SecureItemVaultTests` in `Packages/WardAxisManagement/Tests/`.

---

## Telemetry

`TelemetryService` (`WardAxisTelemetry`) is opt-in. It reads consent on every event and drops the event without consent. The default consent closure returns `false`. `AppContainer.production()` uses `TelemetryService()`, so the app records nothing today. The Settings telemetry toggle is fixed to off until a consent flow exists.

`TelemetryEvent` cases (`screenViewed`, `tabSelected`, `actionTapped`) carry UI element names only. They never carry matched content, URLs, host names or file names.

---

## App sandbox, entitlements and privacy manifest

| Item | Value | Source |
|---|---|---|
| App Sandbox | On | `ENABLE_APP_SANDBOX` in `Configurations/app/app.xcconfig` |
| Hardened Runtime | On | `ENABLE_HARDENED_RUNTIME` |
| User-selected files | Read-only | `ENABLE_USER_SELECTED_FILES` |
| Outgoing network | Allowed | `ENABLE_OUTGOING_NETWORK_CONNECTIONS` |
| Keychain access group | `$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)` | `Resources/entitlement.entitlements` |
| Privacy manifest | No tracking, no collected data types; file timestamp access with reason `C617.1` | `Resources/PrivacyInfo.xcprivacy` |
| Export compliance | `ITSAppUsesNonExemptEncryption` = `false` | `Resources/Info.plist` |

---

## Server

The management back end is in `Server/`: Hummingbird 2 on PostgreSQL 18. The stack decision is [ADR 0001](adr/0001-swift-server-stack.md). Setup, variables and behaviour are in [Server/README.md](../Server/README.md).

| Route | Authentication | Note |
|---|---|---|
| `GET /v1/health` | None, or the device client certificate when `TLS_CLIENT_CA_PATH` is set | Database reachability |
| `GET /v1/config/stream` | TLS client certificate that chains to the device CA (`mutualTLS`) | Mounted only when `TLS_CLIENT_CA_PATH` is set |
| `GET /v1/docs`, `GET /v1/openapi.yaml` | None | Development only; production never mounts them |

The server has no user accounts. Administrator authentication is not built yet.

### Configuration flow

```
device certificate (device CA) ──► TLS handshake (mutual TLS)
                                        │
                     GET /v1/config/stream  (WebSocket, wss)
                                        │
              ConfigSnapshot ──► ConfigDelta …      ConfigHeartbeat every 30 s
                                        │
        close 1000 · 1001 · 1011 · 1013 ──► backoff ──► reconnect (new snapshot)
                                        │
                      last good copy ──► offline cache (file)
```

| Step | Server | App |
|---|---|---|
| Handshake | Requires a client certificate that chains to the device CA | Answers the client-certificate challenge with the device identity |
| Snapshot | First frame: current version and every entry | Decodes with `ConfigurationFrameDecoder`, then writes the cache |
| Delta | One frame per committed change; version + 1 each time | Applies it and updates the cache |
| Keep-alive | Heartbeat every 30 s; WebSocket ping every 45 s; no pong for 90 s closes with `1001` | Keeps one receive pending so the task answers pings |
| Lifetime | Closes with `1000` after 15 min, less a random 0 to 3 min | Reconnects after the backoff delay |
| Overload | More than 5 streams per certificate, or relay not ready in 10 s: `1013` | Backs off |
| Offline | None | Starts from the cached copy |

The full close table is in [Server/README.md](../Server/README.md#config-stream).

### TLS and ATS posture

| Surface | Posture | Evidence |
|---|---|---|
| Server listener | TLS 1.2 minimum with forward-secret AEAD suites. `production` (the default) refuses to start without a certificate chain and key | `ConfigurationTests`, `TLSListenerTests` (server) |
| Server config feed | Only with `TLS_CLIENT_CA_PATH`; every handshake must present a device certificate | `ConfigStreamMutualTLSTests` (server) |
| App feed | `wss` only, for every host and build | `ConfigurationWireTests` |
| App base URL, Release | `https` only | `APIConfigurationTests`, `Configurations/app/app-release.xcconfig` |
| App base URL, Debug | `http` to a loopback host is accepted; the feed still refuses it | `Configurations/app/app-debug.xcconfig` |
| App `Info.plist` | No ATS dictionary, no exception key | `HostConfigurationTests.noTransportSecurityException` (app unit tests) |

Check the source tree for an ATS exception. The command prints nothing when the posture holds:

```bash
grep -rnE '\b(NSAppTransportSecurity|NSAllowsArbitraryLoads|NSAllowsLocalNetworking|NSExceptionDomains)\b' Resources Configurations Source WardAxis.xcodeproj/project.xcproj
```

### Contract tests

| Suite | Checks | Command |
|---|---|---|
| `ContractRouteTests` | Each spec operation is mounted and answers per contract | `cd Server && swift test --filter ContractRouteTests` |
| `ConfigFrameContractTests` | Server encoder output for each golden frame equals the fixture | `cd Server && swift test --filter ConfigFrameContractTests` |
| `GoldenFrameFixtureTests` | Each fixture decodes to the generated `ConfigMessage` and re-encodes byte for byte | `cd Packages/WardAxisManagementAPI && swift test` |
| `ConfigurationContractTests` | The app decoder yields the same entries and version as each fixture | `cd Packages/WardAxisManagement && swift test` |

Golden frames: `config-frame-snapshot.json`, `config-frame-delta.json` and `config-frame-heartbeat.json` in `Packages/WardAxisManagementAPI/Sources/WardAxisAPIFixtures/Frames/`. `Packages/WardAxisManagementAPI/scripts/lint-openapi.sh` lints the contract with vacuum and reports breaking changes with oasdiff.

---

## Concurrency model

- **Swift 6 language mode** with `SWIFT_STRICT_CONCURRENCY = complete`; the packages set `swiftLanguageModes: [.v6]`.
- **`@MainActor`** on UI types: coordinator, view models, `AlertManager`, `ConfigurationService`.
- **`actor`** for serial off-main work: `LogReaderService`, `FileLogHandler`, `SecureItemVault`.
- **`Sendable`** on every value that crosses an actor boundary (`Route`, `AppError`, `ManagedConfiguration`).

---

## See also

- [PROJECT-STRUCTURE.md](PROJECT-STRUCTURE.md) - directory tour
- [FEATURE-DEVELOPMENT.md](FEATURE-DEVELOPMENT.md) - add a screen end to end
- [TESTING.md](TESTING.md) - `AppContainer.testing()`, mocks, package tests
- [ERROR-HANDLING.md](ERROR-HANDLING.md) - `AppError` and alerts
- [DESIGN.md](DESIGN.md) - design tokens
- [ADR 0001: Swift server stack](adr/0001-swift-server-stack.md)
