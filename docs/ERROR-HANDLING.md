# Error Handling

Three rules:

1. **Map at the boundary.** A service maps its lower-layer errors to `AppError` before it returns to the presentation layer.
2. **Log at the catch site.** The code that decides what to do about an error logs it. Intermediate rethrows do not.
3. **Show the user only safe text through `AlertManager`.** An error that the user can act on becomes an alert. Everything else is a log entry only.

---

## The error type

[`Source/Shared/Core/Error/AppError.swift`](../Source/Shared/Core/Error/AppError.swift):

```swift
enum AppError: Error, Sendable {
    case networkUnavailable
    case unauthorized
    case invalidRequest
    case rateLimited(retryAfter: Int?)
    case serverError
    case unknown(any Error)
}
```

| Case | Meaning | User text key |
|---|---|---|
| `networkUnavailable` | The device cannot reach the network | `errors.networkUnavailable` |
| `unauthorized` | The server did not accept this device's identity | `errors.unauthorized` |
| `invalidRequest` | The server rejected the request as malformed | `errors.invalidRequest` |
| `rateLimited(retryAfter:)` | Too many requests; `retryAfter` is the server's wait in seconds, if sent | `errors.rateLimited` |
| `serverError` | The server failed, answered outside its contract, or is not configured | `errors.serverError` |
| `unknown(_:)` | An unexpected lower-layer error, kept for logging | `errors.unknown` |

`.unknown` never shows the underlying error text. A lower layer's text can name paths, hosts or OS codes, so `errorDescription` returns a fixed generic sentence.

No service in the app throws `AppError` yet. The configuration feed reports state (`configuration`, `isIdentityRejected`) instead of throwing. Use `AppError` for the first service that returns a failure to a view model.

Add a case when:

- The presentation layer must switch on it (different text or recovery action).
- A check at a call site is clearer than an opaque `Error`.

Otherwise wrap the error in `.unknown(_:)` and log the details at the catch site.

### Adding a case

1. Add the case to the enum.
2. Add the `errorDescription` branch with `String(localized: "errors.<case>", defaultValue: ...)`.
3. Add the English value under the same key in `Resources/Localizable.xcstrings`.

---

## Service layer

A service owns the mapping from lower-layer errors (`URLError`, decoding errors, typed package errors) to `AppError`. Views see only `AppError`.

```swift
func appError(for error: any Error) -> AppError {
    switch error {
    case let urlError as URLError where urlError.code == .notConnectedToInternet:
        .networkUnavailable
    default:
        .unknown(error)
    }
}
```

Package types throw their own typed errors and keep them free of secrets:

| Type | Error | Note |
|---|---|---|
| `APIConfiguration.resolve(rawValue:requiresHTTPS:)` | `APIConfigurationError` | Holds no part of the URL, so it is safe to log |
| `KeychainItemStore`, `SecureItemVault` | `SecureItemStoreError` | `unreadable`, `osStatus(Int32)`, `unavailable` |
| `ClientIdentityProvider.currentIdentity()` | `ClientIdentityError` | `osStatus(Int32)` |

---

## View-model layer

```swift
import Foundation
import Observation
import WardAxisTelemetry

@Observable @MainActor
final class LogSummaryViewModel {
    private(set) var entryCount = 0

    private let logReader: any LogReaderServiceProtocol
    private let alertManager: any AlertManagerProtocol
    private let logger = Log(category: .ui)

    init(logReader: any LogReaderServiceProtocol, alertManager: any AlertManagerProtocol) {
        self.logReader = logReader
        self.alertManager = alertManager
    }

    func load() async {
        do {
            entryCount = try await logReader.loadEntries().count
        } catch {
            // Unlabeled messages are private: the error text never reaches a release log file.
            logger.error("Log load failed: \(error)")
            alertManager.show(.banner(message: AppError.unknown(error).localizedDescription, type: .error))
        }
    }
}
```

- The view model decides whether the user sees the error.
- Log failures at `.error` or `.warning`, never `.debug`.
- The user-facing text comes from `AppError.errorDescription`, never from the raw error.

---

## Surfacing via `AlertManager`

[`AlertManager`](../Source/Shared/Services/Alert/AlertManager.swift) is the only path to in-app alerts. `RootView` attaches `AlertPresenterModifier` to the main content.

```swift
alertManager.show(.banner(message: "Saved", type: .success))
alertManager.show(.banner(message: error.localizedDescription, type: .error))
```

| Alert | Auto-dismiss |
|---|---|
| `.banner(message:type:)` with `.info` or `.success` | 3 s |
| `.banner(message:type:)` with `.error` | 5 s |
| `.accent(message:isLoading:)` | 3 s; never while `isLoading` is `true` |

Inject `any AlertManagerProtocol` from `AppContainer` into the view model's initializer. Do not keep a reference to `AppContainer` in a view model. The view model then stays independent of the container and easy to test.

---

## Don't

- Do not use `try!` outside `#Preview` blocks.
- Do not use `fatalError` for a recoverable condition. Log the error and fall back.
- Do not show `String(describing: error)` to the user. Use `AppError.errorDescription`.
- Do not catch an error and drop it silently. Log it at minimum.
- Do not show an alert from inside a service. Services throw; the presentation layer decides.
- Do not log an error with `privacy: .public`. Error text can hold paths, hosts or identifiers.

---

## Testing errors

Force the failure path with the mock scenario:

```swift
@Test("load() shows an error banner when the log reader fails")
@MainActor
func loadShowsBannerOnFailure() async {
    let alertManager = MockAlertManager()
    let model = LogSummaryViewModel(
        logReader: MockLogReaderService(scenario: .failure(.readFailed(underlying: "test"))),
        alertManager: alertManager
    )

    await model.load()

    #expect(alertManager.currentAlert != nil)
}
```

See [TESTING.md](TESTING.md) for the full patterns.

---

## See also

- [LOGGING.md](LOGGING.md)
- [LOCALIZATION.md](LOCALIZATION.md): error text keys are under `errors.*`
- [ARCHITECTURE.md](ARCHITECTURE.md)
