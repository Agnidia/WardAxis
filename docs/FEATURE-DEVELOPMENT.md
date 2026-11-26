# Feature Development

End-to-end checklist for a new screen. Do the steps in order; each step depends on the one before it.

The example adds a hypothetical **About** screen that pushes from Home.

---

## 1. Define a route

Add a case to [`Source/Shared/Navigation/Route.swift`](../Source/Shared/Navigation/Route.swift):

```swift
enum Route: Hashable, Sendable {
    // ... existing cases
    /// About screen.
    case about
}
```

`Route.id` comes from `String(reflecting:)`, so a new case needs no `id` code.

Add the case to `defaultPresentation` in [`RoutePresentation.swift`](../Source/Shared/Navigation/RoutePresentation.swift). The switch is exhaustive, so the build fails until you do:

```swift
case .home, .help, .logs, .about:
    .push
```

---

## 2. Add localized strings

In [`Source/Shared/Localization/LocalizedStrings.swift`](../Source/Shared/Localization/LocalizedStrings.swift):

```swift
extension L {
    enum About {
        static var title: LocalizedStringKey {
            "about.title"
        }

        static var close: LocalizedStringKey {
            "about.close"
        }
    }
}
```

Add the keys to [`Resources/Localizable.xcstrings`](../Resources/Localizable.xcstrings) with English values. See [LOCALIZATION.md](LOCALIZATION.md).

---

## 3. Add accessibility identifiers

In [`Source/Shared/Accessibility/AccessibilityIdentifiers.swift`](../Source/Shared/Accessibility/AccessibilityIdentifiers.swift), inside `enum AccessibilityID`:

```swift
enum About: String, AccessibilityProtocol, CaseIterable, Sendable {
    case closeButton = "about.close"

    var id: String {
        rawValue
    }
}
```

`AccessibilityProtocol` derives the label key `accessibility.about.close.label` and the hint key `accessibility.about.close.hint`. Add both to the String Catalog. See [ACCESSIBILITY.md](ACCESSIBILITY.md).

---

## 4. Build the view

Feature screens live in `Source/Shared/Features/<Name>/`, with the view and its view model side by side:

- `Source/Shared/Features/About/AboutView.swift`
- `Source/Shared/Features/About/AboutViewModel.swift` (when the screen has logic)

```swift
import SwiftUI

@MainActor
struct AboutView: View {
    @Environment(\.coordinator) private var coordinator
    @Environment(\.appContainer) private var container

    var body: some View {
        VStack(spacing: CGFloat.spacing.xxl) {
            Text(L.About.title)
                .titleLarge()
                .foregroundStyle(Color.Label.primary)

            Spacer()

            Button(L.About.close) {
                coordinator.pop()
            }
            .buttonStyle(.main(isFullWidth: true))
            .accessible(AccessibilityID.About.closeButton)
        }
        .padding(CGFloat.padding.l)
        .task {
            container.telemetry.track(.screenViewed("about"))
        }
    }
}
```

Use the [design tokens](DESIGN.md). Never hardcode spacing, radius, color or copy. The `appContainer` and `coordinator` environment values are non-optional.

Give each new Swift file the project header (file name, `Created on <date>.`, `Copyright © <year> Agnidia. All rights reserved.`). SwiftFormat never writes or changes headers.

---

## 5. Register the route in the resolver

Add the case to `RouteResolver.view(for:)` in [`RouteResolver.swift`](../Source/Shared/Navigation/RouteResolver.swift). The switch is exhaustive:

```swift
case .about:
    AboutView()
```

Open it from a view: `coordinator.navigate(to: .about)`. If a URL must reach it, add a host to `AppCoordinator.handleDeepLink(_:)`.

---

## 6. Add a view model (when needed)

Put screen logic in an `@Observable @MainActor` view model. Inject its services through the initializer:

```swift
import Foundation
import Observation
import WardAxisTelemetry

@Observable @MainActor
final class AboutViewModel {
    private(set) var logEntryCount = 0

    private let logReader: any LogReaderServiceProtocol
    private let logger = Log(category: .ui)

    init(logReader: any LogReaderServiceProtocol) {
        self.logReader = logReader
    }

    func load() async {
        do {
            logEntryCount = try await logReader.loadEntries().count
        } catch {
            logger.error("About: log load failed: \(error)")
        }
    }
}
```

The view owns the model with `@State` and builds it from the container:

```swift
@State private var viewModel: AboutViewModel?

var body: some View {
    content
        .task {
            if viewModel == nil {
                viewModel = AboutViewModel(logReader: container.logReaderService)
            }
            await viewModel?.load()
        }
}
```

Never construct a service inside a view or a view model. A new long-lived service goes into `AppContainer`; see [AGENTS.md](../AGENTS.md#adding-a-service).

---

## 7. Write tests

Create `Tests/UnitTests/Features/About/AboutViewModelTests.swift`, then add its path to the `UnitTests` inclusion list in `WardAxis.xcodeproj/project.xcproj`. Without that entry the file compiles into no target and its tests never run.

```swift
import Testing
@testable import WardAxis

@Suite("AboutViewModel")
@MainActor
struct AboutViewModelTests {
    @Test
    func `load() counts the log entries`() async {
        let model = AboutViewModel(logReader: MockLogReaderService(scenario: .sampleEntries))

        await model.load()

        #expect(model.logEntryCount > 0)
    }

    @Test
    func `load() keeps zero when the reader fails`() async {
        let model = AboutViewModel(logReader: MockLogReaderService(scenario: .failure(.readFailed(underlying: "test"))))

        await model.load()

        #expect(model.logEntryCount == 0)
    }
}
```

See [TESTING.md](TESTING.md).

---

## 8. Format and verify

```bash
swiftformat .
xcodebuild -project WardAxis.xcodeproj -scheme WardAxis -configuration Debug \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile test
```

Run the app on macOS, an iOS simulator and a tvOS simulator. Walk the new flow. Turn on VoiceOver and check that labels and hints are read correctly.

---

## Pre-merge checklist

- [ ] `Route` case added
- [ ] Case added to `RoutePresentation.defaultPresentation`
- [ ] Case added to `RouteResolver.view(for:)`
- [ ] Deep-link host added in `AppCoordinator.handleDeepLink(_:)` (if a URL reaches it)
- [ ] `L` accessors added; `Localizable.xcstrings` updated, including `accessibility.*` keys
- [ ] View in `Source/Shared/Features/<Name>/`
- [ ] Accessibility identifiers added and applied
- [ ] View model is `@Observable @MainActor` (if present); services injected, not constructed
- [ ] Telemetry event names a UI element only (if present)
- [ ] Mock-backed unit tests exist and are in the `UnitTests` inclusion list
- [ ] No hardcoded spacing, color or copy
- [ ] Quality gate in [AGENTS.md](../AGENTS.md#quality-gates-run-before-pr) is green

---

## See also

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [DESIGN.md](DESIGN.md)
- [TESTING.md](TESTING.md)
- [ERROR-HANDLING.md](ERROR-HANDLING.md)
