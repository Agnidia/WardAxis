# ADR 0018: CIDR network matching

## Status

Accepted on 2026-11-27 (NET-010, #16).

## Context

A rule names destination networks in `match.destinationNetworks`: canonical CIDR strings, IPv4 or IPv6, with every host bit zero ([ADR 0015](0015-policy-schema.md) D4). Validation fixed the policy side. Nothing matched a flow's remote address against them. [ADR 0017](0017-host-name-matching.md) D3 leaves every flow without a host name, including an IP literal, to the network rules.

The flow's address is untrusted. It comes from the provider, as bytes or as text:

| Provider | Platform | Remote address of a flow |
|---|---|---|
| `NetworkFilter`, content filter | macOS, iOS | `remoteEndpoint`; a dual-stack socket can report an IPv4 destination as `::ffff:a.b.c.d` |
| `TransparentProxy` | macOS | The flow's remote endpoint |
| `DNSProxy` | macOS | None for the query; the answer holds addresses, but a query is not a connection |
| `URLFilter` | iOS | None before the system resolves the name; an IP-literal URL host is text |
| `PacketTunnel` | tvOS | The packet header, as bytes |

On an IPv6-only network with NAT64 (a case App Review tests), an IPv4 destination arrives as `64:ff9b::a.b.c.d` or as an address under a network-specific prefix.

| Constraint | Source |
|---|---|
| IPv4 and IPv6 prefixes; boundary tests | #16 |
| Rule `2001:db8::/32` matches `2001:db8::1` | #16 |
| Fields a platform cannot supply use the documented fallback | [roadmap 1.3](../../roadmap/01-network-security.md#13-policy-engine-wardaxispolicy), [ADR 0016](0016-application-identity-matching.md) D3 |
| Validated strings are parsed for matching | [ADR 0015](0015-policy-schema.md) D4 |
| Bounded work per flow | [ADR 0012](0012-bounded-client-processing.md) |

Trust boundary: TB10 (network flows and NE providers). The policy data crosses TB4.

| Threat | Example |
|---|---|
| N1: An edge of the prefix is off by one | `192.0.2.0/24` misses `192.0.2.255` or covers `192.0.3.0`; `/0` builds its mask with a shift by the full width |
| N2: An IPv4-mapped address takes the other family's rules | A dual-stack socket to `::ffff:192.0.2.1` reaches `192.0.2.1`, but a deny of `192.0.2.0/24` compares it as IPv6, or an `allow ::/0` covers it while a plain IPv4 socket to the same host is denied |
| N3: A NAT64 address escapes an IPv4 deny, or widens an IPv4 allow | `64:ff9b::c000:201` reaches `192.0.2.1` through the network's NAT64 gateway. On a network without NAT64, or for a non-global address that RFC 6052 §3.1 forbids under the prefix, `64:ff9b::a00:1` reaches whatever router takes the prefix, not `10.0.0.1` |
| N4: An ambiguous spelling reads as another address | `0x7f.1`, `127.1` and `010.0.0.1` mean `127.0.0.1` or `8.0.0.1` to `inet_aton` and to a browser URL parser |
| N5: Unbounded work per flow | A 1 MiB reported address string is parsed |
| N6: An unvalidated pattern changes a match | `192.0.2.1/0` or `garbage` in a policy built in code or decoded without `validate()` widens an allow, or drops out of a deny |
| N7: Per-flow work grows with the policy | 256 rules × 64 networks parsed again on every flow |

## Decision

### D1: The address bits are the canonical form (N4, N5, N6)

`FlowAddress` holds a `UInt32` or a `UInt128` and nothing else, so two spellings of one address are equal. Every constructor turns an IPv4-mapped address (`::ffff:0:0/96`) into IPv4, the family it reaches on the wire (N2). One destination therefore meets the same rules from an IPv4 and from a dual-stack socket.

| Source | Accepted |
|---|---|
| `init(bytes:)` | 4 or 16 bytes in network byte order; the primary path for socket and packet providers |
| `init(ipv4:)`, `init(ipv6:)` | The bits |
| `init?(reported:)` | Text up to `PolicyLimits.maximumReportedAddressLength` (66 bytes), checked before any parse. IPv4: the canonical dotted quad only (`FieldRules.isCanonicalIPv4`). IPv6: any RFC 4291 §2.2 form, any case, leading zeros, one `::`, a canonical dotted IPv4 tail, optional brackets, a zone of 1–16 `[A-Za-z0-9._-]` that is dropped. The zone delimiter is `%`, or inside brackets also the RFC 6874 URI form `%25`. The longest legitimate form is 66 bytes |

Everything else is refused: short, octal and hex IPv4 forms, an IPv4 in brackets or with a zone, a sign before a hex group, a second `::`, a non-ASCII digit. The parse is our own, not `inet_pton` or `inet_aton`, so the meaning never depends on libc.

`FieldRules.canonicalNetwork(_:)` (`WardAxisCore`, public) returns the bytes and prefix length of a canonical network; `isCanonicalNetwork(_:)` now calls it. Validation and matching share one parse. It also refuses an IPv6 network inside `::ffff:0:0/96` in any spelling (`::ffff:c000:200/120`, not only the dotted form of ADR 0015 D4): no flow is ever a mapped IPv6 address, so such a network would never match (N2). A policy writes it as IPv4.

`IPNetwork(_:)` builds from that parse only, so a string that validation refuses never becomes a network. `PolicyMatch` compiles `destinationNetworks` into `IPNetwork` values once, when it is created or decoded, so a flow costs no string parse (N7). The compiled form is not encoded.

### D2: Masked containment; a NAT64 address is unknown to an IPv4 network (N1, N2, N3)

`IPNetwork.evaluate(_:)` compares `address & mask == network`. The mask is `0` for `/0` and `.max << (width − prefix)` otherwise (N1).

| Network | Flow address | Result |
|---|---|---|
| IPv4 | IPv4, including an IPv4-mapped address (D1) | `match` when the masked bits are equal, else `noMatch` |
| IPv4 | IPv6 in `64:ff9b::/96` (NAT64 well-known prefix, RFC 6052) whose embedded IPv4 is in the network | `unknown` |
| IPv4 | Any other IPv6 | `noMatch` |
| IPv6 | IPv6, including NAT64 | `match` when all 128 bits, masked, are equal, else `noMatch` |
| IPv6 | IPv4 | `noMatch`, so `::/0` means "all IPv6" and does not cover IPv4 |

The NAT64 address reaches the embedded IPv4 host only where the network translates it, and this pure package cannot know that. `unknown` lets an IPv4 deny apply (N3, escape) and keeps an IPv4 allow from applying (N3, widening). A policy that allows a NAT64 destination names it as IPv6 (`64:ff9b::c000:200/120`), which matches exactly.

### D3: A flow without an address is absent; an unreadable address is unknown

A flow's address is an `Observed<FlowAddress?>` ([ADR 0016](0016-application-identity-matching.md) D2), with the same table as the host criterion ([ADR 0017](0017-host-name-matching.md) D3):

| Flow address | `PolicyMatch.evaluateNetwork(_:)` | `deny` rule | `allow` rule |
|---|---|---|---|
| Known, a network matches | `match` | Applies | Applies |
| Known, no network matches, and one is `unknown` (D2) or bypassed validation | `unknown` | Applies | Does not apply |
| Known, no network matches | `noMatch` | Does not apply | Does not apply |
| `.known(nil)`: no address at this layer (a URL before resolution, a DNS query) | `noMatch` | Does not apply | Does not apply |
| `unknown`: a reported address that does not parse | `unknown` | Applies | Does not apply |
| Rule without `destinationNetworks` | `match` | Applies | Applies |

A network entry that bypassed validation is `unknown`, not `noMatch`: dropping it would narrow a deny (N6). A valid entry that matches still decides.

`FlowAddress.observed(reported:)` maps text that does not parse, a host name included, to `unknown`, so an ambiguous spelling never escapes a deny (N4). The provider contract is therefore: classify a reported host first with `FlowHost.observed(reportedName:)` ([ADR 0017](0017-host-name-matching.md) D3). It uses this D1 grammar for IP literals, so the two sides never disagree:

| `FlowHost.observed` | Host | Address |
|---|---|---|
| `.known(host)` | That host | `.known(nil)` until the provider has an address, else the address |
| `.known(nil)`: an IP literal | `.known(nil)` | `FlowAddress.observed(reported:)` of the same text |
| `unknown` | `unknown` | `unknown`, unless the provider has an address as bytes | `PolicyRule.networkApplies(to:)` applies the table; a disabled rule never applies. Combining criteria stays with the engine ([ADR 0015](0015-policy-schema.md) D3, NET-012).

## Alternatives considered

- **Compare address strings by prefix.** No parse. `192.0.2.1` would match `192.0.2.10`, and every spelling variant would escape (N1, N4). Rejected.
- **Parse reported text with `inet_pton`, `inet_aton` or the Network framework.** Less code. `inet_aton` accepts `0x7f.1` and octal; the accepted forms differ between libc and OS versions, so one string could mean two addresses (N4). Rejected; the strict parse is about 60 lines and fully tested.
- **No IPv4-mapped or NAT64 handling.** Simpler semantics. A deny of an IPv4 network would miss the same destination reached over a dual-stack socket or an IPv6-only network (N2, N3). Rejected.
- **Keep a mapped address as IPv6 and also match IPv4 networks through it.** Covers IPv4 denies. An `allow ::/0` then lets every IPv4 destination through a dual-stack socket while a plain IPv4 socket to it is denied (N2). Rejected; the address is IPv4.
- **An IPv4 flow also matches IPv6 rules through its mapped form.** Symmetric. `::/0` would then cover every IPv4 flow, so "deny all IPv6" would block all traffic. Rejected.
- **Translate a NAT64 address to IPv4 for both actions.** Closes the escape. It widens every IPv4 allow to addresses that never reach the allowed host, private ones included (N3). Rejected; the result is `unknown`.
- **Treat a host name given to `FlowAddress.observed(reported:)` as `.known(nil)`.** Forgives a provider that skips classification. A name in a URL with no address yet and a garbled address would then read the same, and the provider bug would hide. Rejected; the provider classifies first (D3).
- **Treat every address under any NAT64 prefix as unknown.** Closes N3 for network-specific prefixes. The prefix is per network and the provider cannot know it in general, so every IPv6 flow on such networks would apply every network deny. Rejected; recorded as a known gap.
- **Decode `destinationNetworks` into typed `IPNetwork` values in place of the strings.** One parse per policy. ADR 0015 rejected it to keep schema paths in violations. The strings stay; the compiled values sit next to them (D1).
- **Parse the network strings on every flow until NET-013.** No extra state. 256 × 64 parses per flow on the decision path (N7). Rejected.

## Consequences

- A destination under a network-specific NAT64 prefix (RFC 6052 §2.2, including `64:ff9b:1::/48` of RFC 8215) is matched as IPv6 only. An IPv4 deny does not see it. Learning the local prefix (RFC 7050) belongs to a provider, not to this pure package.
- A deprecated IPv4-compatible address (`::a.b.c.d`) is plain IPv6; no current stack routes it to IPv4.
- An IPv4 allow never applies to a NAT64 address. On an IPv6-only network, a destination that a policy allows by IPv4 only falls to the other rules and `defaultAction`. The policy adds the `64:ff9b::` form to allow it.
- `IPNetwork.evaluate(_:)` returns `MatchResult`, not `Bool`, because of the NAT64 case.
- An application that connects by name in a URL filter passes a network-only deny until a connection-level provider sees the address. A policy that must block a destination also names its hosts (ADR 0017).
- Per flow, `evaluateNetwork(_:)` does at most 64 masked compares, after one bounded parse of the reported address. A `PolicyMatch` keeps up to 64 compiled networks next to its strings.
- A reported address is never logged; a zone is dropped and never stored.

## Validation

| Check | Kind | Scope | Decision |
|---|---|---|---|
| `NetworkMatchingTests` (`WardAxisPolicy`) | Unit tests | The acceptance case; first, last, one-below and one-above addresses for `/1`, `/8`, `/23`, `/24`, `/31`, `/32`, `/45`, `/127`, `/128`; `/0` per family; family separation; mapped addresses as IPv4 from every source, and `allow ::/0` against a dual-stack socket; NAT64 as `unknown` to IPv4 networks and exact to IPv6 networks, and `allow 10.0.0.0/8` against `64:ff9b::a00:1`; refused mapped networks; other IPv4 embeddings; spellings, brackets and zones, `%25` included; the input bound at 66 and 67 bytes; refused text (short, octal, hex IPv4, signs, double `::`, names); raw bytes; unvalidated patterns as `unknown`; decode and encode of the compiled form; the D3 table for `deny`, `allow`, disabled rules and rules without a network criterion | D1, D2, D3 |
| `NetworkMatchingTests` properties | Seeded property tests (SplitMix64, 4 seeds × 500 cases) | A random address lies in the network of each of its prefixes and leaves it when the last prefix bit flips, IPv4 and IPv6; canonical, expanded, uppercase, bracketed and zoned spellings parse alike; random RFC 4291 spellings (leading zeros, mixed case, any compressed zero run, IPv4 tail) and arbitrary accepted input equal what `inet_pton` reads, an independent oracle in tests only | D1, D2 |
| `HostMatchingTests` (`WardAxisPolicy`) | Unit tests | Every IPv6 spelling that `FlowAddress` accepts is an IP literal to `FlowHost`, and every literal it refuses is `unknown` | D3 |
| `FieldRulesTests` (`WardAxisCore`) | Unit tests | `canonicalNetwork(_:)` bytes and prefix; every refused spelling returns `nil`, mapped networks in hex included | D1 |
| `PolicyFixtureTests` (`WardAxisPolicy`) | Fixture tests | `policy-network-mapped-ipv4-hex` is refused with `malformedNetwork` | D1 |
