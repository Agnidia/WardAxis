# ADR 0015: Policy schema and the WardAxisPolicy package

## Status

Accepted on 2026-11-27 (NET-007, #13).

## Context

PRE-009 ([ADR 0011](0011-versioned-schemas.md)) put a first `SecurityPolicy` in `WardAxisCore`. Its rules run in array order, the first match wins, and a rule names only an application and destination hosts. The policy engine (NET-008 to NET-015) needs explicit priority, an enabled flag, an audit mode, networks, transport and ports. It must also live in its own pure package.

| Constraint | Source |
|---|---|
| Policy models in `WardAxisPolicy`, a pure package for all three platforms | [roadmap 1.3](../../roadmap/01-network-security.md#13-policy-engine-wardaxispolicy), #13 |
| Precedence: explicit priority, specificity, stable rule ID, default decision | [roadmap 1.3](../../roadmap/01-network-security.md#13-policy-engine-wardaxispolicy) |
| Policy depends on core; core depends on nothing | [roadmap/README.md](../../roadmap/README.md#shared-package-requirements) |
| One envelope, strict decode, typed refusals with schema paths only | [ADR 0011](0011-versioned-schemas.md) D1, D2, D5 |
| Policies are data, with no expression language | [ADR 0010](0010-app-store-only-distribution.md) D3 |

Trust boundary: TB4 (device and management server) today. TB2 and TB10 use the same model when the enforcement components have logic.

| Threat | Example |
|---|---|
| T1: A reader guesses whether a policy enforces | A policy without `mode` is enforced by one component and only reported by another |
| T2: Two components resolve the same rules differently | One component reads array order, another reads priority, and a deny loses to an allow |
| T3: One network has several spellings | `192.0.2.1/24`, `192.000.2.0/24` and `192.0.2.0/24` name the same network, so a duplicate or exception check misses one |
| T4: A rule matches every flow | An empty `match`, or an empty host list read as "any", overrides `defaultAction` |
| T5: A disabled rule hides an unchecked payload | A rule with `enabled: false` is not validated, and a later toggle enables a malformed rule |
| T6: The package split opens a bypass of the codec | Moving the bodies out of `WardAxisCore` makes it possible to decode a policy with a plain `JSONDecoder` |

## Decision

### D1: `WardAxisPolicy` owns the policy models (T6)

`Packages/WardAxisPolicy` holds `SecurityPolicy`, `PolicyMode`, `PolicyRule`, `PolicyMatch`, `PortRange`, `PolicyLimits` and `PolicySourceProtocol`. `FixturePolicySource` is in the `WardAxisPolicyTestSupport` product, for tests and previews only.

`WardAxisCore` keeps the parts that other schemas share: the envelope, `SchemaCodec`, `SchemaError`, `SchemaPath`, `FieldRules`, `ApplicationMatcher`, `TransportProtocol`, `PolicyAction` and `PolicyReference`. Events report a `PolicyAction` and a `PolicyReference`, so they stay in core.

`SchemaCodec.requireCodec(_:)` is now `public`, so a body in another package can call it. The marker that it checks stays `private` to `WardAxisCore`. No other module can name the marker, so no other decoder can carry it, and the ADR 0011 D2 guarantee holds.

### D2: The fields of a policy (T1, T4, T5)

| Field | Rule |
|---|---|
| `mode` | `enforce` or `audit`. Required; there is no default mode |
| `defaultAction` | Required (ADR 0011 D3) |
| `revision` | ≥ 1 (ADR 0011 D3) |
| `rules` | At most 256, unique `identifier`. Array order carries no meaning |
| `priority` | Required integer in `0...10_000` |
| `enabled` | Required. A disabled rule never matches, but it is validated like every other rule |
| `match` | Required. Names at least one criterion. An absent criterion matches anything; within a list, one element must match |
| `match.application` | `ApplicationMatcher` (ADR 0011 D3), with an optional `bundleIdentifier` ([ADR 0016](0016-application-identity-matching.md) D1) |
| `match.destinationHosts` | Host names or `*.` patterns (ADR 0011 D3), 1 to 64, no duplicates |
| `match.destinationNetworks` | Canonical CIDR (D4), 1 to 64, no duplicates |
| `match.transport` | `tcp` or `udp` |
| `match.destinationPorts` | Inclusive `{first, last}` ranges in `1...65535` with `first <= last`, 1 to 32, no duplicates |

A list that is present must not be empty. Leaving a criterion out is the only way to say "any", so an empty list never widens a rule. A `match` with only `transport` or only ports is allowed: "deny all UDP" is a valid rule.

### D3: Resolution order (T2)

A higher `priority` wins. Equal priorities fall to the more specific rule, then to the lower `identifier` in byte order. When no enabled rule matches, `defaultAction` decides. The rule identifier is the last tie-breaker, so it is unique (D2). NET-012 implements this order and defines specificity. The schema fixes the direction now, so no writer can depend on array order.

### D4: One spelling per network (T3)

A network is `<address>/<prefix>`. The address is a canonical IPv4 or IPv6 literal (ADR 0011 D3). The prefix is a decimal number with no leading zero, `0–32` or `0–128`. Every bit after the prefix is zero. A zone (`%en0`) or an embedded IPv4 tail (`::ffff:192.0.2.0`) is refused. The refusal reason is `malformedNetwork`.

Networks stay strings in the model, and `validate()` checks them. A refusal therefore reports a schema path (ADR 0011 D5). NET-010 parses them into a typed form for matching.

### D5: Version 1 is redefined before release

No build has shipped, so this change redefines the body of `schemaVersion` 1 in place. There is no v2 and no compatibility path (AGENTS.md: no backward compatibility). The ADR 0011 rule "a new field needs a new schema version" applies from the first App Store release.

## Alternatives considered

- **Keep the models in `WardAxisCore` and add `WardAxisPolicy` with the engine.** A smaller change. The issue and the roadmap name the package, and the engine would split one domain over two packages. Rejected.
- **Ordered rules, first match wins.** Simple, and the earlier model did it. Ordering survives no merge of two policies, and the roadmap requires explicit priority (T2). Rejected.
- **Typed `IPNetwork` decoded from a string.** Matching code gets a parsed value. A parse failure would then surface as `wrongShape` and lose the violation reason. The parse also belongs to NET-010. Rejected for now; NET-010 parses validated strings.
- **Bump the policy to schema version 2.** The rule of ADR 0011 for a shipped schema. Nothing has shipped, so a v1 reader to keep compatible does not exist. Rejected (D5).
- **Optional `enabled` and `priority` with defaults.** Shorter documents. A default is a value that the issuer did not write, so two writers can disagree about it (T1). Rejected.

## Consequences

- `WardAxisManagement` does not depend on `WardAxisPolicy`. Its test target does, to read a policy from a feed snapshot.
- `FieldRules`, `SchemaPath`, `ApplicationMatcher.validate(at:)` and `SchemaCodec.requireCodec(_:)` are public API of `WardAxisCore`. Each is a pure check or a path builder and holds no state.
- `0.0.0.0/0` and `::/0` pass validation. They are valid "all IPv4" and "all IPv6" criteria; review of the policy content catches a misuse, not the schema.
- A public-suffix wildcard (`*.co.uk`) still passes (ADR 0011 known gap).
- Audit mode is data only here. NET-014 defines what an audit decision reports.
- No app target links `WardAxisPolicy` yet. The Xcode project gets a package reference when a target first imports it.

## Validation

| Check | Kind | Scope | Decision |
|---|---|---|---|
| `PolicyFixtureTests` (`WardAxisPolicy`) | Unit tests, fixtures in `Packages/WardAxisPolicy/Tests/WardAxisPolicyTests/Fixtures/` | A valid policy decodes with version, mode, priority and every criterion; round trip. Refusals: unknown version, wrong kind, missing mode, priority or enabled, unknown mode, action or transport, empty match, unknown and `null` fields, repeated and escaped keys, plain `JSONDecoder`, every network and port rule with its path | D1, D2, D4 |
| `PolicyBoundsTests` (`WardAxisPolicy`) | Unit tests | Rule, host, network and port limits; empty lists; inclusive priority bounds; disabled rules validated; encoder refusal; a policy at every per-rule limit fits in one document | D2 |
| `FieldRulesTests` (`WardAxisCore`) | Unit tests | Canonical networks accepted; host bits, leading zeros, prefix range, uppercase or long IPv6, zone, mapped IPv4 refused | D4 |
| `ConfigurationSchemaTests` (`WardAxisManagement`) | Unit tests | A policy from a feed snapshot decodes; a wrong shape or unknown version is refused | D1 |
| Code review of NET-012 | Review | The resolver implements D3 | D3 |
