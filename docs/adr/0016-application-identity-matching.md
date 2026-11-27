# ADR 0016: Application identity matching and the unknown-identity fallback

## Status

Accepted on 2026-11-27 (NET-008, #14).

## Context

A rule names an application with an `ApplicationMatcher` ([ADR 0011](0011-versioned-schemas.md) D3, [ADR 0015](0015-policy-schema.md) D2). The matcher pins a Team ID or names an Apple platform binary. Its `matches(_:)` returned a `Bool` against a full `ApplicationIdentity`. It had no bundle ID, and it could not say "this flow's identity is unknown".

The providers do not see the same identity:

| Provider | Platform | Application identity of a flow |
|---|---|---|
| `NetworkFilter`, `TransparentProxy`, `DNSProxy` | macOS | Audit token: signing identifier, Team ID, platform-binary flag and bundle ID through the code signature. Unknown when the process exited or its PID was reused (`ApplicationIdentityResolverProtocol`) |
| Content filter | iOS | A source application identifier from the system. The iOS provider maps only the fields it can prove; the rest are unknown |
| `URLFilter` | iOS | None. A URL carries no application |
| `PacketTunnel` | tvOS | None. A packet carries no application |

| Constraint | Source |
|---|---|
| Match by bundle ID, Team ID and signing identifier; exact match | #14 |
| Fields a platform cannot supply evaluate to the documented unknown-identity fallback | [roadmap 1.3](../../roadmap/01-network-security.md#13-policy-engine-wardaxispolicy), #14 |
| "Unknown identity: documented fallback" on macOS, iOS and tvOS | [roadmap 1.7](../../roadmap/01-network-security.md#17-integration-test-matrix) |
| A resolver answer of `nil` is an unknown application, never a match | `ApplicationIdentityResolverProtocol` ([ADR 0011](0011-versioned-schemas.md)) |

Trust boundary: TB10 (network flows and NE providers). The policy data crosses TB4.

| Threat | Example |
|---|---|
| T1: Hiding the identity escapes a deny | A process exits right after it opens a flow, the resolver returns `nil`, and a rule that denies this application to a host is skipped |
| T2: A missing identity earns an allow | On tvOS no flow has an identity, and a rule that allows one application to a host allows every application |
| T3: A partial identity passes as a full one | A provider knows only the signing identifier, which any developer can claim, and the matcher treats the unknown Team ID as equal |
| T4: Unknown and absent are confused | "No Team ID" (ad hoc or platform binary) and "Team ID not supplied" read the same, so an ad hoc copy matches a platform-binary rule |
| T5: Two spellings compare equal | `String ==` is canonical equivalence: `com.example.K` with U+212A KELVIN SIGN equals `com.example.K` |
| T6: A bundle ID replaces the Team ID pin | A rule names a bundle ID and no Team ID, and any team that claims the bundle ID matches |

## Decision

### D1: Exact match on every named field (T5, T6)

`ApplicationMatcher` gains an optional `bundleIdentifier`. It narrows a match and never replaces the Team ID pin: validation still refuses a matcher without a Team ID or the platform-binary flag. `validate(at:)` checks the bundle ID with the signing-identifier token rule.

`WardAxisPolicy` evaluates a matcher. It compares each named field as UTF-8 bytes. There is no case folding, no prefix or suffix match and no Unicode normalization. `matches(_:)` is removed from `WardAxisCore`.

### D2: Unknown is a value of its own (T3, T4)

A provider describes a flow as a `FlowApplication`. Each field is `Observed.known(value)` or `Observed.unknown`. The team is `TeamAttribution`: `.team(id)`, `.platformBinary` or `.withoutTeam`. A bundle ID of `.known(nil)` is a code object with no bundle. An `ApplicationIdentity` maps its signing identifier and team as known. Its bundle ID maps as known when present and as unknown when `nil`, because `nil` can mean "not read"; only a provider that proves there is no bundle passes `.known(nil)`. A Team ID beside the platform-binary flag is a forged claim, so the team maps to unknown. A resolver answer of `nil` maps to `FlowApplication.unknown`. Equality and hashing of `FlowApplication` and `TeamAttribution` compare bytes, like the matcher, so a cache keyed by a flow cannot merge two spellings (T5).

`ApplicationMatcher.evaluate(_:)` returns:

| Result | When |
|---|---|
| `noMatch` | A known field differs from the matcher. This wins over any unknown field |
| `unknown` | No known field differs, and a field that the matcher names is unknown |
| `match` | Every field that the matcher names is known and equal |

A matcher that names no bundle ID ignores the bundle field. A matcher that skipped validation has no team to compare, so it never returns `match`.

### D3: Unknown fails closed by action (T1, T2)

`PolicyRule.applicationApplies(to:)` applies the fallback:

| Matcher result | `deny` rule | `allow` rule |
|---|---|---|
| `match` | Applies | Applies |
| `noMatch` | Does not apply | Does not apply |
| `unknown` | Applies | Does not apply |
| No `application` criterion | Applies | Applies |
| Rule disabled | Does not apply | Does not apply |

Losing or hiding the identity therefore never escapes a deny and never earns an allow. The other criteria and the resolution order stay with the engine ([ADR 0015](0015-policy-schema.md) D3, NET-012).

## Alternatives considered

- **An unknown identity skips the rule.** No over-blocking. A deny rule is then bypassed whenever the identity is missing, and on macOS a process can make it missing by exiting (T1). Rejected.
- **A policy field chooses the fallback (`unknownApplication: deny | skip`).** The issuer decides per policy. It is one more required field that two writers can set differently, and the safe choice must still be the default the issuer writes. Rejected for v1; revisit if the tvOS consequence below blocks a customer.
- **Unknown matches every rule.** Simple. An `allow` rule then grants access to every unidentified flow (T2). Rejected.
- **Compare with `String ==`.** Idiomatic. Canonical equivalence accepts different bytes (T5). Rejected.

## Consequences

- On a provider with no identity (tvOS `PacketTunnel`, iOS `URLFilter`), an application-scoped `deny` rule denies its destinations for every application, and an application-scoped `allow` rule never applies. A policy for those platforms uses rules without an application criterion. Decision explanations (NET-015) report the `unknown` result, so the effect is visible.
- Each provider owns its mapping to `FlowApplication`. A provider that cannot prove a field marks it `unknown`; it never guesses.
- `bundleIdentifier` is a new field of the policy schema v1, redefined in place before release ([ADR 0015](0015-policy-schema.md) D5).

## Validation

| Check | Kind | Scope | Decision |
|---|---|---|---|
| `ApplicationMatchingTests` (`WardAxisPolicy`) | Unit tests | Exact match on all three fields; differing signing ID, Team ID or bundle ID; case, prefix and suffix variants; U+212A; platform binary against team-signed and ad hoc copies; partial and fully unknown flows; a known mismatch beside unknown fields; an unvalidated matcher; a resolver `nil` bundle ID kept unknown; a forged team claim; byte-wise flow equality and hashing; the fallback for `deny` and `allow` rules, disabled rules and rules with no application criterion | D1, D2, D3 |
| `ApplicationMatcherTests` (`WardAxisCore`) | Unit tests | Well-formed, absent, malformed and oversize bundle IDs; a bundle ID without a Team ID is refused | D1 |
| `PolicyFixtureTests` (`WardAxisPolicy`) | Unit tests, fixtures | A rule with a bundle ID decodes and round-trips; a malformed bundle ID is refused at its path | D1 |
| Integration matrix "Unknown identity" | Manual, per platform | Each provider applies D3 to a flow with no identity | D3 |
