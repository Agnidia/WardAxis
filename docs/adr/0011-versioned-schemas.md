# ADR 0011: Versioned schema documents with strict decoding

## Status

Accepted on 2026-11-26 (PRE-009, #9).

## Context

Events, policies and application identities cross the boundaries between the server, the app, the extensions and the agent. Each of them is data that an untrusted or partly trusted peer can write.

| Constraint | Source |
|---|---|
| Decode with typed `Codable` only; validate and bound all untrusted input; fail closed | AGENTS.md, Development rules |
| Every consumer of configuration values has a typed model and rejects any other shape | [ADR 0010](0010-app-store-only-distribution.md) D3, [THREAT-MODEL.md](../THREAT-MODEL.md#threats-of-this-file) TM5 |
| Policies and rules are data. No expression language, no control flow | [ADR 0010](0010-app-store-only-distribution.md) D3 |
| Simulated, lab and App Store results are labeled separately | [roadmap/README.md](../../roadmap/README.md), [ADR 0009](0009-endpoint-security-lab-only.md) D3 |
| `WardAxisCore` holds the `Sendable` domain models and protocols; other packages depend on it | [roadmap/README.md](../../roadmap/README.md#shared-package-requirements) |

Trust boundary: TB4 (device and management server) today. TB2 (app and embedded components) and TB10 (flows and NE providers) use the same schemas when those components have logic.

| Threat | Example |
|---|---|
| T1: An old reader interprets a newer document with old rules | A v2 policy adds an `exceptions` list. A v1 reader ignores it and enforces more than the issuer meant, or less |
| T2: A misspelled or unknown field is ignored silently | `"applicaton": {...}` in a rule is skipped, so the rule matches every application |
| T3: One document type is accepted as another | An event document is passed where a policy is read |
| T4: A rule matches on a spoofable identity | A rule names only `com.example.browser`. Any developer can sign code with that identifier |
| T5: Deep or oversize input exhausts the stack or memory | A server value nested 10,000 levels deep crashes the decoder on a cooperative-pool thread |
| T6: A synthetic or lab event is reported as a real result | Fixture output appears in a benchmark as App Store enforcement |
| T7: Errors leak untrusted content into logs | A decode error message echoes a host name or a key from the input |
| T8: Two parsers read the same bytes differently | A rule holds `"action":"deny","action":"allow"`. `JSONDecoder` keeps `deny`, and a console that keeps the last copy shows `allow` |
| T9: One value has several spellings | `127.1`, `0x7f.0.0.1` and `127.0.0.1` name the same address, or `fe80::1%en0` is valid only on a device that has `en0` |

## Decision

### D1: One envelope, one version for the whole document (T1, T3)

Every document is `{"schema": <kind>, "schemaVersion": <Int>, "body": {...}}`. `schema` is one of `wardaxis.security-event`, `wardaxis.security-policy`, `wardaxis.application-identity`. The version governs the body and every nested type, so nested types carry no version.

`SchemaCodec` reads the envelope first. A different kind throws `wrongKind`. A version outside the type's `supportedVersions` throws `unsupportedVersion` before the body is decoded. A reader never guesses or downgrades. A new version adds a new supported range and its own decode path in the same change.

### D2: Strict decoding, in a fixed order (T2, T5, T8)

| Step | Refusal |
|---|---|
| `BoundedJSON` pre-scan: 64 KiB, depth 16, one strict JSON object with matching brackets and nothing after it | `outOfBounds` |
| `BoundedJSON` pre-scan: no key repeated within an object, compared after escapes are decoded | `duplicateField` |
| Envelope: `schema` string and integer `schemaVersion` | `malformed` |
| Kind and version (D1) | `wrongKind`, `unsupportedVersion` |
| Typed `Codable` decode; unknown enum cases included. A time must be `yyyy-MM-ddTHH:mm:ssZ`: no fraction, no offset | `wrongShape(path:)` |
| Key tree of the input is a subset of the key tree that the decoded value writes back | `unknownField(path:)` |
| `SchemaBody.validate()` | `invalid(SchemaViolation)` |

The unknown-field step refuses an explicit `null` for an optional field. Absence is the only way to omit one. `SchemaCodec.encode` validates and bounds its own output, so a writer never produces what a reader refuses. `BoundedJSON` is the same pre-scan that the configuration feed uses; `ConfigurationLimits` calls it with the feed's limits, so the feed refuses repeated keys too.

The body types decode only inside `SchemaCodec`. Each body's `init(from:)` requires a marker in the decoder's `userInfo` whose type cannot be named outside `WardAxisCore`, so a plain `JSONDecoder` cannot skip these steps. Nested types such as `PolicyRule` stay freely decodable: on their own they are not a policy.

### D3: Identity and host rules (T4, T9)

| Field | Rule |
|---|---|
| `ApplicationMatcher` | Pins `teamIdentifier`, or sets `isPlatformBinary` with no Team ID. A signing identifier alone is refused |
| `ApplicationIdentity` | A platform binary with a Team ID is refused as a contradictory claim |
| Team ID | Exactly ten of `A–Z 0–9` |
| Host name | ASCII, lowercase LDH labels, no trailing dot, last label not all digits. Internationalized names arrive as punycode |
| Host pattern | A host name, or `*.` and a name of at least two labels. `*.com` is refused. No public-suffix list is consulted, so `*.co.uk` passes (known gap) |
| Remote host of a flow | A host name, a dotted-quad IPv4 with no leading zeros, or an IPv6 address in RFC 5952 form. No zone, no embedded IPv4, no short or hex forms |
| Event time | Whole seconds; `validate()` refuses a fraction, which the wire format would drop |
| Policy rule | Names at least one criterion. A rule without one would override `defaultAction` |
| Policy | `defaultAction` is required, `revision` ≥ 1, rule identifiers are unique, at most 256 rules and 64 hosts per rule |

`ProcessReference` keys identity resolution by PID and PID version, so a reused PID never inherits an exited process's identity.

### D4: Provenance on every event (T6)

`SecurityEvent.provenance` is `live`, `synthetic` or `lab`, and is required. The synthetic sources in `WardAxisCoreSynthetic` emit `synthetic` only. A report keeps results of each provenance apart.

### D5: Errors carry schema paths only (T7)

A `SchemaError` path is built from schema keys and array indexes, such as `$.body.rules[2].action`. For an unknown field the path names the enclosing object, not the unknown key. No error holds a value from the input, so an error may be logged with `privacy: .public`. Events have no free-text, URL or content field.

### D6: Synthetic sources behind protocols

`SecurityEventSourceProtocol`, `ApplicationIdentityResolverProtocol` and `PolicySourceProtocol` live in `WardAxisCore`. The deterministic stand-ins (`SyntheticEventSource`, `SyntheticIdentityResolver`, `FixturePolicySource`) live in the separate `WardAxisCoreSynthetic` product, for tests and previews only. `SyntheticEventSource` is seeded (SplitMix64) and takes every choice straight from the raw stream, not from `Int.random(in:using:)`, whose mapping the standard library may change. A failure therefore reproduces from its seed on any toolchain. The initializer validates the catalog, so a batch never fails midway.

## Alternatives considered

- **Hand-written `init(from:)` per type that checks `allKeys`.** Explicit, and no second decode. Every new field needs an edit in two places, and a missed key fails open (T2). Rejected for the single generic key-tree check.
- **Lenient decoding: ignore unknown fields for forward compatibility.** Lets an old reader accept a newer document. It is T1 and T2 by design. Rejected; D1 versions the document instead.
- **A version per nested type.** Finer-grained evolution. Mixed versions inside one document multiply the cases to test. Rejected.
- **JSON Schema validation at runtime.** A standard format. It adds a dependency and a second, loose decode of the same bytes, against the typed-`Codable` rule. Rejected.

## Consequences

- `WardAxisManagement` depends on `WardAxisCore`. `ManagedConfiguration.document(_:forKey:)` is the typed read path for feed values (TM5). Nothing yet forces a consumer to use it; code review does.
- A new field or enum case needs a new schema version. A v1 reader refuses v2 documents until it is updated. The server must keep serving v1 to devices that have not updated.
- An explicit `null` for an optional field is refused. Writers omit the field.
- The unknown-field check decodes each document twice. The 64 KiB bound keeps the cost small.
- A wildcard over a public suffix (`*.co.uk`, `*.github.io`) passes validation. A public-suffix check needs a bundled list and its updates; it waits for the policy engine.
- `WardAxisCore` does not import `Network`, so the server can share these schemas later.
- `revision` gives a consumer what it needs to refuse a replayed older policy. The comparison and its storage come with signed policy distribution (roadmap ADR-011).

## Validation

| Check | Kind | Scope | Decision |
|---|---|---|---|
| `SchemaFixtureTests` | Unit tests, fixtures in `Packages/WardAxisCore/Tests/WardAxisCoreTests/Fixtures/` | Unknown versions, wrong kind, wrong shape, unknown and `null` fields, repeated keys, fractional and offset times, a plain `JSONDecoder` refused, every validation rule with its path | D1, D2, D3, D5 |
| `SchemaBoundsTests` | Unit tests | Oversize, too deep, not a strict object, trailing data, mismatched brackets, repeated keys, encoder refusals, rule and host limits | D2, D3 |
| `FieldRulesTests` | Unit tests | Host names, patterns, canonical IP literals, Team IDs, signing identifiers, homoglyphs | D3 |
| `SyntheticSourceTests` | Unit tests | Determinism from SplitMix64 alone, `synthetic` provenance, catalog checked at init, codec round trip, batch bounds, PID reuse, matcher pinning | D3, D4, D6 |
| `ConfigurationSchemaTests` (`WardAxisManagement`) | Unit tests | A feed value of the wrong shape, an unknown version or a non-object is refused; a frame with a repeated key is dropped | D2, ADR 0010 D3 |
