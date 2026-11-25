# ADR 0004: NetworkExtension entitlements per target and platform

## Status

Accepted on 2026-11-25 (PRE-004, #4).

## Context

WardAxis uses five NetworkExtension provider types. [TN3134](https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment) (revision 2025-08-19) fixes where each one can run and how it is packaged ([roadmap](../../roadmap/README.md#platform-capability-matrix)). The extension targets come with PRE-005. Their entitlements are fixed now, so PRE-005 only wires the files in.

Trust boundary: the signed entitlements of each bundle. The OS enforces them, and the provisioning profile limits them.

| Threat | Example |
|---|---|
| T1: Over-privilege | The URL filter extension can also start a content filter or a tunnel |
| T2: A non-host bundle installs system extensions | A compromised provider activates or replaces another system extension |
| T3: A macOS bundle runs unsandboxed | A new target misses the App Sandbox, and App Review rejects it, or it ships with full file access |
| T4: A Developer ID value reaches an App Store archive | A `-systemextension` value is copied from a lab or sample file |

## Decision

### D1: Provider types per target

| Target | Packaging | macOS | iOS | tvOS | Entitlements file |
|---|---|---|---|---|---|
| App | App | `app-proxy-provider`, `content-filter-provider`, `dns-proxy`, `url-filter-provider` | `packet-tunnel-provider`, `url-filter-provider` | `packet-tunnel-provider` | `App-macOS`, `App-iOS`, `App-tvOS` |
| Content filter (`.networkfilter`) | System extension | `content-filter-provider` | — | — | `NetworkFilter` |
| DNS proxy (`.dnsproxy`) | System extension | `dns-proxy` | — | — | `DNSProxy` |
| Transparent proxy (`.transparentproxy`) | System extension | `app-proxy-provider` | — | — | `TransparentProxy` |
| URL filter (`.urlfilter`) | App extension | `url-filter-provider` | `url-filter-provider` | — | `URLFilter-macOS`, `URLFilter-iOS` |
| Packet tunnel (`.packettunnel`) | App extension | — | `packet-tunnel-provider` | `packet-tunnel-provider` | `PacketTunnel` |

All files are in `Configurations/Entitlements/`. A provider carries only its own type (T1). The app carries every type of the providers it embeds on that platform: it configures them through the matching `NE*Manager`. The iOS content filter and DNS proxy work only on supervised or managed devices, so the iOS app does not claim them.

### D2: App Store values, never `-systemextension`

Apple documents the `-systemextension` variants "when signed with a Developer ID profile". App Store and development signing use the plain values. No App Store file contains a `-systemextension` value (T4).

### D3: `system-extension.install` on the macOS app only

The issue text says "every macOS target". Only the host app calls `OSSystemExtensionRequest`, so only the app gets the entitlement. An extension with it could activate or replace another system extension (T2).

### D4: App Sandbox on every macOS bundle

Each macOS file sets `com.apple.security.app-sandbox` explicitly. The app also keeps `ENABLE_APP_SANDBOX = YES`. iOS and tvOS files never set the key. The provider files and the app use one file per SDK: a plist cannot expand a build setting into array items, and the sandbox key must not appear in an iOS or tvOS signature. `app.xcconfig` selects the app file with `CODE_SIGN_ENTITLEMENTS[sdk=…]` and sets no unconditional value, so an SDK without a file fails to sign.

### D5: Group membership

Each provider joins the App Group, as [ADR 0002](0002-app-store-signing-identifiers.md) D5 requires. No provider has `keychain-access-groups` yet: none joins the shared group, and none stores a secret. A target that later stores a secret adds its private group first (ADR 0002 D4).

### D6: The lab build is deferred

The lab app signs with the manual profile `WardAxis Lab Developer ID`, which has no Network Extensions or System Extension capability. `app-lab.xcconfig` points to `App-Lab.entitlements`, which keeps the sandbox, App Group and Keychain set only. The lab gets the install entitlement with the ES extension ([LAB.md](../LAB.md)), and NE providers with their `-systemextension` values when the lab embeds them.

## Alternatives considered

- **One app file for all SDKs.** Every platform would claim every provider type, and iOS would carry the sandbox key. Rejected (T1).
- **`system-extension.install` on every macOS target.** It matches the issue text, but it gives every provider the power to install system extensions. Rejected (T2).
- **App Sandbox through `ENABLE_APP_SANDBOX` only.** The setting does not show in the file, and a new target that misses it signs without the sandbox. The explicit key and the archive check make it visible. Rejected as the only control (T3).
- **Wait for PRE-005 to write the files.** Then the entitlement review would mix with target scaffolding. Rejected.

## Verification

| Check | Scope |
|---|---|
| `EntitlementsTests` (macOS) | The test host: `system-extension.install` is `true`; the NE values are exactly the macOS set of D1 |
| `scripts/verify-entitlements.py` | Every bundle in an archive: NE values within D1 for its bundle and platform, no `-systemextension` value, `system-extension.install` on the macOS app only, App Sandbox on every macOS bundle |

## Consequences

- The App IDs need the Network Extensions capability, and the macOS app ID needs System Extension. Xcode automatic signing adds them when it builds. Each provider App ID gets only its own capability when PRE-005 registers it.
- A new provider type or target fails the archive check until this ADR grants it in D1 and `NE_ALLOWED` in the script lists it.
- Packet tunnel builds pass App Review only from an organization account (guideline 5.4, ORG-001).
