# ADR 0002: App Store signing and identifiers

## Status

Accepted on 2026-11-24 (PRE-002, #2).

Amended on 2026-11-25 (PRE-003, #3): the lab build uses the disjoint root `com.agnidia.wardaxis.lab`, and the `lab` segment is reserved. See [D1](#d1-bundle-ids) and [ADR 0003](0003-lab-build-signing.md).

## Context

WardAxis ships one app with up to eight embedded components on macOS, iOS and tvOS ([roadmap](../../roadmap/README.md#repository-layout)). The components share policy data and some secrets. The identifiers fix three trust boundaries:

| Boundary | Enforced by | Threat |
|---|---|---|
| Bundle ID | Code signature, provisioning profile, App Store validation | A foreign bundle claims to be a WardAxis component |
| App Group | Sandbox, container entitlement | A component reads policy data or the outbox that it does not need |
| Keychain access group | Keychain, `keychain-access-groups` entitlement | A component reads a secret (client identity, enrollment token) that it does not need |

Identifiers are hard to change after release: App Store Connect binds a bundle ID to the app record for good, and Keychain items and App Group containers are keyed by their group. So the scheme is fixed now, before PRE-005 adds the extension targets.

## Decision

### D1: Bundle IDs

Every bundle ID is a child of `APP_BUNDLE_ID` (`com.agnidia.wardaxis`). Each one is a build setting in `Configurations/base.xcconfig`; a target never spells out its own ID.

| Component | Build setting | Bundle ID | Kind | Platforms |
|---|---|---|---|---|
| App | `APP_BUNDLE_ID` | `com.agnidia.wardaxis` | App | macOS, iOS, tvOS |
| Agent | `AGENT_BUNDLE_ID` | `….agent` | Login item (`SMAppService`) | macOS |
| Content filter | `NETWORK_FILTER_BUNDLE_ID` | `….networkfilter` | System extension | macOS |
| Transparent proxy | `TRANSPARENT_PROXY_BUNDLE_ID` | `….transparentproxy` | System extension | macOS |
| DNS proxy | `DNS_PROXY_BUNDLE_ID` | `….dnsproxy` | System extension | macOS |
| URL filter | `URL_FILTER_BUNDLE_ID` | `….urlfilter` | App extension | macOS, iOS |
| Packet tunnel | `PACKET_TUNNEL_BUNDLE_ID` | `….packettunnel` | App extension | iOS, tvOS |
| Safari Web Extension | `SAFARI_EXTENSION_BUNDLE_ID` | `….safari` | App extension | macOS, iOS |
| Mail extension | `MAIL_EXTENSION_BUNDLE_ID` | `….mail` | MailKit app extension | macOS |
| Unit tests | — | `….tests` | Test bundle | all |
| UI tests | — | `….uitests` | Test bundle | all |

Rationale: the OS ties an embedded bundle to its host by the bundle-ID prefix, and App Store validation rejects an extension outside the host's namespace. One flat level keeps the IDs short and lets `scripts/verify-entitlements.py` reject any bundle outside the root.

The lab build (PRE-003) uses Developer ID signing, its own scheme and its own root `com.agnidia.wardaxis.lab`. It never uses an App Store profile, and no App Store target carries a lab entitlement. No App Store bundle ID contains the `lab` segment; `scripts/verify-entitlements.py` rejects one that does. See [ADR 0003](0003-lab-build-signing.md).

### D2: One App ID for all platforms (Universal Purchase)

The app uses the same bundle ID on macOS, iOS and tvOS. One App Store Connect record carries all three platforms, which gives Universal Purchase. A per-platform ID would need three records and would split purchases.

### D3: App Group

| SDK | Identifier | Authorized by |
|---|---|---|
| macOS | `$(DEVELOPMENT_TEAM).com.agnidia.wardaxis` | The team ID in the code signature |
| iOS, tvOS | `group.com.agnidia.wardaxis` | The App Group registered on the App ID, carried in the provisioning profile |

`APP_GROUP_ID` in `base.xcconfig` selects the form per SDK.

Alternatives considered:

- **`group.` form on macOS too.** macOS 15 and later accept it only through the provisioning profile; without one, the OS asks the user for consent to access the container. `NEMachServiceName` of a NetworkExtension system extension must start with an App Group, and the team-prefixed form needs no profile lookup. Rejected.
- **Team-prefixed form on iOS and tvOS.** The platforms reject it. Not possible.

### D4: Keychain access groups

Each bundle lists its own private group first, then the shared group:

```text
$(AppIdentifierPrefix)<bundle ID>                  # private, default for writes
$(AppIdentifierPrefix)com.agnidia.wardaxis.shared  # KEYCHAIN_SHARED_GROUP
```

- The Keychain writes an item with no explicit `kSecAttrAccessGroup` to the first group. With the private group first, a write reaches the shared group only when the code names it in `KeychainItemLocation.accessGroup`. A forgotten parameter fails closed: the secret stays private.
- The shared group is separate from the App Group. A component can then read the shared container (policy snapshots) without reading shared secrets.

Alternatives considered:

- **App Group as the Keychain group.** Apple allows it, but it joins container access and secret access in one entitlement. Rejected: it breaks least privilege for the extensions that need policy data only.
- **Shared group first.** Every unscoped write would become readable by every member. Rejected.

### D5: Membership per component

A component joins a group only when its function needs it. PRE-005 adds the entitlements when it creates each target; this table is the default it applies.

| Component | App Group | Shared Keychain group | Why |
|---|---|---|---|
| App | Yes | Yes | Writes policy snapshots; owns enrollment secrets |
| Agent | Yes | Yes | Reads the outbox; authenticates to the server |
| Content filter, transparent proxy, DNS proxy | Yes | No | Read immutable policy snapshots only |
| URL filter | Yes | No | Reads policy snapshots only |
| Packet tunnel | Yes | No | Reads policy snapshots; add the shared group only if the tunnel authenticates to the server |
| Safari Web Extension | Yes | No | Reads registered AI and policy domains |
| Mail extension | Yes | No | Reads DLP rules |

A change to this table needs an amendment to this ADR.

### D6: Signing

| Item | Value | Source |
|---|---|---|
| Style | Automatic | `CODE_SIGN_STYLE` in `Configurations/sign.xcconfig` |
| Build identity | Apple Development | `CODE_SIGN_IDENTITY` |
| Export | `app-store-connect`, automatic, no `teamID` | `Configurations/export/app-store.plist` |
| Distribution identity | Apple Distribution (applied at export) | Xcode |
| Team | Individual team until ORG-001 (#192) | `DEVELOPMENT_TEAM` |

The export options file names no team, so `DEVELOPMENT_TEAM` stays the one source. The `app-store-connect` method accepts only Apple Distribution with App Store profiles, so an App Store export cannot pick up a Developer ID identity.

### D7: Verification

| Check | Scope | Evidence |
|---|---|---|
| `EntitlementsTests` (unit test, macOS) | The running test host: App Sandbox on, exact App Group, Keychain group order, `system-extension.install`, exact NetworkExtension provider set ([ADR 0004](0004-network-extension-entitlements.md)), no lab or runtime-weakening entitlement | `Tests/UnitTests/Core/EntitlementsTests.swift` |
| `scripts/verify-entitlements.py` | An archive or exported app and every nested bundle: bundle-ID namespace, group membership, Keychain group order, App Sandbox on macOS, NetworkExtension provider types per bundle and platform, `system-extension.install` on the macOS app only, no `-systemextension` value, no `get-task-allow`, no temporary exception, no Developer ID authority | Run on each archive before upload |

The unit test cannot check temporary exceptions or `get-task-allow`: Xcode adds them to every test host. The script checks them on the archive.

## Consequences

- The identifiers were registered under the individual team on 2026-11-24, so Phase 0 can sign and upload for iOS and tvOS. ORG-001 (#192) cannot register the same IDs under the organization team: bundle IDs are unique across teams. The app moves to the organization by App Transfer. Check Apple's App Transfer criteria, and their effect on the App Group and Keychain groups, before ORG-001 starts.
- Moving the team changes `$(AppIdentifierPrefix)` and the macOS App Group. Keychain items and the macOS container of the old team are not readable after the move. Enrollment secrets must be re-provisioned, not migrated.
- A new target must take its bundle ID from D1 and its group membership from D5. `scripts/verify-entitlements.py` fails an archive that does not.
