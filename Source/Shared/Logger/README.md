# Logger Module

## Overview

Logging has two parts:

| Part | Location | Contents |
|---|---|---|
| `Log` API | `Packages/WardAxisTelemetry/Sources/WardAxisTelemetry/` | `Log`, `Log+Constants` (`Level`, `Category`, `Privacy`, `Environment`, `Configuration`), `LogProtocol`, `LogMetadata`, `LogDateFormat`, `LoggingError`, `FileLogHandler`, `FileHandlerOutputStream` |
| Reader and viewer | `Source/Shared/Logger/` (this folder) | `Models/` (`LogEntry`, `LogDateRange`), `Service/` (`LogReaderService`, `LogReaderServiceProtocol`, `LogEntryParser`, `LogReaderError`), `UI/` (`LogRowView`, `LogLevelFilterBar`, `LogDateRangeFilterBar`, `LogDateRange+UI`, `Log.Level+UI`, `LogsUnavailableView`) |
| Viewer screen | `Source/Shared/Features/Logs/` | `LogsViewerView`, `LogsViewerViewModel` |

The `Log` API is in a package so that extensions can link it without the app target.

### Concurrency model

- Swift 6 language mode with complete strict concurrency.
- `Log` is a `Sendable` value type. Each call site builds its own `Log(category:)`.
- The global configuration and the date-formatter cache are guarded by `Synchronization.Mutex`.
- `FileLogHandler` and `LogReaderService` are actors. `LogsViewerViewModel` is `@Observable @MainActor`.

---

## Quick Start

```swift
import WardAxisTelemetry

let log = Log(category: .ui)

log.debug("View appeared", privacy: .public)
log.info("Settings opened", privacy: .public)
log.warning("Response was slow")
log.error("Cache write failed: \(error)")
```

Configure once at launch (`Application.init` does this):

```swift
Log.configure(for: .debug)   // or .release / .test
```

Change one value:

```swift
var config = Log.configuration
config.fileLogLevel = .all
Log.configure(config)
```

### Initializer

```swift
Log(category: .management)                            // active configuration
Log(category: .management, configuration: custom)     // override for this instance
Log(category: .management, url: components)           // adds host=port metadata to file lines
```

---

## Privacy

`LogProtocol` has two forms of each level method:

| Form | Privacy |
|---|---|
| `debug(_:)`, `info(_:)`, `warning(_:)`, `error(_:)` | `.private` |
| `debug(_:privacy:)`, `info(_:privacy:)`, `warning(_:privacy:)`, `error(_:privacy:)` | As given |

| Destination | `.public` | `.private` |
|---|---|---|
| Unified log (`os.Logger`) | Visible | Redacted unless private data is enabled |
| Log file, DEBUG build | Visible | Visible |
| Log file, Release build | Visible | `<private>` (`Log.Privacy.redactedPlaceholder`) |

Evidence: `LogPrivacyTests` in `Packages/WardAxisTelemetry/Tests/`.

---

## Log Levels

`Log.Level` is an `OptionSet`, so levels compose into sets.

| Level | Raw | Use for |
|---|---|---|
| `.error` | `1 << 0` | Failures that need attention |
| `.info` | `1 << 1` | Milestones in normal flow |
| `.debug` | `1 << 2` | Verbose detail for development |
| `.warning` | `1 << 3` | Recoverable issues or degraded state |

Sets: `Level.base` (`.error` only) and `Level.all` (all four). `.warning` and `.error` map to `OSLogType.error`.

---

## Log Categories

```swift
public enum Category: String, CaseIterable, Sendable {
    case application
    case ui
    case cache
    case storage
    case management
    case policy
    case filter
    case dns
    case tunnel
    case ipc
    case dlp
    case pki
}
```

The category is the `os.Logger` category. The subsystem is the main bundle identifier (`com.agnidia.wardaxis` for the app).

---

## Configuration

`Log.Configuration` is a `Sendable` struct.

| Property | Type | Purpose |
|---|---|---|
| `categoryStates` | `[Category: Bool]` | Which categories produce output; a missing key counts as disabled |
| `label` | `String` | Optional console label (for example `"[Tests]"`) |
| `consoleEmojis` | `[Level: String]` | Console prefix per level |
| `saveToFileByDefault` | `Bool` | Attach the shared file writer to new `Log` instances |
| `fileLogLevel` | `Level` | The set of levels written to the file |
| `dateDisplayStyle` | `DateDisplayStyle` | `.full`, `.short`, `.time`, `.none` |

### Built-in presets

| Environment | Categories enabled | `fileLogLevel` | `dateDisplayStyle` |
|---|---|---|---|
| `.debug` | All except `application` | `.debug` | `.time` |
| `.release` | None | `.error` | `.short` |
| `.test` | All | `.warning` | `.none` |

At start-up, `Log` picks `.test` when `XCTestConfigurationFilePath` is set, otherwise `.debug` or `.release` by the `DEBUG` flag. `Application.init` then applies `.debug` or `.release` explicitly.

`fileLogLevel` is a set: the file gets a message only when the set contains its level.

---

## File Logging

| Fact | Detail |
|---|---|
| Path | `Library/Logs/<bundle identifier>/log.log` in the user domain (inside the sandbox container); `Log.logDirectoryUrl` returns the folder |
| Writer | `FileLogHandler.shared`; `nil` when the main bundle has no identifier, and logging then falls back to the unified log only |
| Rotation | Keeps the last 100,000 lines, through the live `FileHandle` |
| Extensions | `Log` never attaches the file writer when the bundle path ends in `.appex`, `.systemextension` or `.xpc` |

### Log line format

```
[timestamp] [category] [level] message[ | key=value, ...]
```

The timestamp segment is absent when `dateDisplayStyle` is `.none`. The `key=value` part appears only for a `Log` built with `url:`. Example:

```
[14:32:01.042] [ui] [debug] Switching to tab: settings
```

---

## `FileLogHandler` — Singleton Justification (ADR-FileLogHandler-001)

`FileLogHandler.shared` is the **only** justified singleton in this codebase. The "no Singleton" rule in `AGENTS.md` applies to every other type.

Rationale:

- A `FileHandle` is a kernel descriptor. Several per-instance writers would leak descriptors and race on the same inode.
- One `actor` gives total write ordering through its serial executor.
- `clear()` truncates the live handle in place. Two writers cannot share an in-place truncation; one would orphan the other's seek position.
- Rotation rewrites through the same handle; per-instance writers would corrupt the file.

`Log` itself is **not** a singleton. Each call site builds its own `Log(category:)` value. Only the file writer is shared.

---

## In-App Log Viewer

`LogsViewerView` opens from **Settings → Diagnostics → Logs**, pushed on the Settings `NavigationStack` through `Route.logs`. It builds its `LogsViewerViewModel` from `AppContainer.logReaderService`.

| Feature | Detail |
|---|---|
| Filters | Level (error, warning, info, debug) and date range (10 min, 30 min, 1 hour, 1 day, all) |
| Refresh | Reloads the file |
| Share | `exportEntries(_:)` writes `wardaxis-logs-YYYYMMDD-HHmmss.txt` to the temporary directory; `ShareLink` presents it |
| Clear | `clearEntries()` truncates the live file through `FileLogHandler`; later writes land in the empty file |
| Copy | Long-press copies the raw line |

---

## `LogReaderService`

`actor` that reads, exports and clears the log file off the main actor.

| Feature | Detail |
|---|---|
| Init | `LogReaderService(fileURL:parser:streamingThresholdBytes:maxStreamedEntries:now:)`; every parameter has a default |
| Large files | At 5 MB or more, returns only the last 5,000 entries |
| Order | File order, oldest first; the view reverses it for display |
| Errors | `LogReaderError`: `fileMissing`, `permissionDenied`, `readFailed`, `writeFailed` |
| Test double | `MockLogReaderService(scenario:)` in `Source/Shared/Mocks/` |

---

## Platform Support Matrix

| Platform | Full viewer | Share | Clear | Copy |
|---|---|---|---|---|
| iOS / iPadOS | Yes | Yes | Yes | Yes (`UIPasteboard`, light haptic) |
| macOS | Yes | Yes | Yes | Yes (`NSPasteboard`) |
| tvOS | `LogsUnavailableView` placeholder | No | No | No |

---

## Best Practices

- Keep one `Log(category:)` as a `let` property on each type that logs.
- Match the level to the intent: `debug` for investigation, `info` for milestones, `warning` for degraded but recoverable, `error` for failures.
- Pass `privacy: .public` only for fixed strings.
- File writes are fire-and-forget on the actor; a log call never blocks the caller.
