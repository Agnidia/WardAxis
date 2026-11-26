# Phase 1 — Network Security

[Roadmap](README.md) | [Previous](00-preparation.md) | [Next](02-tls-pki.md)

**Weeks:** 1–2 · **Estimate:** 45–60 hours · **Release:** v0.1.0

**Platforms:** macOS (content filter, DNS proxy, URL filter) · iOS/iPadOS (URL filter, optional packet tunnel) · tvOS (packet tunnel)

**Distribution:** All tasks are **Shipped**.

**Goal:** Application-level firewall with flow attribution, deterministic policy enforcement, diagnostics and lifecycle management. The macOS content filter system extension is the core. The URL filter covers iOS and macOS without supervision. A packet tunnel provides DNS filtering on tvOS. DNS proxy and transparent proxy are separate capabilities. This phase addresses the networking experience gap for Apple-platform security roles.

## 1.1. Network Extension infrastructure

| ID | Task | Platform | Implementation |
|---|---|---|---|
| NET-001 | System Extension lifecycle | macOS | OSSystemExtensionManager: activation, replacement, deactivation |
| NET-002 | Filter configuration | macOS | NEFilterManager, persistence |
| NET-003 | Filter provider | macOS | NEFilterDataProvider, handleNewFlow |
| NET-004 | Provider lifecycle | All | Start, stop, configuration updates |
| NET-005 | Permissions | All | Approval status, errors, recovery |
| NET-006 | Diagnostics | All | Extension state, configuration, error reporting |
| NET-024 | URL filter | macOS, iOS | NEURLFilter app extension, policy-to-filter compilation |
| NET-025 | Packet tunnel DNS filter | tvOS, iOS (optional) | NEPacketTunnelProvider; DNS-only routes; policy evaluation per query |
| NET-026 | Consent and activation flow | All | Consent screen before any filter or tunnel activation |

Content filter data providers have restrictions on exporting network content. Use supported control and reporting channels; keep evaluation within the provider and avoid assuming arbitrary IPC or network access is available. Start in audit mode and validate removal before enforcement.

On iOS, the content filter and DNS proxy work only on supervised or per-app managed devices. Phase 5 verifies them through MDM; the shipped iOS default is the URL filter. The tvOS packet tunnel has no per-app mode. Packet tunnel apps fall under guideline 5.4: declare collected data before use, and never sell or share it.

## 1.2. Flow and application identity

| Field | Type | Purpose |
|---|---|---|
| id | UUID | Event identity |
| timestamp | Date | Event time |
| processID | Int32? | Process attribution |
| bundleIdentifier | String? | Application identity |
| teamIdentifier | String? | Developer identity |
| signingIdentifier | String? | Code-signing identity |
| executablePath | String? | Executable location |
| localEndpoint | Endpoint? | Source address |
| remoteEndpoint | Endpoint? | Destination address |
| hostname | String? | Observed hostname |
| transportProtocol | TransportProtocol | TCP / UDP |
| direction | FlowDirection | Inbound / outbound |
| decision | PolicyDecision | Allow / deny |
| matchedRuleID | UUID? | Policy attribution |
| policyVersion | UInt64 | Applied version |
| platform | Platform | macOS / iOS / tvOS |

Use audit-token-derived identity and code-signing information where available. PID alone is insufficient because of reuse. Hostname or process metadata may be unavailable; represent unknown explicitly. On iOS and tvOS, process, signing and executable fields are always `unknown`; the URL filter and packet tunnel report only the URL or DNS query. Document the available fields per provider. Use consistent policy IDs in schema and fixtures (UUIDs or a declared string identifier type).

## 1.3. Policy engine (`WardAxisPolicy`)

| ID | Task |
|---|---|
| NET-007 | Versioned SecurityPolicy and SecurityRule models |
| NET-008 | Application identity matching |
| NET-009 | Domain and subdomain matching |
| NET-010 | IPv4/IPv6 CIDR matching |
| NET-011 | Transport protocol and port matching |
| NET-012 | Priority-based rule resolution |
| NET-013 | Immutable policy snapshots |
| NET-014 | Audit-only mode |
| NET-015 | Decision explanations |

The policy engine is a pure package that builds for all three platforms. Rule precedence: explicit priority, specificity, stable rule ID, default decision. Use label-aware domain matching; `fakeexample.test` must never match `example.test` solely by string suffix. Rules that need fields a platform cannot supply evaluate to the documented unknown-identity fallback. Test missing metadata, conflicting rules, IPv6, CIDR boundaries, normalization and policy updates. Compile snapshots before publication and validate schema before replacement.

```json
{
  "version": 1,
  "mode": "enforce",
  "defaultDecision": "allow",
  "rules": [
    {
      "id": "f0292da2-3331-4ed9-8d38-a4210b7472ee",
      "priority": 100,
      "enabled": true,
      "match": {
        "bundleIdentifier": "com.example.testclient",
        "domains": ["blocked.example.test"]
      },
      "decision": "deny"
    }
  ]
}
```

## 1.4. Optional DNS security

| ID | Task |
|---|---|
| NET-016 | NEDNSProxyProvider lifecycle (macOS) |
| NET-017 | DNS query and response parsing |
| NET-018 | Domain-based policy evaluation |
| NET-019 | TTL-aware DNS cache |
| NET-020 | IPv4/IPv6 resolution |
| NET-021 | Upstream resolver configuration |
| NET-022 | Timeout and retry handling |
| NET-023 | DoH / DoT compatibility analysis |

The DNS proxy ships on macOS only. On iOS it requires supervision (Phase 5). The DNS parser and cache are shared with the tvOS packet tunnel (NET-025). Encrypted DNS and application-specific resolution can limit visibility. Avoid equating an IP address with a unique domain or process.

## 1.5. Safari content blocking

| ID | Task | Platform |
|---|---|---|
| NET-027 | Compile policy domain rules into Safari `declarativeNetRequest` rules | macOS, iOS |
| NET-028 | Update rules from the app through native messaging or the App Group | macOS, iOS |
| NET-029 | Rule-count limits and overflow reporting | macOS, iOS |

Request only the host permissions the rules need (guideline 4.4.2). Safari blocking covers Safari only; other browsers rely on the network providers.

## 1.6. UI

| Screen | Platform | Function |
|---|---|---|
| Network activity | macOS, iOS | Flow metadata, application identity, endpoints, verdicts |
| Firewall rules | macOS, iOS | Create, enable, disable and reorder rules |
| DNS activity | All | Observed queries, TTL, results, blocked domains |
| Diagnostics | All | Provider state, approval, errors, recovery |
| Protection status | tvOS | Tunnel state, policy version, blocked counts; focus-based navigation |

## 1.7. Integration test matrix

| Scenario | macOS | iOS | tvOS | Expected result |
|---|:---:|:---:|:---:|---|
| Allowed application connects | ✓ | ✓ | ✓ | Succeeds |
| Blocked test application or domain connects | ✓ | ✓ | ✓ | Denied |
| URL filter blocks a policy domain | ✓ | ✓ | — | Denied without supervision |
| Policy changes during traffic | ✓ | ✓ | ✓ | New flows use updated version |
| IPv6 destination | ✓ | ✓ | ✓ | Correct matching |
| Unknown identity | ✓ | ✓ | ✓ | Documented fallback |
| Sleep/wake | ✓ | ✓ | ✓ | Provider recovers |
| Wi-Fi/Ethernet transition | ✓ | ✓ | ✓ | No persistent connectivity loss |
| VPN active | ✓ | ✓ | — | Behavior measured and documented |
| Extension restart | ✓ | ✓ | ✓ | Last-known-good policy restored |
| Device reboot | ✓ | ✓ | ✓ | Tunnel or filter restarts with last-known-good policy |
| Invalid policy | ✓ | ✓ | ✓ | Previous valid policy retained |
| Safari blocks a policy domain | ✓ | ✓ | — | Blocked in Safari |

## Acceptance criteria

- [ ] Application-level TCP/UDP filtering works on the test Mac.
- [ ] The URL filter blocks policy domains on an unsupervised iPhone.
- [ ] The tvOS packet tunnel filters DNS queries by policy.
- [ ] Policy evaluation is deterministic on all platforms; audit-only decisions are observable.
- [ ] New flows adopt policy updates; existing-flow semantics documented.
- [ ] Every provider can be disabled and removed.
- [ ] The consent screen precedes any filter or tunnel activation (guidelines 5.1.1, 2.5.14).
- [ ] The TestFlight build passes App Store Connect validation with sandboxed targets only.
- [ ] VPN coexistence and DNS visibility limitations documented.
- [ ] Local policy evaluation p99 below 1 ms in a defined benchmark (target; report actual).

**Deliverables:** Firewall demo on macOS, URL filter demo on iOS, tvOS DNS filter, Safari content blocking, policy engine tests, architecture document, VPN compatibility report, v0.1.0 TestFlight release.

**Skills:** NetworkExtension, URL filtering, packet tunnels, application attribution, network flow lifecycle, DNS security, policy enforcement.

## References

- [NetworkExtension](https://developer.apple.com/documentation/networkextension)
- [NEFilterDataProvider](https://developer.apple.com/documentation/networkextension/nefilterdataprovider)
- [URL filters](https://developer.apple.com/documentation/networkextension/url-filters)
- [NEPacketTunnelProvider](https://developer.apple.com/documentation/networkextension/nepackettunnelprovider)
- [TN3134](https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment)
- [Safari web extensions](https://developer.apple.com/documentation/safariservices/safari-web-extensions)
- [LuLu](https://github.com/objective-see/LuLu)
