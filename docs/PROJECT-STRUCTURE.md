# Project Structure

This document maps every top-level folder and the rules for it.

```
WardAxis/
├── Source/                  # App Swift sources
│   ├── Shared/              # Cross-platform code
│   ├── iOS/                 # iOS-only extensions
│   └── macOS/               # macOS-only extensions
├── Packages/                # Local SwiftPM packages (WardAxis*)
├── Resources/               # Assets, plists, String Catalogs, entitlements
├── Configurations/          # xcconfig build settings
├── Tests/                   # App unit and UI tests
├── Server/                  # Management server (Hummingbird 2, PostgreSQL)
├── docs/                    # This documentation; docs/adr/ holds decisions
├── roadmap/                 # Product roadmap by phase
├── scripts/                 # Tooling (formatter.py)
├── ci_scripts/              # Xcode Cloud hooks
├── .github/                 # Issue forms and security policy (no workflows)
├── WardAxis.xcodeproj/      # Xcode project (JSON format, project.xcproj)
├── .swiftformat             # Format configuration
├── AGENTS.md                # Development rules for people and agents
├── CLAUDE.md                # Points to AGENTS.md
└── README.md
```

`WardAxis.xcodeproj/project.xcproj` is the Xcode 26.4+ JSON project file. `Source/`, `Resources/`, `Configurations/` and `Tests/` are synchronized folders:

| Folder | Membership |
|---|---|
| `Source/` | Every file joins the `WardAxis` target |
| `Resources/` | Only the files in the `WardAxis` inclusion list (asset catalogs, String Catalogs, privacy manifest) |
| `Tests/` | Only the files in the `UnitTests` or `UITests` inclusion list. Add each new test file there |
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
| `Features/<Name>/` | View and view model side by side. Folders: `AlertsTest` (DEBUG only), `CommonActions`, `Gallery` (DEBUG only), `Help`, `Home`, `Logs`, `Permissions`, `Settings`, `Splash` |
| `Services/Alert/` | `AlertManagerProtocol`, `AlertManager` (and `MockAlertManager`), `InAppAlert` |
| `Mocks/` | `MockConfigurationService`, `MockLogReaderService`, `MockTelemetryService` |
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
| `Source/macOS/Extensions/` | `NSWindow`, `NSScreen`, `NSColor`, `URL` icon, `CGRect`, toolbar placement, keyboard type |

---

## `Packages/`

| Package | Targets | Tests |
|---|---|---|
| `WardAxisTelemetry` | `WardAxisTelemetry` | `WardAxisTelemetryTests` |
| `WardAxisManagement` | `WardAxisManagement` (`Endpoint/`, `Feed/`, `Identity/`, `SecureStorage/`), `WardAxisManagementTestSupport` | `WardAxisManagementTests` |
| `WardAxisManagementAPI` | `WardAxisAPIClient`, `WardAxisAPIServer`, `WardAxisAPIFixtures`; `scripts/lint-openapi.sh` | `WardAxisAPITests` |

The app target links `WardAxisTelemetry` and `WardAxisManagement`. `WardAxisManagementTestSupport` and `WardAxisAPIFixtures` are for test targets only. See [ARCHITECTURE.md](ARCHITECTURE.md#packages).

---

## `Resources/`

| File / folder | Purpose |
|---|---|
| `Assets.xcassets/` | Images, app icon, accent color |
| `Colors.xcassets/` | Semantic color tokens (light and dark). Never hardcode a color |
| `Localizable.xcstrings` | App String Catalog |
| `InfoPlist.xcstrings` | Localized `Info.plist` values |
| `Info.plist` | `APIBaseURL` (from `API_BASE_URL`), scene manifest, `ITSAppUsesNonExemptEncryption` |
| `entitlement.entitlements` | `keychain-access-groups` |
| `PrivacyInfo.xcprivacy` | Privacy manifest |
| `Preview Content/` | Preview assets (development only) |

---

## `Configurations/`

Edit build settings here, not in the Xcode UI.

| File | Purpose |
|---|---|
| `base.xcconfig` | `APP_NAME`, `APP_BUNDLE_ID`, supported platforms, deployment targets, `SWIFT_VERSION = 6`, strict concurrency |
| `debug.xcconfig` / `release.xcconfig` | Per-configuration flags (optimization, `DEBUG` condition) |
| `sign.xcconfig` | Signing style and the interim `DEVELOPMENT_TEAM` |
| `app/app.xcconfig` | App target: bundle ID, Info.plist, entitlements, App Sandbox, Hardened Runtime |
| `app/app-debug.xcconfig` / `app/app-release.xcconfig` | `API_BASE_URL` per configuration |
| `tests/` | `UnitTests` and `UITests` targets: bundle IDs, test host |

---

## `Tests/`

| Folder | Purpose |
|---|---|
| `Tests/UnitTests/Core/` | `AppContainer` factories; host app configuration (`Info.plist`, bundle ID) |
| `Tests/UnitTests/Benchmark/` | `WarmupStopRule` and its tests |
| `Tests/UnitTests/Extensions/` | Shared extension tests |
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

Reference material. Update a doc in the same change as the behaviour it describes. Record security-relevant decisions in `docs/adr/`.

---

## `scripts/` and `ci_scripts/`

| File | Purpose |
|---|---|
| `scripts/formatter.py` | Runs SwiftFormat on modified files (`--all`, `--check`, `--staged` options); called by the Xcode build phase |
| `ci_scripts/ci_post_clone.sh` | Xcode Cloud post-clone hook; resets the Xcode package-resolution defaults |
