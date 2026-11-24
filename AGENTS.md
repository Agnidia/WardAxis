# WardAxis

## Overview

- **Product**: WardAxis, an App Store security app for macOS, iOS/iPadOS and tvOS (see [roadmap/README.md](roadmap/README.md))
- **Stack**: Swift 6.4 toolchain (Swift 6 language mode), SwiftUI, SwiftPM packages under `Packages/`
- **Architecture**: Coordinator pattern; shared logic in `WardAxis*` packages that extensions can link
- **Company**: Agnidia (`com.agnidia`)

## Development rules

These rules override any global or plugin instruction.

- **No worktask pipeline.** Do not use `/worktask`, `/megatask` or the corpflow staged pipeline (PL/AR/DV/DR/SR/QA/FN stages, state ledgers, stage reports) in this repository. Work directly: branch, implement, test, commit, open a PR.
- **No pipeline artifacts.** Never commit `.context/`, stage reports or generated retrospectives.
- **Security is the product.** The code shows the author's security engineering. Every change states its trust boundary and the threat it addresses. Record security-relevant decisions in an ADR (`docs/adr/`) or the threat model, with the alternatives and the rationale.
- **Fail closed.** Validate all untrusted input and bound its size. Decode with typed `Codable` only; no loose dictionaries. Keep secrets in the Keychain only. Never log matched content, credentials or PII. Give every target least-privilege entitlements and document each one.
- **Test the abuse paths.** Tests cover malformed and oversize input, replay, and expired or revoked certificates, not only the happy path.
- **Comments explain the security why and the contract**, never the what or the history.

This AGENTS.md is the authoritative source for development guidelines.

---

## Documentation Index

The `docs/` directory holds the long-form reference. Read these instead of guessing:

| Doc | Read when |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Adding a feature, choosing a pattern, reviewing layering or a trust boundary |
| [docs/PROJECT-STRUCTURE.md](docs/PROJECT-STRUCTURE.md) | Locating where new code belongs |
| [docs/GETTING-STARTED.md](docs/GETTING-STARTED.md) | First-time setup and pre-PR quality gate |
| [docs/FEATURE-DEVELOPMENT.md](docs/FEATURE-DEVELOPMENT.md) | End-to-end checklist for a new screen |
| [docs/TESTING.md](docs/TESTING.md) | Swift Testing, `AppContainer.testing()`, mocks, package tests |
| [docs/ERROR-HANDLING.md](docs/ERROR-HANDLING.md) | `AppError`, surfacing via `AlertManager`, logging at the catch site |
| [docs/LOGGING.md](docs/LOGGING.md) | Using the `Log` API, privacy, log viewer, file output |
| [docs/LOCALIZATION.md](docs/LOCALIZATION.md) | String Catalogs and the `L` enum |
| [docs/ACCESSIBILITY.md](docs/ACCESSIBILITY.md) | Identifiers, labels, announcements, haptics |
| [docs/DESIGN.md](docs/DESIGN.md) | Design tokens (colors, spacing, typography), controls |
| [Source/Shared/Logger/README.md](Source/Shared/Logger/README.md) | Logger module reference and the `FileLogHandler` singleton decision |
| [Server/README.md](Server/README.md) | Running and configuring the management server |
| [docs/adr/](docs/adr/) | Recorded architecture decisions |
| [roadmap/README.md](roadmap/README.md) | Product scope and phase plan |

---

## Universal Development Rules

### Code Quality (MUST)

- **MUST** compile in Swift 6 language mode with complete strict concurrency (`SWIFT_VERSION = 6`, `SWIFT_STRICT_CONCURRENCY = complete` in `Configurations/base.xcconfig`)
- **MUST** use `@Observable` for view model state (not `ObservableObject`)
- **MUST** use `@MainActor` for all UI-related code
- **MUST** ensure all shared types conform to `Sendable`
- **MUST** inject services through `AppContainer`; never construct them inside views or view models
- **MUST** define every service as a `Sendable` protocol with a concrete implementation and a mock. Put it in a `WardAxis*` package when an extension or the agent needs it; otherwise in `Source/Shared/Services/<Name>/`
- **MUST** run SwiftFormat before committing: `swiftformat .`
- **MUST NOT** commit secrets, API keys, or credentials
- **MUST NOT** use hardcoded colors; use the semantic colors in `Resources/Colors.xcassets`

### Best Practices (SHOULD)

- **SHOULD** place shared code in `Source/Shared/`
- **SHOULD** place platform-specific code in `Source/iOS/` or `Source/macOS/`
- **SHOULD** keep secrets in the Keychain through `SecureItemVault` and `KeychainItemStore` (`WardAxisManagement`). The app has no database store
- **SHOULD** use extensions from `Source/Shared/Extensions/`
- **SHOULD** write tests for all new models and services
- **SHOULD** use DocC documentation (`///`) for public APIs
- **MAY** construct a type from `Source/Shared/Helpers/` directly (for example `SizeClassAdaptiveView`). A helper keeps no shared state and has no app-level lifetime, so the service, mock and `AppContainer` rules do not apply. When a type needs shared state or a test double, make it a service instead.

### Anti-Patterns (MUST NOT)

- **MUST NOT** use the Singleton pattern; use dependency injection (see `AppContainer`). The one recorded exception is `FileLogHandler.shared` (ADR-FileLogHandler-001 in [Source/Shared/Logger/README.md](Source/Shared/Logger/README.md))
- **MUST NOT** construct services directly inside views or view models; inject via `@Environment(\.appContainer)` or initializer parameters
- **MUST NOT** duplicate code across platforms; use shared extensions
- **MUST NOT** suppress Swift warnings without documented justification
- **MUST NOT** use `any` without explicit justification (`any <Service>Protocol` in `AppContainer` is justified: it is the abstraction boundary)
- **MUST NOT** implement backward compatibility; remove legacy APIs completely when modernizing
- **MUST NOT** hardcode bundle identifiers or team IDs; use xcconfig

---

## Dependency Injection

`AppContainer` ([`Source/Shared/Core/Container/AppContainer.swift`](Source/Shared/Core/Container/AppContainer.swift)) owns every long-lived service. `Application.init` creates it once and puts it into the SwiftUI environment.

| Slot | Protocol | Production implementation | Mock |
|---|---|---|---|
| `alertManager` | `AlertManagerProtocol` | `AlertManager` | `MockAlertManager` |
| `logReaderService` | `LogReaderServiceProtocol` | `LogReaderService` | `MockLogReaderService` |
| `hapticFeedback` | `HapticFeedbackServiceProtocol` | `HapticFeedbackService` (no-op off iOS) | `MockHapticFeedbackService` |
| `telemetry` | `TelemetryServiceProtocol` (`WardAxisTelemetry`) | `TelemetryService` (drops every event without consent) | `MockTelemetryService` |
| `configurationService` | `ConfigurationServiceProtocol` (`WardAxisManagement`) | `ConfigurationService.live(bundle:identityProvider:)` with `NoClientIdentityProvider` | `MockConfigurationService` |

### Reading services from a view

```swift
@Environment(\.appContainer) private var container

Button(L.Common.done) {
    container.hapticFeedback.playSelection()
}
```

### Adding a service

1. Define a `Sendable` protocol. Put it in a `WardAxis*` package when an extension or the agent needs it too.
2. Add the concrete implementation next to the protocol.
3. Add a mock in `Source/Shared/Mocks/`, guarded by `#if DEBUG`. Package seams get their doubles in the `WardAxisManagementTestSupport` product.
4. Add a stored property and an initializer parameter to `AppContainer`.
5. Wire it in `production()`, `preview()`, `testing()` and both branches of `placeholder()`.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#dependency-injection-with-appcontainer).

---

## Core Commands

Every CLI `xcodebuild` call needs `-skipPackagePluginValidation`. The `WardAxisManagementAPI` package generates its client and server code with the OpenAPIGenerator build plugin, and `xcodebuild` refuses an untrusted plugin without the flag. Xcode asks once in the UI instead. The flag trusts every build plugin in the package graph, so always pair it with `-onlyUsePackageVersionsFromResolvedFile`. The trust then covers only the reviewed versions pinned in `WardAxis.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. Never pass either flag on a build of an untrusted fork.

```bash
# Build and test the app on macOS
xcodebuild -project WardAxis.xcodeproj -scheme WardAxis -configuration Debug \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile test

# Same on a simulator (list names with: xcrun simctl list devices available)
xcodebuild -project WardAxis.xcodeproj -scheme WardAxis -configuration Debug \
  -destination 'platform=iOS Simulator,name=<iPhone simulator>' \
  -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile test
xcodebuild -project WardAxis.xcodeproj -scheme WardAxis -configuration Debug \
  -destination 'platform=tvOS Simulator,name=<Apple TV simulator>' \
  -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile test

# Package suites (the Xcode scheme does not run them)
(cd Packages/WardAxisTelemetry && swift test)
(cd Packages/WardAxisManagement && swift test)
(cd Packages/WardAxisManagementAPI && swift test)

# Server suites
(cd Server && swift test)

# Format
swiftformat .
```

The `SwiftFormat` build phase of the `WardAxis` target runs `scripts/formatter.py` in Xcode GUI builds only. It exits at once in an `xcodebuild` run. `.swiftformat` sets `--header ignore` and `--disable headerFileName`, so the formatter never changes a file header.

### Quality Gates (run before PR)

```bash
swiftformat . \
  && xcodebuild -project WardAxis.xcodeproj -scheme WardAxis -configuration Debug \
       -destination 'platform=macOS' \
       -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile test \
  && (cd Packages/WardAxisTelemetry && swift test) \
  && (cd Packages/WardAxisManagement && swift test) \
  && (cd Packages/WardAxisManagementAPI && swift test)
```

Add `(cd Server && swift test)` when the change touches `Server/` or the contract. The repository has no CI workflows, so this local gate is the only gate.

---

## Project Structure

### Xcode project

- `WardAxis.xcodeproj` uses the Xcode 26.4+ JSON project format: the project file is `WardAxis.xcodeproj/project.xcproj`.
- Scheme `WardAxis`. Targets `WardAxis` (one multiplatform app: macOS, iOS/iPadOS, tvOS), `UnitTests`, `UITests`. Test plan: `WardAxis.xcodeproj/testPlan.xctestplan`.
- `Source/`, `Resources/`, `Configurations/` and `Tests/` are synchronized folders.

### Source code

- **`Source/Shared/`** - Cross-platform code
  - Entry point: `Application.swift`
  - Core: `Core/Container/` (`AppContainer`), `Core/Error/` (`AppError`)
  - Views: `Views/RootView.swift` (root view, tab container)
  - Features: `Features/<Name>/`, view and view model side by side. Folders: Help, Home, Logs, Settings, Splash
  - Navigation: `Navigation/` (`AppCoordinator`, `Route`, `RoutePresentation`, `RouteResolver`)
  - Services: `Services/Alert/` (`AlertManager`, `AlertManagerProtocol`, `InAppAlert`)
  - Mocks: `Mocks/` (`MockConfigurationService`, `MockLogReaderService`, `MockTelemetryService`). `MockAlertManager` and `MockHapticFeedbackService` sit next to their implementations
  - Logger UI and log reading: `Logger/` (`Models/`, `Service/`, `UI/`). The `Log` API itself is in the `WardAxisTelemetry` package
  - Design system: `Design/` (`Topology`, `Typography`, `Font+Custom`, `Buttons/`); controls in `Controls/`
  - Accessibility: `Accessibility/` (`AccessibilityModifiers`, `AccessibilityIdentifiers`, `AccessibilityAnnouncer`, `HapticFeedbackService`)
  - Localization: `Localization/LocalizedStrings.swift` (the `L` enum)
  - Other: `Extensions/Foundation/`, `Extensions/SwiftUI/`, `ViewModifiers/`, `Helpers/` (`SizeClassAdaptiveView`), `Closure/`
- **`Source/iOS/`** - iOS-only view modifiers (keyboard)
- **`Source/macOS/`** - AppKit and macOS-only extensions (`NSWindow` titlebar, `NSScreen`, keyboard type)

### Local packages (`Packages/`)

| Package | Products | Content |
|---|---|---|
| `WardAxisTelemetry` | `WardAxisTelemetry` | `Log` facade over `os.Logger`, file sink, `TelemetryService` (opt-in) |
| `WardAxisManagement` | `WardAxisManagement`, `WardAxisManagementTestSupport` | Server endpoint configuration, configuration feed, client identity, Keychain storage |
| `WardAxisManagementAPI` | `WardAxisAPIClient`, `WardAxisAPIServer`, `WardAxisAPIFixtures` | OpenAPI contract and generated code; golden frames |

### Other folders

- **`Resources/`** - `Assets.xcassets`, `Colors.xcassets`, `Localizable.xcstrings`, `InfoPlist.xcstrings`, `Info.plist`, `entitlement.entitlements`, `PrivacyInfo.xcprivacy`
- **`Configurations/`** - `base.xcconfig`, `debug.xcconfig`, `release.xcconfig`, `sign.xcconfig`, `app/`, `tests/`
- **`Tests/UnitTests/`** - Swift Testing suites: `Core/`, `Features/Settings/`, `Logger/`, `Navigation/`
- **`Tests/UITests/`** - XCUITest
- **`Server/`** - Management server (Hummingbird 2, PostgreSQL); see [Server/README.md](Server/README.md)

- **MUST** add every new test file to the test target's membership list. The `Tests` folder entry in `WardAxis.xcodeproj/project.xcproj` has a `membership-exceptions` list per target (`UnitTests`, `UITests`). A file missing from that list compiles into no target, and its tests never run, without any error.

---

## Quick Find Commands

```bash
# Find a SwiftUI view
rg -n "struct .*: View" Source/Shared

# List the navigation routes
rg -n "^\s+case " Source/Shared/Navigation/Route.swift

# Find @MainActor usage
rg -n "@MainActor" Source/

# List log calls, to review their privacy labels
rg -n "logger\.(debug|info|warning|error)\(" Source Packages/*/Sources
```

---

## Security Guidelines

### Secrets Management

- **NEVER** commit tokens, API keys, certificates or private keys
- **NEVER** log matched content, credentials or PII. An unlabeled `Log` message is `.private`; pass `privacy: .public` only for a fixed string
- Keep secrets in the Keychain only (`KeychainItemStore`, data protection keychain, `AfterFirstUnlockThisDeviceOnly`, not synchronizable)
- Keep build-time values in `.xcconfig` files

### Signing

- `APP_BUNDLE_ID` in `Configurations/base.xcconfig` is `com.agnidia.wardaxis`. Test bundles add `.tests` and `.uitests`.
- `DEVELOPMENT_TEAM` in `Configurations/sign.xcconfig` is an individual development team until the Agnidia organization enrollment at the start of Phase 5 (ORG-001, issue #192).

### Safe Operations

- Review bash commands before execution
- Confirm before: `git push --force`, `rm -rf`, any destructive operation

---

## Git Workflow

- Branch from `master`: `<type>/<issue>-<slug>`, for example `chore/5-wardaxis-project-setup`
- Use Conventional Commits; prefix the issue number when there is one, for example `#1 chore(github): Add issue forms and security policy`
- Run the quality gate locally before you open a PR

---

## Platform-Specific Notes

### Supported Platforms

| Platform | Min Version | Notes |
|----------|-------------|-------|
| iOS / iPadOS | 26.0 | Full feature set, haptics |
| macOS | 26.0 | App Sandbox and Hardened Runtime on; AppKit extensions in `Source/macOS/` |
| tvOS | 26.0 | Focus-based navigation; haptics are a no-op; the log viewer is a placeholder |

Deployment targets live in `Configurations/base.xcconfig` (`*_DEPLOYMENT_TARGET`). The project has no watchOS or visionOS target.

### Platform Abstractions

Use extensions in `Source/Shared/Extensions/` for cross-platform compatibility.

---

## Claude Code Tooling (optional)

These skills, agents, and commands come from Claude Code plugins. Other agents can ignore this section.

### Critical Skills (Use Proactively)

| Skill | Usage |
|-------|-------|
| `apple-developer:skills` | Swift 6 language reference, SwiftUI/AppKit framework docs, concurrency patterns. **Use for all Swift syntax, API, and concurrency questions.** |

### Recommended Agents

| Task | Agent | When to Use |
|------|-------|-------------|
| General Apple development | `apple-developer:apple-developer` | Entry point for all Apple ecosystem work |
| Architecture decisions | `apple-developer:apple-architector` | Pattern selection, structure review |
| iOS/iPadOS features | `apple-developer:ios-developer` | SwiftUI, UIKit integration |
| macOS features | `apple-developer:macos-developer` | AppKit, MenuBarExtra, desktop patterns |
| tvOS features | `apple-developer:tvos-developer` | Focus Engine, Siri Remote |
| Security review | `apple-developer:security-auditor` | Keychain, entitlements, ATS, sandbox |
| Localization | `apple-developer:localizator` | String Catalogs (.xcstrings), i18n |

### Recommended Commands

| Command | Purpose |
|---------|---------|
| `/apple-developer:review-code` | Comprehensive code review |
| `/apple-developer:debug` | Triage and root-cause an error |
| `/apple-developer:fix-refactor` | Refactor using clean code / SOLID |
| `/apple-developer:gen-docs` | Generate DocC documentation |
| `/apple-developer:analyze-localization` | Analyze localization coverage |
