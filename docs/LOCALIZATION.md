# Localization

The app uses **String Catalogs** (`.xcstrings`) and a type-safe `L` enum. Views never use raw string keys.

---

## Files

| File | Purpose |
|---|---|
| [`Resources/Localizable.xcstrings`](../Resources/Localizable.xcstrings) | App strings |
| [`Resources/InfoPlist.xcstrings`](../Resources/InfoPlist.xcstrings) | Localized `Info.plist` values |
| [`Source/Shared/Localization/LocalizedStrings.swift`](../Source/Shared/Localization/LocalizedStrings.swift) | The `L` namespace |

Build settings (`Configurations/base.xcconfig`): `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`, `SWIFT_EMIT_LOC_STRINGS = YES`, `STRING_CATALOG_GENERATE_SYMBOLS = YES`. The development language is English.

---

## The `L` enum

`L` is a `@MainActor` namespace, organized by feature. Top-level groups: `Splash`, `Main` (`Tab`, `Home`), `Common`, `Settings` (`Logs`), `Help`.

```swift
@MainActor
enum L {
    enum Splash {
        static var title: LocalizedStringKey {
            "splash.title"
        }
    }

    enum Main {
        enum Tab {
            static var home: LocalizedStringKey {
                "main.tab.home"
            }

            static var settings: LocalizedStringKey {
                "main.tab.settings"
            }
        }
    }
}
```

An accessor returns `LocalizedStringKey` for SwiftUI `Text`, `Button` and `Label`. An accessor with arguments interpolates them into the key; the catalog entry holds the matching format (`settings.logs.entryCount %lld %lld`). Return `String` only when the caller needs a plain string:

```swift
static func entryCount(_ total: Int, _ hidden: Int) -> LocalizedStringKey {
    "settings.logs.entryCount \(total) \(hidden)"
}
```

---

## Usage in views

```swift
Text(L.Splash.title)
Button(L.Common.done) { dismiss() }
Label(L.Main.Tab.home, systemImage: "house")

// Interpolated
Text(L.Settings.Logs.entryCount(total, hidden))
```

Never:

```swift
Text("Welcome")                // hardcoded
Text(NSLocalizedString(...))   // bypasses the L enum
```

---

## Adding a new string

1. **Pick a key.** Use `feature.subfeature.purpose`, dot-separated, for example `settings.logs.title`.
2. **Add the catalog entry.** Open `Resources/Localizable.xcstrings` in Xcode and add the key with the English value.
3. **Add the `L` accessor.** Add a `static var` (or a `static func` for interpolation) under the matching nested enum.
4. **Use it.** Reference it as `L.Settings.Logs.title`.

### Interpolation and plurals

For locale-aware formatting, return an interpolated `LocalizedStringKey`:

```swift
static func entryCount(_ total: Int, _ hidden: Int) -> LocalizedStringKey {
    "settings.logs.entryCount \(total) \(hidden)"
}
```

The catalog entry `settings.logs.entryCount` holds the format with positional arguments (`%lld %lld`). Add plural variants in the catalog editor.

---

## Accessibility strings

Labels and hints use `accessibility.<id>.label` and `accessibility.<id>.hint`, where `<id>` is the `AccessibilityProtocol` identifier:

```
accessibility.home.settings.label = "Settings"
accessibility.home.settings.hint  = "Open app settings"
```

`AccessibilityProtocol` builds the key as a `String` first, then calls `String(localized: String.LocalizationValue(key))`. A key passed as an interpolated literal would become the format `accessibility.%@.label` and find no translation. See [ACCESSIBILITY.md](ACCESSIBILITY.md).

---

## Errors

`AppError.errorDescription` calls `String(localized:defaultValue:)` directly with keys under `errors.*`:

```swift
case .networkUnavailable:
    String(localized: "errors.networkUnavailable", defaultValue: "Network is unavailable.")
```

This keeps `AppError` free of `@MainActor` isolation. Add each new error key to the catalog under `errors.*`. The catalog today has `errors.networkUnavailable`, `errors.unauthorized`, `errors.invalidRequest`, `errors.rateLimited` and `errors.serverError`. `errors.unknown` is not in the catalog yet, so it shows its `defaultValue`.

---

## Adding a locale

1. In Xcode, select `Localizable.xcstrings`, press the add button and choose the locale.
2. The catalog creates entries for every existing key in the new locale.
3. Translate the values. Xcode shows the coverage per locale.

---

## Don't

- Do not hardcode `Text("...")` in views. SF Symbol names are the exception.
- Do not add two `L` accessors for the same key.
- Do not keep English copy in code comments and the translation in the catalog. Keep both in the catalog and reference it through `L`.

---

## See also

- [Apple: Localization](https://developer.apple.com/documentation/xcode/localization)
- [ACCESSIBILITY.md](ACCESSIBILITY.md)
