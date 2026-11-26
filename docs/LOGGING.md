# Logging

The `Log` API lives in the `WardAxisTelemetry` package, so the app and future extensions share it. The log reader and the in-app viewer live in the app (`Source/Shared/Logger/`, `Source/Shared/Features/Logs/`). The full reference is the [Logger README](../Source/Shared/Logger/README.md). This doc covers daily use.

---

## Quick start

```swift
import WardAxisTelemetry

private let logger = Log(category: .ui)

logger.debug("View appeared", privacy: .public)
logger.info("Settings opened", privacy: .public)
logger.warning("Response was slow")
logger.error("Cache write failed: \(error)")
```

`Log` is a `Sendable` value type over `os.Logger`. Keep one as a `private let` on the type that logs.

---

## Privacy

| Call | Privacy | Console (`os.Logger`) | Log file, Debug build | Log file, Release build |
|---|---|---|---|---|
| `logger.error("…")` (no label) | `.private` | Redacted unless private data is enabled | Full text | `<private>` |
| `logger.error("…", privacy: .private)` | `.private` | Same | Full text | `<private>` |
| `logger.error("…", privacy: .public)` | `.public` | Full text | Full text | Full text |

Unlabeled messages are private, so an interpolated value (host name, path, identifier, error text) never reaches a persisted log by omission. Pass `privacy: .public` only for a fixed string. Never log matched content, credentials or PII, with any label.

---

## Configuration

`Application.init` picks a preset:

```swift
#if DEBUG
Log.configure(for: .debug)
#else
Log.configure(for: .release)
#endif
```

| Preset | Categories enabled | `fileLogLevel` | Timestamp | Selected |
|---|---|---|---|---|
| `.debug` | All except `.application` | `.debug` | `.time` (`HH:mm:ss.SSS`) | `Application.init` in Debug |
| `.release` | None | `.error` | `.short` | `Application.init` in Release |
| `.test` | All | `.warning` | `.none` | At start-up when `XCTestConfigurationFilePath` is set |

`fileLogLevel` is a set, not a minimum. The file gets a message only when the set contains its level. Use `.all` to write every level. A disabled category writes nothing to the console or the file.

Change one field:

```swift
var config = Log.configuration
config.fileLogLevel = .all
Log.configure(config)
```

`Log.resetConfiguration()` restores the preset for the detected environment.

---

## Categories

Defined in `Packages/WardAxisTelemetry/Sources/WardAxisTelemetry/Log+Constants.swift`:

| Category | Use for |
|---|---|
| `.application` | App lifecycle, launch, telemetry sink |
| `.ui` | Views, navigation, user actions |
| `.cache` | Cache reads and writes (configuration cache) |
| `.storage` | Secure storage and erase markers |
| `.management` | Management server: endpoint, configuration feed |
| `.policy` | Policy evaluation |
| `.filter` | Network filtering |
| `.dns` | DNS handling |
| `.tunnel` | Packet tunnel |
| `.ipc` | Inter-process communication |
| `.dlp` | Data loss prevention |
| `.pki` | Certificates and identities |

To add a category, add a case to `Log.Category` and a prefix in `Category.prefix`. The presets build `categoryStates` from `Category.allCases`, so the new case gets the preset default.

---

## Levels

`Log.Level` is an `OptionSet`:

| Level | Use for |
|---|---|
| `.error` | A failure that the user or developer must know about |
| `.warning` | Degraded but recoverable: slow response, retry |
| `.info` | A milestone in normal flow |
| `.debug` | Verbose detail for development |

Sets: `.base` (`.error` only) and `.all` (all four).

---

## Signposts

`logger.signposter` returns an `OSSignposter` on the same subsystem and category, so Instruments shows intervals next to the messages:

```swift
let signposter = logger.signposter
let state = signposter.beginInterval("loadEntries")
defer { signposter.endInterval("loadEntries", state) }
```

---

## File output

| Fact | Detail |
|---|---|
| Path | `Library/Logs/<bundle identifier>/log.log` in the app's container (`Log.logDirectoryUrl` gives the folder) |
| Writer | `FileLogHandler.shared`, one `actor` for the process |
| Rotation | 4 MiB maximum; retains up to 2 MiB through the live handle, serialized with writes and clearing |
| Extensions | Never write a file. A bundle path that ends in `.appex`, `.systemextension` or `.xpc` logs to the unified log only, because extensions see flows, DNS queries and mail |
| Line format | `[timestamp] [category] [level] message[ | key=value, ...]` |

---

## In-app log viewer

Settings → Diagnostics → Logs pushes `LogsViewerView` (`Source/Shared/Features/Logs/`). It has:

- A level filter (error, warning, info, debug)
- A date-range filter (10 min, 30 min, 1 hour, 1 day, all)
- Refresh
- Share through `ShareLink`; the export file is a temporary `.txt`
- Clear, which truncates the log file in place

Open it from code with `coordinator.navigate(to: .logs)`.

| Platform | Viewer | Share | Clear |
|---|---|---|---|
| iOS / iPadOS | Full | Yes | Yes |
| macOS | Full | Yes | Yes |
| tvOS | `LogsUnavailableView` placeholder | No | No |

---

## Service interface

`LogReaderServiceProtocol` (`Sendable`) is the `AppContainer.logReaderService` slot. `LogReaderService` is an `actor` that reads, exports and clears the file off the main actor. Inject it into view models:

```swift
let viewModel = SettingsViewModel(logReader: container.logReaderService)
```

Tests and previews use `MockLogReaderService(scenario:)`.

---

## Best practices

- Keep `private let logger = Log(category: ...)` on the owning type. `Log` copies the active configuration at init.
- Match the level to the intent. Do not log routine events at `.error`.
- Log calls do not block. Do not wrap them in `Task { }`.

---

## Don't

- Do not use `print(...)`. It bypasses the logger and never reaches the log file.
- Do not create `os.Logger(subsystem:category:)` directly. Use `Log(category:)`, so the subsystem, privacy defaults and file output stay consistent.
- Do not pass `privacy: .public` for a message with interpolated values.

---

## See also

- [Logger README](../Source/Shared/Logger/README.md): module reference and the `FileLogHandler` singleton decision
- [TESTING.md](TESTING.md): `MockLogReaderService` in tests
