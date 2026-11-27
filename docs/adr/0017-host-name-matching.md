# ADR 0017: Host name matching and normalization

## Status

Accepted on 2026-11-27 (NET-009, #15).

## Context

A rule names destinations in `match.destinationHosts`: host names and `*.` patterns in canonical form ([ADR 0011](0011-versioned-schemas.md) D3, [ADR 0015](0015-policy-schema.md) D2). Validation fixed the policy side. Nothing matched a flow's host against it, and nothing put the flow's host into the same form.

The flow's host is untrusted. It comes from the application or the network, in any spelling:

| Provider | Platform | Host name of a flow |
|---|---|---|
| `NetworkFilter`, content filter | macOS, iOS | `remoteHostname` when the application connected by name; `nil` when it connected by address |
| `DNSProxy` | macOS | The query name, in wire form |
| `URLFilter` | iOS | The URL host, which can be Unicode |
| `PacketTunnel` | tvOS | None for a plain packet; a name only where the provider parses DNS or SNI |

| Constraint | Source |
|---|---|
| Label-aware match; `fakeexample.test` never matches `example.test` | [roadmap 1.3](../../roadmap/01-network-security.md#13-policy-engine-wardaxispolicy), #15 |
| Normalize case, trailing dot and IDNA | #15 |
| Fields a platform cannot supply use the documented fallback | [roadmap 1.3](../../roadmap/01-network-security.md#13-policy-engine-wardaxispolicy), [ADR 0016](0016-application-identity-matching.md) D3 |
| Bounded work per flow | [ADR 0012](0012-bounded-client-processing.md) |

Trust boundary: TB10 (network flows and NE providers). The policy data crosses TB4.

| Threat | Example |
|---|---|
| H1: Suffix match without a label boundary | `fakeexample.test` matches `example.test` or `*.example.test` |
| H2: A spelling variant escapes a deny | `EXAMPLE.test`, `example.test.`, fullwidth `ｅxample.test`, `bücher.de` against `xn--bcher-kva.de` |
| H3: A malformed name escapes a deny | `exa mple.test`, `ex%41.test`, an invalid A-label `xn--zz.test`, or any name that has no canonical form |
| H6: The connecting stack resolves another name | `faß.de` is `xn--fa-hia.de` under nontransitional UTS 46 and `fass.de` under transitional processing, so a deny for one misses the other |
| H7: A flow without a name blocks everything | An IP-literal URL, or a tvOS packet with no DNS or SNI, reads as unknown, and one host-scoped deny rule applies to every such flow |
| H4: A wildcard covers its apex by accident | `*.example.test` matches `example.test` |
| H5: Unbounded work per flow | A 1 MiB reported name goes through IDNA mapping |

## Decision

### D1: One canonical form on both sides (H2, H3, H5, H6)

`FlowHost(normalizing:)` maps a reported name to the policy host-name form (`FieldRules.isHostName`, now public):

1. Refuse input over `PolicyLimits.maximumReportedHostLength` (1024 UTF-8 bytes) before any mapping.
2. ASCII input: fold `A–Z` to lowercase. Nothing else changes.
3. Non-ASCII input: UTS 46 nontransitional mapping and punycode through Foundation (`URLComponents.host`, then `encodedHost`). A result with `%` or a non-ASCII byte is refused.
4. Remove one trailing dot. A second one stays and is refused.
5. Accept only when the result passes `FieldRules.isHostName`.
6. Check every `xn--` label, on both paths: it must decode (RFC 3492) and map back through step 3 to the same bytes, the UTS 46 round trip. Foundation passes ASCII through unchecked, so without this step `xn--zz.test` would be a name while `ü.xn--zz` would not.
7. Refuse a label that decodes to a deviation character (U+00DF ß, U+03C2 ς, U+200C ZWNJ, U+200D ZWJ). Transitional and nontransitional processing map these differently, so the flow could reach a name that the policy does not see (H6). Uppercase ẞ maps to ß and is refused with it.

An IP literal (canonical IPv4, canonical IPv6, or IPv6 in brackets) is not a name. It is matched as a network (NET-010); see D3. A short, octal or hexadecimal IPv4 form (`127.1`, `0x7f.1`) and an IPv4 in brackets have no canonical form and are malformed.

`FlowHost` holds ASCII only, so its equality and hash are byte equality.

### D2: Label-aware, byte-exact match (H1, H4)

`FlowHost.matches(_:)`:

| Pattern | Matches |
|---|---|
| `example.test` | The same bytes only |
| `*.example.test` | A host that ends in `.example.test` and has at least one more label. Not `example.test`, not `fakeexample.test` |

The dot stays in the compared suffix, so a match always ends on a label boundary. An unvalidated pattern cannot widen a match: a canonical host has no uppercase, `*` or trailing dot for it to hit.

### D3: A flow without a name is absent; an unreadable or malformed name is unknown (H3, H7)

A flow's host is an `Observed<FlowHost?>` ([ADR 0016](0016-application-identity-matching.md) D2):

| Flow host | `PolicyMatch.evaluateHost(_:)` | `deny` rule | `allow` rule |
|---|---|---|---|
| Known, a pattern matches | `match` | Applies | Applies |
| Known, no pattern matches | `noMatch` | Does not apply | Does not apply |
| `.known(nil)`: the flow has no host name | `noMatch` | Does not apply | Does not apply |
| `unknown`: the flow has a name that could not be read, or the reported name does not normalize | `unknown` | Applies | Does not apply |
| Rule without `destinationHosts` | `match` | Applies | Applies |

`FlowHost.observed(reportedName:)` maps a reported IP literal to `.known(nil)` and a name that does not normalize to `unknown`, so a malformed name never escapes a deny (H3) and an address never applies every host deny (H7).

A provider reports a flow as `.known(nil)` when the flow has no name to read (H7):

| Flow | Observed host |
|---|---|
| `remoteHostname == nil` on a socket flow: the application connected by address | `.known(nil)` |
| A provider with no name source for the flow, such as a plain packet in `PacketTunnel` with no DNS or SNI parsing | `.known(nil)` |
| A reported name, including an IP literal | `FlowHost.observed(reportedName:)` |
| A name source exists for the flow but returned nothing | `unknown` | `PolicyRule.hostApplies(to:)` applies the table; a disabled rule never applies. Combining criteria stays with the engine ([ADR 0015](0015-policy-schema.md) D3, NET-012). `ApplicationMatchResult` becomes `MatchResult`, the tri-state that every criterion shares.

## Alternatives considered

- **String suffix match (`hasSuffix`).** One line. It is H1. Rejected.
- **A wildcard also matches its apex.** One rule covers a site and its subdomains. ADR 0011 D3 defines `*.` as "any subdomain", and a silent widening is H4. Rejected; a policy lists both.
- **Own Punycode encoder without UTS 46 mapping.** No dependency on Foundation behavior. Without the mapping, `ｅxample.test` and `EXAMPLE.test` in Unicode form encode to names that differ from what the resolver looks up (H2). Rejected.
- **Non-ASCII input is unknown.** No IDNA at all. Every Unicode URL host on iOS would then apply every host-scoped deny rule. Rejected.
- **Every flow without a usable name is unknown.** One rule for all cases. Every connection by address, and every packet on tvOS, would then apply every host-scoped deny rule (H7). Rejected; network rules cover those flows.
- **Map deviation characters with transitional processing.** Matches older stacks. Newer stacks and browsers use nontransitional processing, so the mismatch only moves (H6). Rejected; a deviation is unknown.
- **Trust an ASCII A-label as it arrives.** No decoder. Invalid punycode then becomes a known name, while the same label in a Unicode name is unknown (H3). Rejected.

## Consequences

- IDNA follows the Foundation version of the OS. `HostMatchingTests` pins the expected outputs (`bücher.de`, fullwidth, U+3002 full stop, Cyrillic `а`) on macOS, and on iOS and tvOS simulators, so a change in the mapping fails the suite.
- A name with ß, ς, ZWJ or ZWNJ is unknown: a host-scoped deny applies to it and an allow never does. A policy cannot allow such a name by host.
- An application that connects by address, and a flow from a provider with no name source, pass a host-only deny rule. A policy that must block a destination also names its networks (NET-010). On tvOS `PacketTunnel` without DNS or SNI parsing, host rules never apply. DNS-to-flow correlation is out of scope here.
- A wildcard over a public suffix (`*.co.uk`) still passes validation and matches every name under it (ADR 0011 known gap). A public-suffix check needs a bundled list and its updates.
- Per flow, a match is at most 64 patterns of at most 255 bytes (`*.` and a 253-byte name), after one bounded normalization. The A-label check decodes at most 127 labels of at most 63 bytes.

## Validation

| Check | Kind | Scope | Decision |
|---|---|---|---|
| `HostMatchingTests` (`WardAxisPolicy`) | Unit tests | `fakeexample.test` against a name and a wildcard; the wildcard apex; subdomains; unvalidated patterns; case, trailing dot and IDNA spellings; refused names (spaces, `%`, `_`, non-canonical IPv4, a zone, label and name length, the input bound); invalid A-labels on both paths; deviation characters; IP literals as `.known(nil)`; byte-wise equality and hashing; the D3 table for `deny`, `allow`, disabled rules and rules without a host criterion | D1, D2, D3 |
| `HostMatchingTests` properties | Seeded property tests (SplitMix64, 4 seeds × 500 cases) | Normalization is idempotent and canonical; case and trailing-dot variants match alike; wildcards respect label boundaries; arbitrary input is refused, canonical, or an address that is never also a name | D1, D2, D3 |
| `xcodebuild -scheme WardAxisPolicy-Package test` on an iOS and a tvOS simulator, from `Packages/WardAxisPolicy` | Unit tests, per platform | The same suite against each platform's Foundation IDNA | D1 |
| `FieldRulesTests` (`WardAxisCore`) | Unit tests | The host-name rule that both sides share | D1 |
