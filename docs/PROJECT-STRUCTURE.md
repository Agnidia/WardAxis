# Project Structure

This document maps every top-level folder and the rules for it.

```
WardAxis/
├── Source/                  # App Swift sources
│   ├── Shared/              # Cross-platform code
│   ├── iOS/                 # iOS-only extensions
│   └── macOS/               # macOS-only extensions
├── Extensions/              # Extension shells, one folder per target
├── Services/Agent/          # macOS login item shell
├── AppStore/                # App Store listing (asc layout) and publishing steps
├── Packages/                # Local SwiftPM packages (WardAxis*)
├── Resources/               # Assets, plists, String Catalogs, entitlements
├── Configurations/          # xcconfig build settings
├── Tests/                   # App unit and UI tests
├── Server/                  # Management server (Hummingbird 2, PostgreSQL)
├── docs/                    # This documentation; docs/adr/ holds decisions, THREAT-MODEL.md the trust boundaries, PRIVACY.md the data inventory, privacy/ the policy source
├── roadmap/                 # Product roadmap by phase
├── scripts/                 # Tooling (formatter.py, verify-entitlements.py, ci-simulator.py)
├── ci_scripts/              # Xcode Cloud hooks
├── .github/                 # Issue forms, security policy, PullRequest.yml (disabled until v1.0.0)
├── WardAxis.xcodeproj/      # Xcode project (JSON format, project.xcproj)
├── .swiftformat             # Format configuration
├── AGENTS.md                # Development rules for people and agents
├── CLAUDE.md                # Points to AGENTS.md
└── README.md
```

`WardAxis.xcodeproj/project.xcproj` is the Xcode 26.4+ JSON project file. `Source/`, `Resources/`, `Configurations/`, `Tests/`, each `Extensions/<Target>/` and `Services/Agent/` are synchronized folders:

| Folder | Membership |
|---|---|
| `Source/` | Every file joins the `WardAxis` target |
| `Resources/` | Only the files in the `WardAxis` inclusion list (asset catalogs, String Catalogs, privacy manifest) |
| `Tests/` | Only the files in the `UnitTests` or `UITests` inclusion list. Add each new test file there |
| `Extensions/<Target>/`, `Services/Agent/` | Every file joins the target of the same name, except `Info.plist` (read through `INFOPLIST_FILE`). Each folder has the bundle's own `PrivacyInfo.xcprivacy` ([ADR 0013](adr/0013-privacy-disclosures.md)) |
| `Configurations/` | No target; referenced by the project configurations |

---

## `Source/Shared/`

| Path | Purpose |
|---|---|
| `Application.swift` | `@main` entry. Configures `Log`, builds `AppContainer` and `AppCoordinator`, forwards the scene phase to the configuration feed |
| `Core/Container/` | `AppContainer` (dependency injection) |
| `Core/Error/` | `AppError` |
| `Navigation/` | `AppCoordinator`, `Route`, `RoutePresentation`, `RouteResolver` |
| `Views/` | `RootView.swift`: root view, splash-to-main switch, tab view |
| `Features/<Name>/` | View and view model side by side. Folders: `Help`, `Home`, `Logs`, `Settings`, `Splash` |
| `Services/Alert/` | `AlertManagerProtocol`, `AlertManager` (and `MockAlertManager`), `InAppAlert` |
| `Services/SystemExtension/` | `SystemExtensionServiceProtocol`, `SystemExtensionService`, `SystemExtensionIdentifier` ([ADR 0006](adr/0006-debug-system-extension-activation.md)) |
| `Mocks/` | `MockConfigurationService`, `MockLogReaderService`, `MockSystemExtensionService`, `MockTelemetryService` |
| `Logger/` | Log reading and viewer parts: `Models/` (`LogEntry`, `LogDateRange`), `Service/` (`LogReaderService`, `LogEntryParser`, `LogReaderError`), `UI/` (rows, filter bars, unavailable view). See the [Logger README](../Source/Shared/Logger/README.md) |
| `Localization/` | `LocalizedStrings.swift` (the `L` enum). Values live in `Resources/Localizable.xcstrings` |
| `Design/` | `Topology.swift` (tokens), `Typography.swift`, `Font+Custom.swift`, `Buttons/`. See [DESIGN.md](DESIGN.md) |
| `Controls/` | Shared controls (`AccentAlert`, `BannerAlert`, `AlertPresenter`, `FormTextField`, `SearchField`, `ToggleRow`, `TagPill`, …) |
| `Accessibility/` | `AccessibilityModifiers`, `AccessibilityIdentifiers`, `AccessibilityAnnouncer`, `HapticFeedbackService` (and its mock). See [ACCESSIBILITY.md](ACCESSIBILITY.md) |
| `Extensions/Foundation/`, `Extensions/SwiftUI/` | Shared extensions |
| `ViewModifiers/` | Reusable view modifiers (`ShimmerEffect`, keyboard, size) |
| `Helpers/` | `SizeClassAdaptiveView` |
| `Closure/` | `Closure+Default.swift` |

The `Log` API is not in `Source/`. It is in the `WardAxisTelemetry` package.

---

## `Source/iOS/` and `Source/macOS/`

Platform-specific extensions only. Before you add code here, check whether `Source/Shared/` with an `#if os(...)` or `#if canImport(...)` guard can hold it.

| Folder | Content |
|---|---|
| `Source/iOS/Extensions/ViewModifiers/` | Keyboard modifiers |
| `Source/macOS/Extensions/` | `NSWindow` titlebar, `NSScreen` frame, keyboard type |

---

## `Extensions/` and `Services/`

Packaging shells for the embedded components ([ADR 0005](adr/0005-extension-shells.md)). Each one refuses to work until its phase adds real logic.

| Folder | Target | Kind | Platforms |
|---|---|---|---|
| `Extensions/NetworkFilter/` | `NetworkFilter` | System extension (`NEFilterDataProvider`) | macOS |
| `Extensions/TransparentProxy/` | `TransparentProxy` | System extension (`NETransparentProxyProvider`) | macOS |
| `Extensions/DNSProxy/` | `DNSProxy` | System extension (`NEDNSProxyProvider`) | macOS |
| `Extensions/URLFilter/` | `URLFilter` | ExtensionKit extension (`NEURLFilterControlProvider`) | macOS, iOS |
| `Extensions/PacketTunnel/` | `PacketTunnel` | App extension (`NEPacketTunnelProvider`) | iOS, tvOS |
| `Extensions/SafariWebExtension/` | `SafariWebExtension` | Safari Web Extension; `Resources/manifest.json` | macOS, iOS |
| `Extensions/MailExtension/` | `MailExtension` | MailKit app extension | macOS |
| `Services/Agent/` | `Agent` | Login item app | macOS |

---

## `Packages/`

| Package | Targets | Tests |
|---|---|---|
| `WardAxisCore` | `WardAxisCore` (`Schema/`, `Event/`, `Policy/`, `Identity/`, `Sources/`), `WardAxisCoreSynthetic` | `WardAxisCoreTests` (fixtures in `Fixtures/`) |
| `WardAxisTelemetry` | `WardAxisTelemetry` | `WardAxisTelemetryTests` |
| `WardAxisManagement` | `WardAxisManagement` (`Endpoint/`, `Feed/`, `Identity/`, `SecureStorage/`), `WardAxisManagementTestSupport` | `WardAxisManagementTests` |
| `WardAxisManagementAPI` | `WardAxisAPIClient`, `WardAxisAPIServer`, `WardAxisAPIFixtures`; `scripts/lint-openapi.sh` | `WardAxisAPITests` |

The app target links `WardAxisTelemetry` and `WardAxisManagement`. `WardAxisManagement` brings in `WardAxisCore`. `WardAxisCoreSynthetic`, `WardAxisManagementTestSupport` and `WardAxisAPIFixtures` are for test targets only. See [ARCHITECTURE.md](ARCHITECTURE.md#packages).

---

## `Resources/`

| File / folder | Purpose |
|---|---|
| `AppIcon.icon` | App icon for iOS and macOS (Icon Composer): five SVG layers in `Assets/` |
| `AppIconTV.xcassets/` | tvOS `Brand Assets`: layered app icon (Back, Middle, Front) and Top Shelf images, rendered from the `AppIcon.icon` layers |
| `Assets.xcassets/` | Images |
| `Colors.xcassets/` | Semantic color tokens (light and dark), including `AccentColor`. Never hardcode a color |
| `Localizable.xcstrings` | App String Catalog |
| `InfoPlist.xcstrings` | Localized `Info.plist` values |
| `Info.plist` | `APIBaseURL` (from `API_BASE_URL`), scene manifest, `ITSAppUsesNonExemptEncryption` |
| `PrivacyInfo.xcprivacy` | Privacy manifest |
| `Preview Content/` | Preview assets (development only) |

---

## `Configurations/`

Edit build settings here, not in the Xcode UI.

| File | Purpose |
|---|---|
| `base.xcconfig` | `APP_NAME`, `APP_BUNDLE_ID`, extension bundle IDs, `APP_GROUP_ID`, `KEYCHAIN_SHARED_GROUP`, supported platforms, deployment targets, `SWIFT_VERSION = 6`, strict concurrency |
| `debug.xcconfig` / `release.xcconfig` | Per-configuration flags (optimization, `DEBUG` condition) |
| `lab.xcconfig` | Lab-only `Lab` configuration on top of Release: `.lab` bundle-ID root, macOS only, `WARDAXIS_LAB`, manual Developer ID signing ([ADR 0003](adr/0003-lab-build-signing.md)) |
| `sign.xcconfig` | Signing style and the interim `DEVELOPMENT_TEAM` |
| `app/app.xcconfig` | App target: bundle ID, Info.plist, entitlements file per SDK, App Sandbox, Hardened Runtime |
| `app/app-debug.xcconfig` / `app/app-release.xcconfig` / `app/app-lab.xcconfig` | `API_BASE_URL` per configuration |
| `extensions/` | One file per shell target for Debug, Release and Lab: bundle ID, platforms, entitlements per SDK. `extension.xcconfig` holds the shared settings; in Lab the shells build unsigned and the lab app embeds none |
| `tests/` | `UnitTests` and `UITests` targets: bundle IDs, test host |
| `Entitlements/` | One entitlements file per target and SDK: App Sandbox (macOS), NetworkExtension provider types, `system-extension.install` (macOS app only), App Group, Keychain groups (private first, then shared). `App-Lab.entitlements` is the lab app's ([ADR 0004](adr/0004-network-extension-entitlements.md)) |
| `export/app-store.plist` | Export options for App Store Connect (automatic signing, no team ID) |
| `export/developer-id.plist` | Export options for the lab build (Developer ID, manual profile); never uploaded |

---

## `Tests/`

| Folder | Purpose |
|---|---|
| `Tests/UnitTests/Core/` | `AppContainer` factories; host app configuration (`Info.plist`, bundle ID); signed entitlements (macOS); embedded bundles |
| `Tests/UnitTests/Features/Settings/` | `SettingsViewModel` |
| `Tests/UnitTests/Logger/` | Log parser, `LogReaderService`, `LogsViewerViewModel` |
| `Tests/UnitTests/Navigation/` | `AppCoordinator`, `RoutePresentation`, `RouteResolver` |
| `Tests/UITests/` | XCUITest (launch performance) |

Package tests live in each package's `Tests/` folder. See [TESTING.md](TESTING.md).

---

## `Server/`

Swift package with the executable `Server` and the library `ServerCore`, plus `compose.yaml`, `Dockerfile` and `.env.example`. See [Server/README.md](../Server/README.md).

---

## `docs/`

Reference material. Update a doc in the same change as the behaviour it describes. Record security-relevant decisions in `docs/adr/`, and a new trust boundary, asset or out-of-scope item in `docs/THREAT-MODEL.md`.

---

## `scripts/` and `ci_scripts/`

| File | Purpose |
|---|---|
| `scripts/formatter.py` | Runs SwiftFormat on modified files (`--all`, `--check`, `--staged` options); called by the Xcode build phase |
| `scripts/verify-entitlements.py` | Checks the signed entitlements of every bundle in an archive or app; run before each App Store upload |
| `scripts/ci-simulator.py` | Prints the UDID of the newest available iOS or tvOS simulator for `PullRequest.yml`; fails when none exists |
| `ci_scripts/ci_post_clone.sh` | Xcode Cloud post-clone hook; resets the Xcode package-resolution defaults |
