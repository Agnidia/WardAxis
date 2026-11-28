# ADR 0020: Transport protocol and port matching

## Status

Accepted on 2026-11-28 (NET-011, #17).

## Context

A rule names a transport in `match.transport` (`tcp` or `udp`) and destination ports in `match.destinationPorts`: 1 to 32 inclusive `{first, last}` ranges in `1...65535` with `first <= last` ([ADR 0015](0015-policy-schema.md) D4). Validation fixed the policy side. Nothing matched a flow's transport and remote port against them.

The flow's transport and port are untrusted. They come from the provider:

| Provider | Platform | Transport | Remote port |
|---|---|---|---|
| `NetworkFilter`, content filter | macOS, iOS | Socket type and protocol | `remoteEndpoint`; on macOS `NWHostEndpoint.port` is text |
| `TransparentProxy` | macOS | `NEAppProxyTCPFlow` or `NEAppProxyUDPFlow` | The flow's remote endpoint |
| `DNSProxy` | macOS | UDP or TCP of the query | The resolver port |
| `URLFilter` | iOS | Unknown: the URL does not say TCP or QUIC over UDP | From the URL, explicit or by scheme |
| `PacketTunnel` | tvOS | The IP header; also ICMP and other protocols | The TCP or UDP header; none for other protocols |

| Constraint | Source |
|---|---|
| Protocol match; port ranges | #17 |
| Rule UDP 53 does not match a TCP 53 flow | #17 |
| Fields a platform cannot supply use the documented fallback | [roadmap 1.3](../../roadmap/01-network-security.md#13-policy-engine-wardaxispolicy), [ADR 0016](0016-application-identity-matching.md) D3 |
| A `match` with only a transport or only ports is valid | [ADR 0015](0015-policy-schema.md) D4 |
| Bounded work per flow | [ADR 0012](0012-bounded-client-processing.md) |

Trust boundary: TB10 (network flows and NE providers). The policy data crosses TB4.

| Threat | Example |
|---|---|
| P1: An edge of a range is off by one | `1024...49151` misses `49151`, or `53...53` covers `54` |
| P2: A port of the other transport matches | `deny udp 53` also blocks DNS over TCP, or `allow udp 443` lets TCP 443 through |
| P3: A range that bypassed validation changes a match | `{5, 1}`, `{0, 70000}` or `{-1, 53}` in a policy built in code or decoded without `validate()` widens an allow, or drops out of a deny |
| P4: An ambiguous or oversize reported port reads as another port | `053` is 43 to an octal reader; `+53`, ` 53`, `٥٣` (Arabic-Indic digits) or `65589` wrap or parse in one component and not in another; a 1 MiB string is parsed |
| P5: A flow without a port meets a port rule | ICMP through the tvOS packet tunnel is read as port 0, or as "any port" |
| P6: A provider that cannot tell the transport widens an allow or escapes a deny | An iOS URL filter reports an HTTPS URL that the system may fetch over HTTP/3 (UDP) |

## Decision

### D1: The port is a `UInt16`; reported text is canonical decimal only (P4)

`FlowPort` holds a `UInt16` and nothing else, so a provider value can never be out of range.

| Source | Accepted |
|---|---|
| `init(_:)` | The bits; the primary path for socket and packet providers |
| `init?(reported:)` | Text up to `PolicyLimits.maximumReportedPortLength` (5 bytes), checked before any parse. ASCII `0-9` only, no leading zero except `"0"`, value ≤ 65535 |

`FlowPort.observed(reported:)` maps refused text to `unknown`. A provider reports `.known(nil)` for a flow without a port.

### D2: Transport and port are two criteria (P1, P2, P5, P6)

`PolicyMatch.evaluateTransport(_:)` takes an `Observed<TransportProtocol?>`. `PolicyMatch.evaluatePort(_:)` takes an `Observed<FlowPort?>`. The port criterion does not depend on the transport: a ports-only rule covers TCP and UDP. A range is inclusive at both ends, compared in `Int` (P1).

| Flow field | `evaluateTransport` | `evaluatePort` | `deny` rule | `allow` rule |
|---|---|---|---|---|
| Known, equal to the rule's transport, or in a valid range | `match` | `match` | Applies | Applies |
| Known, no valid range contains it, one range bypassed validation (D3) | — | `unknown` | Applies | Does not apply |
| Known, the other transport, or in no range | `noMatch` | `noMatch` | Does not apply | Does not apply |
| `.known(nil)`: neither TCP nor UDP, or no port (ICMP) | `noMatch` | `noMatch` | Does not apply | Does not apply |
| `unknown`: the provider cannot tell (URL filter transport, refused port text) | `unknown` | `unknown` | Applies | Does not apply |
| Rule without the criterion | `match` | `match` | Applies | Applies |

`PolicyRule.transportApplies(to:port:)` joins the two with D4 and applies the result by action ([ADR 0016](0016-application-identity-matching.md) D3). A disabled rule never applies.

### D3: A range that bypassed validation is unknown (P3)

`evaluatePort(_:)` checks `PortRange.isValid` per range, which costs one compare per end. An invalid range is `unknown`, not `noMatch`: dropping it would narrow a deny. It never reports `match`, so it cannot widen an allow. A valid range that matches still decides. Ranges are not compiled: at most 32 per rule, each a pair of `Int`.

### D4: `MatchResult.and` joins criteria; a known contradiction is definite (P2)

`noMatch` wins over `unknown`, and `unknown` over `match`. `udp 53` against a TCP flow with an unknown port is `noMatch`: the transport alone rules it out, so a deny does not apply to traffic it never names. The engine (NET-012) reuses `and` to join every criterion.

## Alternatives considered

- **Ports scoped to the transport of the same rule, with no transport meaning "TCP only".** Mirrors some firewall syntaxes. ADR 0015 already allows a ports-only rule; reading it as TCP would let a UDP flow escape `deny 53` (P2). Rejected; a ports-only rule covers both.
- **Treat a flow without a port as port 0.** No `.known(nil)` case. Port 0 is not in any valid range, so the result is the same today, but a range that bypassed validation (`{0, 0}`) would then match ICMP (P5). Rejected.
- **`unknown` wins over `noMatch` in `and`.** Fails closed harder. A deny of `udp 53` would then apply to every TCP flow whose port is unknown, a block the policy never asked for. A known contradiction is definite. Rejected.
- **Parse reported text with `Int(_:)` or `strtol`.** Less code. `Int("+53")` is 53, `strtol` skips spaces and reads `0x35` with base 0 (P4). Rejected; the strict parse is a few lines.
- **Infer the URL filter's transport from the scheme (`https` is TCP).** Makes `allow tcp 443` apply. The system can use HTTP/3 over UDP for the same URL, so the inference is wrong for some flows (P6). Rejected; the transport is `unknown`.

## Consequences

- On iOS `URLFilter`, a transport-scoped `allow` rule never applies, and a transport-scoped `deny` rule applies to every URL whose other criteria match. A policy for that platform uses rules without `transport`, as it uses rules without `application` ([ADR 0016](0016-application-identity-matching.md)).
- ICMP and other non-TCP/UDP traffic meets no transport or port rule. A policy blocks it with a network or host rule, or with `defaultAction`.
- Per flow, `evaluatePort(_:)` does at most 32 range checks after one bounded parse of a reported port.
- A reported port is never logged.

## Validation

| Check | Kind | Scope | Decision |
|---|---|---|---|
| `TransportMatchingTests` (`WardAxisPolicy`) | Unit tests | The UDP 53 versus TCP 53 acceptance case for `deny` and `allow`; first, last, one-below and one-above ports of `1...1`, `53...53`, `443...444`, `1024...49151`, `65535...65535`, `1...65535`; port 0; ports-only and transport-only rules; `.known(nil)` and `unknown` fields; a known contradiction next to an unknown field; disabled rules; unvalidated ranges (`{5, 1}`, `{0, 70000}`, `{-1, 53}`, `{0, 0}`, `{65536, 65536}`, `{Int.min, Int.max}`) as `unknown`, and a valid range beside one; decoded and built rules alike; canonical and refused reported text, the 5-byte bound | D1, D2, D3, D4 |
| `TransportMatchingTests` properties | Seeded property tests (SplitMix64, 4 seeds × 500 cases) | Random range containment equals `ClosedRange.contains`; every port parses back from its decimal text, and never with a leading zero | D1, D2 |
