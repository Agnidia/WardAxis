# ADR 0012: Bounded client processing and explicit erase failures

## Status

Accepted on 2026-11-26 (application and extension code review).

## Context

The review found resource limits that bounded individual values but left queues and file reads unbounded.
It also found concurrent log rotation, hidden deletion failures, and an incomplete deep-link delivery path.

| Constraint | Source |
|---|---|
| Bound untrusted input and fail closed | AGENTS.md |
| No credentials or matched content in logs | AGENTS.md, LOGGING.md |
| Generation fences prevent stale credential writes | SecureItemVault |
| A delta gap requires a new snapshot | ConfigurationService |

Trust boundaries: TB2 for client configuration state, TB3 for credential deletion, TB4 for server frames, and TB14 for incoming application URLs.
Local log files are asset A3 and are writable by attacker X2 on macOS.

| Threat | Example |
|---|---|
| T1: Log rotation restores deleted data | Startup rotation writes its earlier snapshot after a clear |
| T2: Input exhausts memory or disk | A server floods bounded frames; a local log grows during a long session |
| T3: Failed erasure revives credentials | Both the marker write and the Keychain delete fail |
| T4: External URLs produce unintended navigation | An unrelated scheme or a URL containing credentials reaches the coordinator |

## Decision

### D1: One log owner and explicit deletion errors (T1)

`FileLogHandler` owns rotation, writes and clearing on one actor.
Startup rotation finishes before the writer becomes available; no detached task retains the file handle.
Clearing discards pending entries before truncating the live file and propagates failures to the caller.

### D2: Byte budgets before parsing and persistence (T2)

| Resource | Limit and overflow behavior |
|---|---|
| Log file | 4 MiB; retain at most 2 MiB of recent complete lines during rotation |
| Log entry | 16 KiB; truncate at a UTF-8 boundary with an explicit marker |
| Pending log writes | 64 entries; discard new entries while full |
| Log reader | Read at most the last 2 MiB, skip a cut first line, discard entries over 16 KiB, return at most 5,000 entries |
| Configuration transport | Eight events, each frame at most 256 KiB; terminate the connection on overflow |
| Configuration cache | One active operation and one latest pending save; deletion precedes pending loads and saves |

A configuration overflow never drops a frame and continues on the same connection.
The service reconnects after backoff and requires a fresh snapshot before applying deltas.
A full event queue may leave no room for the final close event; stream termination also triggers reconnection.
Cache coalescing keeps the latest complete configuration, not an audit history.
An enrollment change discards pending saves and loads belonging to the prior enrollment.
A failed cache delete blocks a subsequent cache load until deletion succeeds.

### D3: Incomplete erasure is an error (T3)

Marker operations throw a typed error rather than logging and returning success.
The vault establishes an in-memory erase fence before any erase I/O.
It still attempts deletion if marker creation fails: successful Keychain deletion establishes safety without a marker.
A failed delete or marker cleanup leaves the in-memory fence active.
A newer successful save and marker cleanup can supersede the erase.
If a save succeeds but marker cleanup fails, the vault retains the write generation and marks cleanup as pending.
A same-generation retry reads the stored value and completes cleanup only when that value matches the retry.
It never rewrites the credential or lowers the generation fence.
A later erase attempt cancels pending persist cleanup, including when deletion fails.

If both marker persistence and Keychain deletion fail, a durable erase record is not guaranteed.
Callers must report incomplete erasure and retry; they cannot promise safety after restart in that case.
A successfully persisted marker continues to suppress restoration after relaunch.
The current application has no enrollment caller; that future caller must honor this error contract.

### D4: Register and validate navigation-only URLs (T4)

`APP_URL_SCHEME` supplies the registered scheme and the coordinator's accepted scheme.
The App Store build uses `wardaxis`; the Lab build uses `wardaxis-lab` to avoid routing between builds.
The persistent root handles URLs during both splash and main content.
Only Home, Help and Settings navigation is accepted, with an optional trailing slash and at most 2,048 UTF-8 bytes.
Credentials, ports, other paths, query strings and fragments are refused without logging their content.
Repeated Help URLs replace the current navigation path instead of growing it.
These URLs grant no authorization and perform no enrollment or extension-management operation.

## Alternatives considered

- **Detached log rotation.** Avoids startup I/O but races with the owner of the same file handle. Rejected for T1.
- **Whole-file parsing followed by a suffix.** Simple, but the limit applies after allocation. Rejected for T2.
- **Drop configuration events and continue.** Bounds memory but can skip deltas. Rejected; overflow reconnects instead.
- **Queue every cache save.** Preserves intermediate snapshots but retains unbounded work. Rejected; the cache needs only the latest snapshot.
- **Ignore marker errors.** Keeps the API simple but gives callers no reliable erase result. Rejected for T3.
- **Accept arbitrary URL components.** Easy to extend but expands the untrusted grammar without a use case. Rejected for T4.

## Consequences

- Diagnostics can omit older entries and burst entries; unified logging remains independent.
- File-log deletion now throws. Callers must surface a failure rather than confirming deletion.
- Configuration persistence can skip intermediate versions while retaining the latest accepted state.
- No server contract, entitlement or extension capability changes are required.
- New enrollment code must treat erase failures as incomplete work, including the documented restart limitation.

## Validation

| Check | Kind | Scope | Decision |
|---|---|---|---|
| `FileLoggingTests` | Package tests | Rotation, concurrent submissions and clear, truncation failure, byte limits, UTF-8 truncation, tail reads | D1, D2 |
| `LogReaderServiceTests` | App tests | Bounded reads and oversize multiline entries | D2 |
| `ConfigurationWireTests`, `ConfigurationServiceTests` | Package tests | Transport overflow, fresh-snapshot recovery, stalled-cache coalescing and unenrollment ordering | D2 |
| `SecureItemVaultTests` | Package tests | Marker write and cleanup failures, delete failures, in-memory fences and relaunch with a persisted marker | D3 |
| `HostConfigurationTests`, `AppCoordinatorTests`, `LaunchUITests` | App and UI tests | Built scheme registration, malformed URLs and splash state; cold and warm delivery targets the reviewed macOS build and the OS handler on simulators | D4 |
