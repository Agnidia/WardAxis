# Accessibility

Accessibility is part of every screen, not a final step. The project supports it with:

1. **Identifiers**: every interactive element gets a stable `accessibilityIdentifier` for UI tests.
2. **Labels and hints**: every non-decorative element has a localized label and, where it helps, a hint.
3. **Announcements**: state changes that do not move focus are announced through `AccessibilityAnnouncer`.
4. **Haptics**: extra non-visual feedback through `HapticFeedbackService` (iOS only).

---

## Files

| File | Purpose |
|---|---|
| [`AccessibilityIdentifiers.swift`](../Source/Shared/Accessibility/AccessibilityIdentifiers.swift) | `AccessibilityProtocol` and the `AccessibilityID` namespace |
| [`AccessibilityModifiers.swift`](../Source/Shared/Accessibility/AccessibilityModifiers.swift) | `View` extensions that apply identifier, label, hint and traits in one call |
| [`AccessibilityAnnouncer.swift`](../Source/Shared/Accessibility/AccessibilityAnnouncer.swift) | `@MainActor` VoiceOver announcements (UIKit and AppKit) |
| [`HapticFeedbackService.swift`](../Source/Shared/Accessibility/HapticFeedbackService.swift) | `HapticFeedbackServiceProtocol`, the iOS implementation, the no-op implementation for macOS and tvOS, and the mock |

---

## Identifiers, labels and hints

Each feature has an enum in `AccessibilityID` that conforms to `AccessibilityProtocol`. The raw value is the identifier. The protocol derives the localized label and hint from it:

| Property | Value |
|---|---|
| `id` | The raw value, for example `home.settings` |
| `label` | `String(localized:)` of `accessibility.<id>.label` |
| `hint` | `String(localized:)` of `accessibility.<id>.hint` |

```swift
enum Home: String, AccessibilityProtocol, CaseIterable, Sendable {
    case settingsButton = "home.settings"

    var id: String {
        rawValue
    }
}
```

Existing enums: `Home`, `Logs`.

Add both keys to `Resources/Localizable.xcstrings`:

```
accessibility.home.settings.label = "Settings"
accessibility.home.settings.hint  = "Open app settings"
```

Why: UI tests target identifiers, not labels. Labels are localized and change. Identifiers stay stable.

---

## Modifiers

| Modifier | Use for |
|---|---|
| `.accessible(_:isButton:)` | Buttons and other interactive elements: label, hint, identifier, button trait |
| `.accessible(_:isButton:isEnabled:)` | Same, plus the disabled state |
| `.accessibleGroup(_:)` | A container read as one element (toggle rows, settings groups) |
| `.accessibleSelectable(...)` | Chips, radio rows, segments; adds `.isSelected` when selected |
| `.accessibleTextField(_:label:value:)` | Text input fields |
| `.accessibleProgress(...)` | Progress indicators |
| `.accessibleDecorativeImage()` | Images that carry no information; hidden from VoiceOver |
| `.accessibleImage(label:)` | Images that carry information |
| `.accessibilityAnnounce(_:when:)` | Announce when a condition becomes true |
| `.accessibilityAnnounceChange(_:value:)` | Announce on a value change |
| `.reduceMotionAnimation(_:value:reducedAnimation:)` | Animation that respects Reduce Motion |

Example from `HomeView`:

```swift
Button {
    coordinator.navigate(to: .settings)
    container.hapticFeedback.playSelection()
} label: {
    Image(systemName: "gear")
}
.accessible(AccessibilityID.Home.settingsButton)
```

### When to write a hint

- **Label only:** the name fully describes the action ("Done").
- **Label and hint:** the action has a result that the label does not show ("Clear logs: deletes every entry on this device").
- **No hint for visible help text:** VoiceOver would read it twice.

---

## Announcements

State changes that do not move focus must be announced. `AccessibilityAnnouncer` is a `@MainActor` enum with static methods. Each method does nothing when VoiceOver is off.

```swift
// `message` is an already localized String.
AccessibilityAnnouncer.announce(message)
AccessibilityAnnouncer.announceError(message)
AccessibilityAnnouncer.screenChanged()
AccessibilityAnnouncer.layoutChanged()
```

`CoordinatedMainTabView` calls `screenChanged()` on every tab change. Use announcements sparingly: each one interrupts what VoiceOver is reading.

---

## Haptics

`AppContainer.hapticFeedback` is an `any HapticFeedbackServiceProtocol`:

```swift
container.hapticFeedback.playSuccess()    // confirmation
container.hapticFeedback.playSelection()  // selection change
container.hapticFeedback.playError()      // failed or destructive action
```

| Platform | Implementation |
|---|---|
| iOS / iPadOS | UIKit feedback generators and Core Haptics |
| macOS, tvOS | No-op |

Haptics are an extra channel, never the only feedback. Always pair them with a visual or audible cue.

---

## Dynamic Type

Use the type presets in [`Typography.swift`](../Source/Shared/Design/Typography.swift) or the system text styles. Do not set a fixed size directly in a view:

```swift
Text(L.Main.Home.title)
    .subtitleLarge()          // project preset
Text(L.Main.Home.title)
    .font(.title)             // system text style, scales with Dynamic Type
```

Check every new screen at the largest accessibility text size.

---

## Color contrast

Use the semantic colors from [`Resources/Colors.xcassets`](../Resources/Colors.xcassets). Each has light and dark variants.

```swift
Text(...).foregroundStyle(Color.Label.primary)                       // correct
Text(...).foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))    // wrong
```

`AGENTS.md` forbids hardcoded colors. Check the contrast of a new color pair against WCAG 2.2 AA in both appearances.

---

## Reduced motion

Respect `accessibilityReduceMotion`. Use `.reduceMotionAnimation(_:value:reducedAnimation:)` or read the environment value:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

var animation: Animation? {
    reduceMotion ? nil : .spring()
}
```

---

## Audit checklist

Before you merge a feature:

- [ ] Every interactive element has an identifier.
- [ ] Every non-decorative element has a label.
- [ ] State changes that do not move focus are announced.
- [ ] Custom controls expose the correct traits (`.isHeader`, `.isButton`, `.isSelected`).
- [ ] The largest accessibility text size does not clip the layout.
- [ ] VoiceOver order matches the visual reading order.
- [ ] tvOS focus reaches every interactive element.
- [ ] All copy goes through the `L` enum.

---

## See also

- [LOCALIZATION.md](LOCALIZATION.md)
- [Apple: Accessibility fundamentals (SwiftUI)](https://developer.apple.com/documentation/swiftui/accessibility-fundamentals)
