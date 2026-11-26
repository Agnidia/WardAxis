# Design System

The shared design system for the WardAxis app. All parts are pure SwiftUI and build for macOS, iOS/iPadOS and tvOS.

| Part | Location |
|---|---|
| Colors | `Resources/Colors.xcassets/` |
| Tokens | `Source/Shared/Design/Topology.swift` |
| Typography | `Source/Shared/Design/Typography.swift`, `Source/Shared/Design/Font+Custom.swift` |
| Button styles | `Source/Shared/Design/Buttons/` |
| Controls | `Source/Shared/Controls/` |
| Alerts | `Source/Shared/Services/Alert/`, `Source/Shared/Controls/AlertPresenter.swift` |
| Accessibility modifiers | `Source/Shared/Accessibility/` (see [ACCESSIBILITY.md](ACCESSIBILITY.md)) |

---

## Colors

Colors live in `Resources/Colors.xcassets/`. Xcode generates Swift symbols from them (`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`), for example `Color.Label.primary`. Every color has light and dark variants.

| Namespace | Purpose | Colors |
|---|---|---|
| `Background` | Surfaces | Primary, Secondary |
| `Button.Background` | Button fills | Primary (Default, Pressed, Disabled, Loading, Border.Default), Secondary (Default, Border: Default, Pressed, Disabled, Loading), Tertiary (Default) |
| `Button.Label` | Button text | Primary, Secondary, Tertiary; each Default, Pressed, Disabled, Loading |
| `State` | Feedback | Error, Success, Warning, Info, Accent |
| `Text` | Text | Primary, Secondary, Disabled, White |
| `Label` | Labels | Primary, Secondary, Disabled |
| `Textfield` | Inputs | Background, Text, Placeholder, Border (Primary, Focused, Accent) |
| `Border` | Structural borders | Primary, Secondary, Stroke |
| `Shadow` | Elevation | Primary |

```swift
Text(L.Main.Home.title)
    .foregroundStyle(Color.Label.primary)

RoundedRectangle(cornerRadius: CGFloat.radius.m)
    .fill(Color.Background.secondary)
```

Text fields and the search field draw `Textfield.Border.primary` at rest and `Textfield.Border.focused` while focused or edited. The `Button.*.Tertiary` colors remain in the catalog, but no button style uses them.

Never hardcode a color. To change a value, edit the colorset `Contents.json`; the namespace stays the same.

---

## Spacing, padding and radius

Defined as nested enums on `CGFloat` in `Topology.swift`. Write `CGFloat.spacing.m`, or `.spacing.m` where the type is `CGFloat`.

| Size | `spacing` | `padding` | `radius` |
|---|---|---|---|
| `xxs` | 1 | 1 | — |
| `xs` | 2 | 2 | 2 |
| `s` | 4 | 4 | 4 |
| `m` | 6 | 8 | 8 |
| `l` | 8 | 12 | 16 |
| `xl` | 10 | 16 | 24 |
| `xxl` | 12 | 24 | 32 |
| `xxxl` | 16 | 32 | 48 |
| `xxxxl` | 20 | 48 | — |

All values are points.

```swift
VStack(spacing: CGFloat.spacing.m) {
    Text(L.Splash.title)
        .padding(.horizontal, CGFloat.padding.m)
}
.padding(CGFloat.padding.l)
```

### Other tokens

| Token | Values |
|---|---|
| `CGFloat.blurRadius` | xxs 1, xs 4, s 8, m 16, l 32, xl 40 |
| `CGFloat.opacity` | 12 levels from `transparent` (0.0) to `opaque` (1.0) |
| `AnimationDuration` | zero 0, ultraFast 0.1, fast 0.2, normal 0.3, slow 0.6, ultraSlow 1.0 |
| `Delay` | ultraShort, short, normal, long, ultraLong, extraLong (derived from `AnimationDuration`) |
| `Scale` | collapsed 0.0; x0_10, x0_25, x0_50, x0_75; base 1.0; focus 1.01 (tvOS); hover 1.025 (macOS); x1_10, x1_25, x1_50, x1_75; doubled 2.0 |
| `Distance` | short 25, medium 50, long 100 |
| `Shadow` | hoverRadius 12, hoverY 4 |
| `IconSize` | xs 8, s 16, m 32, l 48, xl 64, xxl 128 |
| `ButtonSize` | s 24, m 48, l 64, xl 128 |
| `GridSize` | m 128, l 256 |
| `TextFieldSize` | height 40 |
| `CGFloat.lineWidth` | hairline 0.5, thin 1, regular 2, bold 3, heavy 4 (strokes and dividers) |
| `CGFloat.border` | primary 4, secondary 2, thin 1 (button and input borders) |
| `IconBadgeSize` | s 44, m 80, l 120, xl 160 |
| `BadgeSize` | s 18, m 22 |
| `CarouselDotSize` | inactive 6, active 8 |
| `FormSize` | Form control padding, radius and heights |
| `AlertSize` | Banner and accent alert radius, padding, icon size |
| `ButtonBackgroundType` | `.solid`, `.blurred`, `.clear` |

---

## Typography

### Font families (`Font+Custom.swift`)

| Method | Default design | Use for |
|---|---|---|
| `Font.editorial(size:)` | System serif | Display text, headings |
| `Font.flex(size:)` | System default | Body text |
| `Font.mono(size:weight:)` | System monospaced | Labels, buttons |

To use brand fonts, change these three functions to `Font.custom(_:size:)`.

### Presets (`Typography.swift`)

Each preset is a `View` method. It sets the font, size, line height, tracking and text case. `.typography(_:)` applies any `Typography` case.

| Preset | Size (pt) | Family | Uppercase |
|---|---|---|---|
| `.titleLarge()` | 40 | Serif | No |
| `.title()` | 32 | Serif | No |
| `.titleSmall()` | 16 | Mono | Yes |
| `.subtitleLarge()` | 26 | Serif | No |
| `.subtitleSmall()` | 20 | Serif | No |
| `.bodyLarge()` | 16 | Sans | No |
| `.bodyText()` | 14 | Sans | No |
| `.bodyMono()` | 14 | Mono | Yes |
| `.bodySerif()` | 14 | Serif | No |
| `.bodySmall()` | 12 | Mono | Yes |
| `.bodyAlertSmall()` | 12 | Sans | Yes |
| `.labelLarge()` | 24 | Mono | No |
| `.labelBold()` | 16 | Mono bold | No |
| `.labelRegular()` | 16 | Mono | No |
| `.labelSmall()` | 12 | Mono bold | No |
| `.buttonLarge()` | 16 | Mono | Yes |
| `.buttonLargeTertiary()` | 16 | Mono | No |
| `.buttonMedium()` | 16 | Mono | No |
| `.buttonSmall()` | 12 | Mono | Yes |

```swift
Text(L.Splash.title)
    .titleLarge()
    .foregroundStyle(Color.Label.primary)
```

To add a style: add a `Typography` case, map it in `font`, `size`, `lineHeight`, `tracking`, `textCase` and the font-height switch, then add a `View` preset.

---

## Button styles

All styles take a `ButtonState`: `.base`, `.loading` (shimmer), `.complete`.

| Style | Static constructors | Look |
|---|---|---|
| `MainButtonStyle` | `.main(state:isFullWidth:)`, `.mainIconOnly(state:)` | Filled, brand colors |
| `SecondaryButtonStyle` | `.secondary(state:isFullWidth:backgroundType:)`, `.secondaryIconOnly(state:backgroundType:)` | Outlined; `.blurred` background by default |

```swift
Button(L.Common.done) { }
    .buttonStyle(.main(isFullWidth: true))

Button(L.Main.Home.helpCenter) { }
    .buttonStyle(.secondary(isFullWidth: true, backgroundType: .solid))
```

---

## Controls

All in `Source/Shared/Controls/`. Controls that take an `accessibility` or `accessibilityConfig` parameter need an `AccessibilityProtocol` value.

| Control | Purpose | Initializer |
|---|---|---|
| `AccentAlert` | Full-width alert bar | `init(message:style:isLoading:onTap:)`; `style` is `.accent` or `.alert` |
| `BannerAlert` | Pill-shaped banner | `init(message:type:onTap:)`; `type` is `BannerAlertType` |
| `BackButton` | Navigation back button | Action and accessibility config |
| `CustomLabel` | Icon and text label | Memberwise: `title`, `icon` (`ImageResource`), `iconSize` |
| `ErrorTag` | Inline error message | `ErrorTag(message:)` |
| `FlowLayout` | Wrapping `Layout` | `FlowLayout(spacing:)` |
| `FormTextField` | Labeled text input with error text | Label, placeholder, binding, accessibility config |
| `IconBadge` | Icon in a colored badge | Color and `IconBadgeSize` |
| `ProgressDots`, `SimpleProgressDots` | Step indicators | Current step and colors |
| `RowView` | Tappable settings row | Label, content, accessibility config, action |
| `SearchField` | Search input | `init(placeholder:text:accessibility:)` |
| `SelectableChip` | Selectable chip | Title, selection, accessibility config, action |
| `TagPill` | Tag | `TagPill(tag:)` |
| `ToggleRow` | Toggle row | `init(label:isOn:showDivider:accessibility:)` |

---

## Alert system

`AlertManager` (`@MainActor @Observable`) holds the current `InAppAlert`. `RootView` attaches `AlertPresenterModifier` to the main content, so every screen can show alerts through `AppContainer.alertManager`. The `alertPresenter(alertManager:)` view method attaches the same modifier.

```swift
container.alertManager.show(.banner(message: message, type: .success))
container.alertManager.show(.accent(message: message, isLoading: true))
container.alertManager.dismiss()
```

| Alert | Look | Auto-dismiss |
|---|---|---|
| `.banner(message:type: .success)` | Green banner, check mark | 3 s |
| `.banner(message:type: .info)` | Orange banner | 3 s |
| `.banner(message:type: .error)` | Red banner, X icon | 5 s |
| `.accent(message:)` | Full-width accent bar | 3 s |
| `.accent(message:isLoading: true)` | Accent bar with spinner | Never; call `dismiss()` |

---

## View modifiers

### Shimmer

`Source/Shared/ViewModifiers/Animation/ShimmerEffect.swift`:

```swift
RoundedRectangle(cornerRadius: CGFloat.radius.m)
    .shimmerEffect(colors: [.clear, .white.opacity(0.3), .clear], isEnabled: isLoading)

view.shimmerEffect(colors: colors, isEnabled: isLoading, mask: RoundedRectangle(cornerRadius: CGFloat.radius.m))
```

### Hiding a view

`Source/Shared/Extensions/SwiftUI/View/View+IsHidden.swift`:

| Method | Effect |
|---|---|
| `.isHidden(_:)` | Removes the view from the layout (renders nothing) |
| `.isJustHidden(_:)` | Hides the view but keeps its space (`.hidden()`) |

```swift
ProgressView()
    .isHidden(!isLoading)
```

### Reduce Motion

```swift
Circle()
    .reduceMotionAnimation(
        .easeInOut(duration: AnimationDuration.slow),
        value: isAnimating,
        reducedAnimation: nil
    )
```

---

## File structure

```
Source/Shared/
  Design/
    Topology.swift            # Tokens
    Typography.swift          # Text styles and presets
    Font+Custom.swift         # Font families (system defaults)
    Buttons/
      ButtonState.swift
      MainButtonStyle.swift
      SecondaryButtonStyle.swift
  Controls/                   # Shared controls, AlertPresenter
  Services/Alert/             # AlertManager, AlertManagerProtocol, InAppAlert
  ViewModifiers/Animation/
    ShimmerEffect.swift
  Accessibility/              # AccessibilityModifiers and identifiers
Resources/
  Colors.xcassets/            # Semantic colors, light and dark
```
