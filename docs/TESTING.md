# Testing

Unit tests use **Swift Testing**. UI tests use **XCUITest**. App mocks live in `Source/Shared/Mocks/` (and next to `AlertManager` and `HapticFeedbackService`), so previews and tests share them. Package doubles live in the `WardAxisManagementTestSupport` product.

---

## Layout

```
Tests/
├── UnitTests/
│   ├── Core/                 # AppContainer factories, host app configuration
│   ├── Features/Settings/    # SettingsViewModel
│   ├── Logger/               # Log parser, LogReaderService, LogsViewerViewModel
│   └── Navigation/           # AppCoordinator, RoutePresentation, RouteResolver
└── UITests/                  # XCUITest

Packages/WardAxisTelemetry/Tests/WardAxisTelemetryTests/
Packages/WardAxisManagement/Tests/WardAxisManagementTests/
Packages/WardAxisManagementAPI/Tests/WardAxisAPITests/
Server/Tests/ServerTests/
```

Mirror `Source/` where it helps. Do not mirror it by rule.

---

## Running

App tests (the `WardAxis` scheme runs `UnitTests` and `UITests`):

```bash
xcodebuild -project WardAxis.xcodeproj \
           -scheme WardAxis \
           -configuration Debug \
           -destination 'platform=macOS' \
           -skipPackagePluginValidation \
           -onlyUsePackageVersionsFromResolvedFile \
           test
```

One suite:

```bash
xcodebuild ... test -only-testing:UnitTests/AppContainerTests
```

Use `-configuration Debug`: the mocks and the `preview()` and `testing()` factories exist only under `#if DEBUG`. Simulator destinations are in [GETTING-STARTED.md](GETTING-STARTED.md#3-build-and-test).

### Package tests

The Xcode scheme does not run the package suites. Run each one:

```bash
(cd Packages/WardAxisCore && swift test)
(cd Packages/WardAxisTelemetry && swift test)
(cd Packages/WardAxisManagement && swift test)
(cd Packages/WardAxisManagementAPI && swift test)
(cd Server && swift test)
```

| Package | Suites |
|---|---|
| `WardAxisTelemetry` | Log configuration, formatting, levels, privacy defaults, telemetry consent |
| `WardAxisManagement` | `APIConfiguration`, API base path, `ConfigurationService`, feed wire format, configuration cache, configuration contract, `ReconnectBackoff`, `KeychainItemStore`, `SecureItemVault` |
| `WardAxisManagementAPI` | `ConfigMessage` coding, golden frames, contract servers URL |
| `Server` | See [Server/README.md](../Server/README.md#tests); the PostgreSQL suites need `TEST_DATABASE_URL` |

### Add a test file

The `Tests` folder entry in `WardAxis.xcodeproj/project.xcproj` lists the files of each test target under `membership-exceptions`. Add every new test file to the `UnitTests` or `UITests` inclusion list. A file missing from the list compiles into no target, and its tests never run, without any error.

---

## Swift Testing basics

A real suite from `Tests/UnitTests/Features/Settings/SettingsViewModelTests.swift`:

```swift
import Testing
@testable import WardAxis

@Suite("SettingsViewModel")
@MainActor
struct SettingsViewModelTests {
    private func makeViewModel(
        scenario: MockLogReaderService.Scenario = .sampleEntries
    ) -> (SettingsViewModel, MockLogReaderService) {
        let mock = MockLogReaderService(scenario: scenario)
        let viewModel = SettingsViewModel(logReader: mock)
        return (viewModel, mock)
    }

    @Test
    func `initial state is empty`() {
        let (viewModel, _) = makeViewModel()
        #expect(!viewModel.hasEntries)
        #expect(!viewModel.isBusy)
    }
}
```

Put `@MainActor` on the suite when every test touches main-actor state. `AppContainer` and the view models are `@MainActor`.

Name a test with a raw identifier, not with a `@Test("…")` display name. SwiftFormat (`swiftTestingTestCaseNames`) converts a display name into a raw identifier. A raw identifier cannot contain a backslash, so write `Unicode escape`, not `\u escape`.

### Parameterized tests

```swift
@Test(arguments: [Route.home, .help, .logs])
func `Push routes default to .push`(route: Route) {
    #expect(route.defaultPresentation == .push)
}
```

### Throwing tests

```swift
@Test
func `A failing log reader throws its error`() async {
    let service = MockLogReaderService(scenario: .failure(.writeFailed(underlying: "disk full")))
    await #expect(throws: LogReaderError.self) {
        _ = try await service.loadEntries()
    }
}
```

---

## `AppContainer.testing()`

Tests do not build real services. Use the testing factory:

```swift
@Test
@MainActor
func `AppContainer.testing() wires every service slot to a mock`() {
    let container = AppContainer.testing()

    #expect(container.alertManager is MockAlertManager)
    #expect(container.logReaderService is MockLogReaderService)
    #expect(container.hapticFeedback is MockHapticFeedbackService)
    #expect(container.telemetry is MockTelemetryService)
    #expect(container.configurationService is MockConfigurationService)
}
```

To set the mock behaviour, build the mock directly and inject it into the type under test. `AppContainer.preview(configurationService:)` takes a `MockConfigurationService` to show a configuration.

---

## Mocks and doubles

| Double | Location | Controls |
|---|---|---|
| `MockAlertManager` | `Source/Shared/Services/Alert/AlertManager.swift` | `init(initialAlert:)`; `currentAlert` |
| `MockHapticFeedbackService` | `Source/Shared/Accessibility/HapticFeedbackService.swift` | No-op |
| `MockLogReaderService` | `Source/Shared/Mocks/` | `Scenario`: `.empty`, `.sampleEntries`, `.failure(LogReaderError)`; call counters |
| `MockTelemetryService` | `Source/Shared/Mocks/` | `recorded` events |
| `MockConfigurationService` | `Source/Shared/Mocks/` | `init(configuration:)`, `setConfiguration(_:)`; records `enrollmentChanges` and `sceneChanges` |
| `InMemoryConfigurationCache`, `ScriptedStreamTransport`, `StaticClientIdentityProvider`, `InMemorySecureItemStore`, `MockErasePendingMarker` | `WardAxisManagementTestSupport` | Package seams. `ScriptedStreamTransport` replays scripted frames and closes, so no test opens a socket |

Why app mocks sit in the app target:

- SwiftUI previews build against the app target and need them.
- Tests `@testable import WardAxis` and get them directly.
- A test-only mock set would force previews to keep a second set.

---

## What to test

| Layer | Test? | Notes |
|---|---|---|
| Services | Yes | Each protocol method: happy, edge and failure paths |
| Trust boundaries | Yes | Malformed and oversize input, replay, expired or revoked certificates (see `AGENTS.md` § Development rules) |
| View models | Yes | State changes, error handling, calls into mocks |
| `AppContainer` | Yes | Factories wire the right slots |
| `AppCoordinator` | Yes | Routing, tab switching, deep links |
| `RoutePresentation`, `RouteResolver` | Light | Presentation defaults; every route resolves |
| Pure views | Skip | UI tests only when the view has logic |

---

## UI tests

XCUITest in `Tests/UITests/`. Today the target has one test, `LaunchUITests.testLaunchPerformance`. It skips unless it runs on a simulator.

Drive new UI tests through the identifiers in `AccessibilityIdentifiers.swift`, and apply the identifier in the view first. For example, `HomeView` applies `AccessibilityID.Home.settingsButton` (`home.settings`). The UI test target cannot import the app module, so the test repeats the identifier string:

```swift
import XCTest

final class HomeUITests: XCTestCase {
    @MainActor
    func testSettingsButtonExists() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 10))
    }
}
```

The splash screen shows first, so wait for the element. UI tests are slow. Keep them for flows with product value, not for view rendering.

---

## Don't

- Do not hit the network in unit tests. Mock the service or use `ScriptedStreamTransport`.
- Do not build `LogReaderService()` with its default `fileURL` in a test. It reads and clears the real log file. Pass a temporary `fileURL`, as `LogReaderServiceTests` does, or use `MockLogReaderService(scenario:)`.
- Do not touch the real Keychain from a unit test. Use `InMemorySecureItemStore`.
- Do not use `Thread.sleep`. Inject a clock (for example `ConfigurationService(clock:)`).
- Do not test localized copy. Test that a string is returned, not its English value.

---

## See also

- [Apple: Swift Testing](https://developer.apple.com/xcode/swift-testing/)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [ERROR-HANDLING.md](ERROR-HANDLING.md)
