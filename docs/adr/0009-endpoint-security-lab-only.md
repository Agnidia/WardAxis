# ADR 0009: EndpointSecurity as a lab-only track

## Status

Accepted on 2026-11-26 (PRE-008, #8). Roadmap ID: ADR-005.

Open item: roadmap Phase 3 asks to confirm the App Store position with Apple DTS. No DTS reply is recorded yet. When it arrives, record it here as an amendment. A reply that allows EndpointSecurity in an App Store build does not change D1 without a new ADR.

## Context

The EDR engine of Phase 3 needs EndpointSecurity (ES). An ES client needs:

| Requirement | Source |
|---|---|
| The restricted entitlement `com.apple.developer.endpoint-security.client` | Apple approval per team ([LAB.md](../LAB.md#entitlement-requests)) |
| Developer ID signing with a manual profile for the restricted entitlement | [ADR 0003](0003-lab-build-signing.md) D3 |
| Full Disk Access, granted by hand | TCC |
| The client runs as root (a system extension or a daemon) | [EndpointSecurity](https://developer.apple.com/documentation/endpointsecurity) |

App Review constraints:

| Constraint | Source |
|---|---|
| Every Mac app is sandboxed | Guideline 2.4.5(i) |
| No root escalation | Guideline 2.4.5(v) |

Root alone is not the blocker: the shipped build already runs three NE providers as root system extensions ([ADR 0008](0008-extensions-under-app-store.md) D2). The blocker is the entitlement. Apple grants it for Developer ID signing, not for App Store distribution, and a sandboxed App Store process cannot be an ES client. So the shipped build cannot contain an ES client. [ADR 0003](0003-lab-build-signing.md) already isolates the lab build (scheme, bundle-ID root, signing). This ADR records why the track exists and what it may claim.

Trust boundary: shipped build versus lab build (TB8 in [THREAT-MODEL.md](../THREAT-MODEL.md#trust-boundaries)), and the ES client versus the rest of the lab system.

| Threat | Example |
|---|---|
| T1: ES code or the ES entitlement reaches an App Store build | A lab file joins a shipped target, or `WARDAXIS_LAB` reaches `Release` |
| T2: A shipped feature depends on ES | A Phase 3 detection works only with ES, and the App Store build silently lacks it |
| T3: Lab results are claimed for the product | A demo or a benchmark of the lab build is presented as shipped capability |
| T4: The test Mac is weakened to make ES work | A tester disables SIP or grants Full Disk Access to the wrong binary |
| T5: The ES client becomes a data leak | Events with file contents or user data leave the Mac |

## Decision

### D1: ES never ships (T1)

No App Store configuration, target or entitlements file contains ES code or the ES entitlement. ES code compiles only under `WARDAXIS_LAB`, in the `Lab` configuration of the `WardAxisLab` scheme (ADR 0003 D1). The entitlement goes only on a lab-only ES system extension target, after Apple approval (ADR 0003 D4).

### D2: Shipped features never depend on ES (T2)

Every shipped feature has a design that works with the App Store components only ([ADR 0008](0008-extensions-under-app-store.md)). The lab adds visibility; it removes no requirement from the shipped design. A Phase 3 task labeled **Lab-only** has no shipped counterpart unless the phase file names one.

### D3: Lab results are labeled lab (T3)

Every demonstration, benchmark and document labels results as simulated, lab or App Store build (roadmap README, Architecture). Without approval of the entitlement, the synthetic event adapter is the fallback, and nothing claims kernel integration.

### D4: The lab Mac keeps its protections (T4)

No machine disables SIP or other system protections for WardAxis. ES runs only on the test Macs and VMs of [TEST-DEVICES.md](../TEST-DEVICES.md). Full Disk Access goes to the ES system extension only, never to `WardAxis Lab.app`: the app needs no extra privilege (ADR 0003 D4).

### D5: Events stay local and are normalized (T5)

The ES client sends only normalized, bounded event batches to the agent over authenticated XPC. Events carry no file contents. ES events never leave the Mac. The management contract has no upstream event channel: the configuration feed runs from server to device only. An upstream channel needs its own ADR first, which fixes consent, the fields and the size limits. The ES client answers each AUTH event once, before its deadline, with no network or disk I/O on the decision path; audit mode is the default.

## Alternatives considered

- **Ship ES behind a setting in the App Store build.** One product. App Review rejects it (2.4.5(i), (v)), and one wrong setting would ship root code. Rejected (T1).
- **A separate Developer ID product with ES.** A real EDR product. It doubles the release, update and support surface, and it is outside the App Store goal ([ADR 0010](0010-app-store-only-distribution.md)). Rejected for now.
- **Drop the EDR track.** Simplest. It loses the research value of Phase 3 and the evidence for EDR roles (roadmap Career mapping). Rejected.
- **Use the unsupported `systemextensionsctl developer` mode or disable SIP to test.** Faster setup. It changes the security of the test machine and hides real approval behavior. Rejected (T4).

## Consequences

- The lab needs the Apple approval of the ES entitlement. Its status is in [LAB.md](../LAB.md#entitlement-requests) (submitted 2026-11-25).
- The lab build embeds no agent today (`EXCLUDED_SOURCE_FILE_NAMES` in `app-lab.xcconfig`, [ADR 0005](0005-extension-shells.md) D6). The agent joins the lab build, as the receiver of D5, only through an amendment to ADR 0005 D6 and [ADR 0004](0004-network-extension-entitlements.md) D6.
- A lab archive fails `scripts/verify-entitlements.py` by design (ADR 0003).
- After ORG-001 (#192), the lab signing setup and the entitlement request are repeated under the organization team.

## Validation

| Check | Kind | Scope | Decision |
|---|---|---|---|
| `LabExclusionTests` | Unit test | The App Store test host defines no `WARDAXIS_LAB` and has no `lab` bundle-ID segment | D1 |
| `scripts/verify-entitlements.py` | Archive script | Rejects the ES entitlement, a Developer ID authority and any `lab` bundle-ID segment | D1 |
| App Store Connect | Upload | No app record exists for `com.agnidia.wardaxis.lab` | D1 |
| Phase file review | Manual, per Phase 3 task | Every ES task is labeled **Lab-only**; no shipped task cites an ES source | D2 |
| Result labels | Manual, per demo and benchmark | Every result names its build: simulated, lab or App Store | D3 |
| [LAB.md](../LAB.md#entitlement-requests) status table | Manual | Entitlement request status and date | D1 |
| Test device record | Manual, per lab session | [TEST-DEVICES.md](../TEST-DEVICES.md): SIP on (`csrutil status`), `systemextensionsctl developer` off, Full Disk Access granted to the ES extension only | D4 |
| Contract review | Manual, per change to `WardAxisManagementAPI` | The OpenAPI contract has no device-to-server event operation; a new upstream operation cites an ADR. `ContractRouteTests` lists every server route | D5 |
| ES client tests | Planned, Phase 3 lab | Each AUTH event gets one answer before its deadline; the decision path makes no network or disk call; event batches have a size bound and carry no file contents | D5 |
