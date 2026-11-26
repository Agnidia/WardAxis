# ADR 0008: System and app extensions under App Store distribution

## Status

Accepted on 2026-11-26 (PRE-008, #8). Roadmap ID: ADR-001.

## Context

WardAxis enforces policy through NetworkExtension providers, a Safari Web Extension, a MailKit extension and a macOS login item ([roadmap](../../roadmap/README.md#architecture)). Every one of them ships to the App Store. App Review and the OS fix how a security product can package and start such components.

| Constraint | Source |
|---|---|
| Every Mac app and its components are sandboxed | Guideline 2.4.5(i) |
| One self-contained bundle built by Xcode; no installer package, no third-party installer | Guideline 2.4.5(ii) |
| No launch at login or background process without consent | Guideline 2.4.5(iii) |
| No root escalation, no setuid | Guideline 2.4.5(v) |
| An extension includes real functionality | Guidelines 4.4, 4.4.2 |
| Provider type decides packaging: system extension or app extension, per platform | [TN3134](https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment) |

Earlier ADRs fixed the details: identifiers and groups ([ADR 0002](0002-app-store-signing-identifiers.md)), NetworkExtension entitlements ([ADR 0004](0004-network-extension-entitlements.md)), packaging and fail-closed shells ([ADR 0005](0005-extension-shells.md)), DEBUG activation ([ADR 0006](0006-debug-system-extension-activation.md)). This ADR records the decision that they implement.

Trust boundary: the host app bundle and the user or MDM approval of each component (TB1, TB2 in [THREAT-MODEL.md](../THREAT-MODEL.md#trust-boundaries)).

| Threat | Example |
|---|---|
| T1: A privileged component outside the sandbox | A launchd daemon or setuid helper runs as root with no sandbox, and one bug in it owns the Mac |
| T2: A component installed outside the reviewed bundle | A PKG or a downloaded installer drops a binary that App Review never saw |
| T3: A component starts without consent | The agent or a filter starts at login before the user opts in |
| T4: A component that the app does not need gets installed | A provider or bundle that no ADR covers ships with the team signature |
| T5: An approved component works with no policy | The user approves a filter, and it passes or drops traffic on no basis |

## Decision

### D1: One sandboxed app embeds every component (T1, T2, T4)

The shipped product is one app bundle. Every component is embedded in it and is sandboxed on macOS. There is no daemon, no privileged helper, no installer package and no setuid binary. The exact set of embedded bundles is the reviewed set of ADR 0005 D1; a new bundle needs an amendment to ADR 0005 first.

### D2: System extensions only for the macOS NetworkExtension providers (T1, T4)

| Component | Packaging | Platforms |
|---|---|---|
| Content filter, DNS proxy, transparent proxy | System extension | macOS |
| URL filter | ExtensionKit app extension | macOS, iOS |
| Packet tunnel | App extension | iOS, tvOS |
| Safari Web Extension, Mail extension | App extension | macOS (Mail), macOS and iOS (Safari) |
| Agent | Sandboxed login item (`SMAppService`) | macOS |

A system extension runs as root outside the app sandbox, but the OS loads it only from the signed app, only after user or MDM approval, and only with its own sandbox profile and entitlements (ADR 0004). TN3134 allows no other packaging for these three providers on macOS. Every other component is an app extension, which the OS runs sandboxed as the user.

### D3: The host app is the only installer (T2, T4)

Only the macOS app has `com.apple.developer.system-extension.install` (ADR 0004 D3). It requests only extensions inside its own bundle, with identifiers that are direct children of the app ID (ADR 0006 D2). Updates come through the App Store only ([ADR 0010](0010-app-store-only-distribution.md) D3).

### D4: Every component starts only by explicit consent (T3)

| Component | Start condition |
|---|---|
| System extension | The user approves it in System Settings, or an MDM profile pre-approves it |
| NE configuration | The user allows the configuration, or an MDM profile installs it |
| Safari and Mail extensions | The user enables them in Safari or Mail |
| Agent | The user opts in; only then does the app register it with `SMAppService` |

No component registers itself at install time.

### D5: A component without policy fails closed (T5)

Until its phase adds real logic, each component refuses to work (ADR 0005 D2). When real logic arrives, the fail-open or fail-closed semantics of each provider are decided per component (roadmap ADR-012), never by default.

## Alternatives considered

- **A privileged helper or launchd daemon for enforcement.** Simpler IPC and full system visibility. App Review rejects it (2.4.5(i), (v)), and it is root code with no sandbox. Rejected (T1).
- **A PKG installer that places extensions and an agent.** The usual enterprise pattern. App Review rejects it (2.4.5(ii)), and it installs code outside the reviewed bundle. Rejected (T2).
- **Developer ID distribution for the shipped build.** Allows the `-systemextension` NE values and EndpointSecurity. It gives up App Review, the App Store update path and Apple Business Manager distribution. Rejected; see [ADR 0010](0010-app-store-only-distribution.md). EndpointSecurity stays in the lab build ([ADR 0009](0009-endpoint-security-lab-only.md)).
- **App extensions only on macOS.** Avoids root code entirely. TN3134 offers the content filter, DNS proxy and transparent proxy on macOS only as system extensions, so the macOS network features would be lost. Rejected.

## Consequences

- Each provider has a narrow sandbox and talks to other components only through the App Group container, NE provider messaging or XPC services whose names start with the App Group (ADR 0005 D4).
- Root-level visibility that a daemon would give (process tree, file events) is not available in the shipped build. That gap is the lab track ([ADR 0009](0009-endpoint-security-lab-only.md)).
- Packet tunnel builds pass App Review only from an organization account (guideline 5.4, ORG-001, #192).
- Removal is the App Store removal path: deleting the app removes its extensions. Roadmap ADR-014 and PRE-010 document the detail.

## Validation

| Check | Kind | Scope | Decision |
|---|---|---|---|
| `EmbeddedBundlesTests` | Unit test | The running host embeds exactly the reviewed set for its platform; Mach service names start with the App Group | D1, D2 |
| `EntitlementsTests` (macOS, signed) | Unit test | The host has `system-extension.install` and exactly the macOS NE set | D2, D3 |
| `scripts/verify-entitlements.py` | Archive script | `EXPECTED_NESTED` bundle set, App Sandbox on every macOS bundle, `<bundle ID>.systemextension` names, `system-extension.install` on the app only | D1, D2, D3 |
| App Store Connect validation | TestFlight upload per platform | App Review packaging rules, ITMS 90939 system extension naming | D1, D2 |
| `SystemExtensionIdentifierTests` | Unit test | A request names only a direct child of the app ID | D3 |
| Consent review | Code review, per change | No code calls `SMAppService.register()`, `OSSystemExtensionRequest` or an `NE*Manager` save outside a user action or an MDM path. Today: `rg -n "SMAppService|OSSystemExtensionRequest|saveToPreferences" Source Extensions Services` finds only `SystemExtensionService`, whose only caller is the DEBUG control of ADR 0006 D1, and a comment in the agent | D4 |
| Agent shell | Code review | The agent exits at launch until its phase (ADR 0005 D2) | D4 |
| Shell refusal review | Manual, per phase | Each shell that gains logic gets its own threat review before it stops refusing | D5 |
