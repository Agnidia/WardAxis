# ADR 0019: Shared API contract constants

## Status

Accepted on 2026-11-27.

## Context

The OpenAPI generator emits types for the HTTP operations and the `ConfigMessage` schemas. It emits nothing for the WebSocket route that serves `GET /config/stream`. The values that both sides of the config stream must agree on were therefore written twice: once in `ServerCore` and once in `WardAxisManagement`.

| Value | Server | Client |
|---|---|---|
| Stream path `config/stream` | `ConfigStreamController` | `ConfigurationStreamRequest` |
| Close codes 1000, 1001, 1008, 1011, 1013 and reason `lifetime` | `ConfigStreamSession` | `ConfigurationCloseRoute` |
| `servers` path rule | `APIBasePath.validate` | `APIConfiguration.validateContractPath` |
| Frame bound: 256 KiB, depth 32 | none | `ConfigurationLimits` |
| Error codes | `APIError` | none (the set is open for clients) |

| Constraint | Source |
|---|---|
| The spec is the only source of the HTTP contract | [ADR 0001](0001-swift-server-stack.md) |
| The client refuses a frame past its bounds before any decoding | [ADR 0012](0012-bounded-client-processing.md) |
| `ServerCore` imports only the approved remote packages | `Server/Package.swift` |

Trust boundary: TB4, device and management server ([THREAT-MODEL.md](../THREAT-MODEL.md#trust-boundaries)).

| Threat | Example |
|---|---|
| T1: The two sides drift apart | A server edit adds close code 1008 for a different reason. The client reads it as an identity refusal and stops the feed for good |
| T2: The server sends a frame that the client refuses | An administrator stores a 300 KiB value. The server sends the snapshot, the client refuses it unread, reconnects, and gets the same snapshot. The device never gets a configuration, and the server serves a reconnect loop |

## Decision

### D1: One hand-written contract target (T1)

The `WardAxisManagementAPI` package gets a third library, `WardAxisAPIContract`. It has no dependencies and no generator plugin. It holds `ConfigStream.path`, `ConfigStream.lifetimeReason`, `ConfigStreamCloseCode`, `ConfigStreamLimits`, `APIBasePathRule` and `APIErrorCode`. `ServerCore` and `WardAxisManagement` both read every one of these values from it. `ContractConstantsTests` checks each value against the text of `openapi.yaml`, so a change to the spec without the code, or the reverse, fails a test.

### D2: The server enforces the client's frame bound (T2)

Before it writes a snapshot or a delta, `ConfigStreamSession` runs the client's pre-scan, `BoundedJSON.isWithinBounds`, with `ConfigStreamLimits`. A frame that fails is not sent. The session logs the event without the content and closes with 1011. `ServerCore` links `WardAxisCore` for the scan only, so both sides run the same code. The spec states the bound.

## Alternatives considered

- **OpenAPI `x-` extensions read by a custom generator step.** This keeps one file. Rejected: it needs a second build plugin, which widens the plugin trust that `-skipPackagePluginValidation` grants.
- **Separate copies with a parity test.** This adds no target. Rejected (T1): the test needs both sides in one test target, and nothing stops a third copy.
- **Truncating or splitting an oversized frame on the server.** Rejected (T2): the client would apply a partial configuration as if it were complete.

## Consequences

- A new close code or error code is one edit in `WardAxisAPIContract` and one in the spec; the test catches a missed half.
- An oversized configuration now shows as a server error log and a 1011 close, not as a silent client refusal. A write-side bound in the admin path is still open.
- The cache file keeps the stream's bounds through `ConfigurationLimits`, because it holds what one frame carried.

## Validation

| Check | Kind | Scope | Decision |
|---|---|---|---|
| `ContractConstantsTests` (WardAxisManagementAPI) | Test | Path, close codes, reason, frame bound and error codes against `openapi.yaml`; base path rule | D1 |
| `ContractRouteTests` (Server) | Test | Base path rule on the server side | D1 |
| `APIBasePathTests` (WardAxisManagement) | Test | Base path rule on the client side | D1 |
| `ConfigStreamSnapshotTests` (Server) | Test | Oversized and over-deep snapshot and delta close with 1011, and no frame is sent | D2 |
