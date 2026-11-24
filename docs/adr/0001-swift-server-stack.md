# ADR 0001: Swift server stack

## Status

Accepted on 2026-10-11.

Amended on 2026-10-11 (#17): the OpenAPI generator pin is 1.13.0 with `exact:`. Superseded on 2026-11-24, see below.

Amended on 2026-10-11 (#19): the approved set adds `hummingbird-auth` (bcrypt password hashing) and `jwt-kit` (JWT signing and verification). See [Pinned versions](#pinned-versions).

Amended on 2026-11-24 (WardAxis #5): the template server became the WardAxis management server. See [WardAxis adoption](#wardaxis-adoption). Issue numbers in the earlier amendments and notes refer to the template project, not to WardAxis.

Amended on 2026-11-24 (WardAxis #5): the OpenAPI generator moves to `from: "1.14.0"` and the #17 `exact:` exception ends. `WardAxisManagementAPI` and `Server` raise their macOS floor to 26, the app's floor. See [Generator pin](#generator-pin-2026-11-24).

The pins in [Pinned versions](#pinned-versions) were checked against the upstream tags on 2026-10-11.

## Context

The app needs a server for milestone 1. The server owns accounts, configuration and a live configuration feed over WebSocket.

These constraints apply:

| Constraint | Source |
|---|---|
| The server is Swift, on the same Swift 6.4 toolchain as the app | `AGENTS.md` |
| Swift 6 language mode with strict concurrency, same as the app | `AGENTS.md` |
| One API contract feeds the server and the app; the two must not drift | Issue #16 |
| A developer runs the full stack on one machine | Issue #16 |
| Later tickets cite one decision ID, not a whole document | Issue #16 |

This ADR records four decisions, D1 to D4. Later tickets cite them by ID. The server scaffold (#18) and the API contract package (#17) apply them.

## Decision

### D1: Server framework

Use Hummingbird 2.

- Hummingbird 2 is built on SwiftNIO and Swift structured concurrency. Its public API is `Sendable` and builds clean in Swift 6 language mode.
- WebSocket support comes from `hummingbird-websocket`.
- OpenAPI server stubs bind to Hummingbird through `swift-openapi-hummingbird`.

### D2: Storage

Use PostgreSQL, run in Docker.

| Item | Decision |
|---|---|
| Database | PostgreSQL, image `postgres:18` |
| Driver | PostgresNIO, with SQL written by hand; no ORM |
| Local runtime | Docker Engine with the Compose v2 plugin (`docker compose`) |
| Compose file | `Server/compose.yaml` |
| Start command | `docker compose -f Server/compose.yaml up -d` |

#18 owns the compose file and its local credentials. No credential enters the repository.

### D3: Repository layout

Keep the server in this repository.

| Path | Kind | Contents |
|---|---|---|
| `Server/` | SwiftPM executable package | The Hummingbird 2 server and `Server/compose.yaml` |
| `Packages/WardAxisManagementAPI/` | SwiftPM library package | The OpenAPI spec and the `swift-openapi-generator` config |

`Packages/WardAxisManagementAPI/` exposes two products. Both are seams from the milestone-1 Shared Seams registry; the seam owner is #17.

| Product | Consumer | Contents |
|---|---|---|
| `WardAxisAPIServer` | `Server/` | Generated server types and handler protocol |
| `WardAxisAPIClient` | The app | Generated client and types |

The app depends on `WardAxisAPIClient` only. The server depends on `WardAxisAPIServer` only.

### D4: WebSocket contract

Describe the WebSocket messages in the same OpenAPI spec.

- Message schemas live in the spec under `components/schemas`. `swift-openapi-generator` generates their Swift types for both products.
- The spec documents the upgrade path: the HTTP `GET` operation, its `Upgrade: websocket` request and its `101 Switching Protocols` response.
- The envelope is the seam `ConfigMessage` (owner #17). It is a discriminated union of `ConfigSnapshot`, `ConfigDelta` and `ConfigHeartbeat`.
- Each of the three message types carries `version: Int64`.

#17 owns the exact schema fields. This ADR adds no type beyond the registry names above.

## Pinned versions

Every package row is a released upstream tag, checked with `git ls-remote --tags` on 2026-10-11.

| Component | Repository or image | Version | Major |
|---|---|---|---|
| Hummingbird | `https://github.com/hummingbird-project/hummingbird` | `2.27.1` | 2 |
| Hummingbird WebSocket | `https://github.com/hummingbird-project/hummingbird-websocket` | `2.8.1` | 2 |
| ~~OpenAPI Hummingbird transport~~ (removed 2026-11-24, see [WardAxis adoption](#wardaxis-adoption)) | `https://github.com/swift-server/swift-openapi-hummingbird` | `2.1.0` | 2 |
| OpenAPI generator | `https://github.com/apple/swift-openapi-generator` | `1.14.0` | 1 |
| OpenAPI runtime | `https://github.com/apple/swift-openapi-runtime` | `1.13.0` | 1 |
| PostgresNIO | `https://github.com/vapor/postgres-nio` | `1.33.1` | 1 |
| ~~Hummingbird Auth (product `HummingbirdBcrypt`)~~ (removed 2026-11-24, see [WardAxis adoption](#wardaxis-adoption)) | `https://github.com/hummingbird-project/hummingbird-auth` | `2.5.0` | 2 |
| ~~JWTKit~~ (removed 2026-11-24, see [WardAxis adoption](#wardaxis-adoption)) | `https://github.com/vapor/jwt-kit` | `5.7.1` | 5 |
| PostgreSQL image | Docker Hub `postgres:18` | `18` | 18 |
| Swift toolchain | Swift 6.4, Swift 6 language mode | `6.4` | 6 |

Apply each package pin in `Package.swift` with the `from:` form and commit `Package.resolved`:

```swift
.package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.27.1"),
```

| Rule | Reason |
|---|---|
| `from: "X.Y.Z"` with the version in the table | Lets SwiftPM resolve shared transitive packages within one major |
| Commit `Package.resolved` for `Server/` and `Packages/WardAxisManagementAPI/` | The resolved graph, not the manifest, makes builds reproducible |
| Set `swift-tools-version: 6.4` in both manifests | Every pinned package declares tools version 6.4 or lower |

Transitive packages are not pinned here.

### Generator pin (2026-11-24)

The #17 exception (`exact: "1.13.0"`) is withdrawn. `Packages/WardAxisManagementAPI/` uses `from: "1.14.0"`, like every other pin.

| Item | Detail |
|---|---|
| Cost | An Xcode build reports 27 `UnusedImportAccess` warnings in the generated sources (`Types*.swift`, `docs.swift`) of each product. `swift build` reports none. The warnings come from generated code (apple/swift-openapi-generator#946) and point to no defect in WardAxis code. |
| Reason | `exact:` blocked every generator patch release and stopped any graph that requires 1.13.1 or later from resolving. The generator is a build-time plugin and links into no product, so the warnings carry no runtime risk. |
| Platform floor | Both manifests declare macOS 26. `Server` depends on `WardAxisManagementAPI`, and SwiftPM refuses a root whose floor is lower than a dependency's. Linux builds ignore the floor. |
| Exit condition | When a release contains apple/swift-openapi-generator#947, raise the `from:` version to it. |

## Consequences

- The WebSocket needs a hand-written transport. `swift-openapi-generator` generates the message types but not a WebSocket client or server. The transport encodes and decodes the generated `ConfigMessage` type on both sides; the server side runs on `hummingbird-websocket`.
- The app and the server change the contract in one pull request. A contract change cannot ship to one side only.
- A pin bump is one pull request. It edits the table above and `Package.resolved` together.
- A major bump, a framework change or a storage change needs a new ADR that supersedes this one.
- The server has no ORM. Queries and migrations are SQL that the server owns.
- Running the server locally needs Docker.
- Note for #17: exclude the WebSocket upgrade `GET` operation from server code generation with a generator filter. Otherwise it becomes a required handler and collides with the `hummingbird-websocket` route.
- Note for #18: mount the `postgres:18` data volume at `/var/lib/postgresql`. The major-18 image keeps its data under that path, not under `/var/lib/postgresql/data`.

## Rejected alternatives

| Alternative | Reason for rejection | Revisit when |
|---|---|---|
| Vapor 4 | Its Swift 6 strict-concurrency support is weaker than Hummingbird 2's; Vapor 4 was designed before Swift concurrency | Vapor ships a new major built for Swift 6 strict concurrency |
| Fluent with PostgresKit | Adds an ORM layer and its model and query abstractions on top of the driver; D2 chose hand-written SQL on PostgresNIO | Hand-written SQL and migrations become a cost the server cannot carry |
| AsyncAPI for the WebSocket messages | A second spec and a second toolchain beside `swift-openapi-generator` | OpenAPI cannot describe a message the feed needs |
| A separate server repository | The contract drifts between two repositories and needs a release step to share it | The server gets a separate team or release cycle |
| `exact:` package requirements | Every security patch needs a manifest edit and can conflict with transitive requirements | Never; `Package.resolved` already gives reproducibility |

## WardAxis adoption

Decided on 2026-11-24 for WardAxis issue #5.

| Item | Decision |
|---|---|
| Framework | Hummingbird 2 stays (D1). It replaces the Vapor backend that the WardAxis roadmap named; the roadmap now says Hummingbird 2. The Vapor 4 rejection above still applies. |
| Toolchain | Swift 6.4 toolchain, Swift 6 language mode, `swift-tools-version: 6.4` in every manifest. Docker image `swift:6.4-noble`. |
| Accounts | Removed. WardAxis devices enroll and then authenticate with mTLS (roadmap §5.5); there are no user accounts. `hummingbird-auth`, `jwt-kit` and `swift-openapi-hummingbird` left the dependency set. |
| Test-only packages | `swift-asn1` 1.7.3, `swift-certificates` 1.21.0 and `swift-crypto` 4.5.2 build the test PKI. They link into `ServerTests` only. |
| Config feed | `/v1/config/stream` accepts only a client certificate that chains to the device CA in `TLS_CLIENT_CA_PATH`. Without that variable the route does not exist. No header is ever trusted for identity. |
| Contract | `WardAxisManagementAPI` 2.0.0: `/config/stream` with the OpenAPI `mutualTLS` scheme only. |

Known gaps, owned by the threat model (PRE-008) and the Phase 5 PKI work:

| Gap | Current mitigation |
|---|---|
| No CRL or OCSP check | A connection lifetime cap (15 min minus up to 3 min jitter) forces a new handshake, so a CA bundle change takes effect within one cap |
| Authorization is "holds a device-CA certificate"; no per-device authorization | The feed serves global configuration only; per-device data waits for the Phase 5 device API |
| With mTLS on, `/v1/health` also needs a client certificate | The container probe presents `HEALTHCHECK_CLIENT_CERTIFICATE_PATH` / `HEALTHCHECK_CLIENT_KEY_PATH` |
