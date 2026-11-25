# ADR 0005: Extension shells, packaging and the Lab build

## Status

Accepted on 2026-11-25 (PRE-005, #5).

## Context

PRE-005 adds the eight embedded components of [ADR 0002](0002-app-store-signing-identifiers.md) D1 as empty targets. They carry no product logic yet, but they get signed, embedded and shipped in every build. Their identifiers, groups and NE entitlements are fixed in ADR 0002 and [ADR 0004](0004-network-extension-entitlements.md). This ADR fixes the rest: how each one is packaged, what an empty shell may do, and how the Lab build leaves them out.

Trust boundary: the host app bundle. Every bundle in its embed folders runs with the team's signature and the app's groups.

| Threat | Example |
|---|---|
| T1: A shell runs with no policy | A user approves the content filter, and the empty provider passes or drops traffic on no basis |
| T2: Unreviewed code in the package | A build adds or keeps a bundle that no ADR covers, and it ships with the team signature |
| T3: An extension reaches another component's service | A process outside the App Group looks up a provider's Mach service |
| T4: Lab signing drifts into the shells | The lab build signs a provider under a Developer ID profile that no ADR reviewed |

## Decision

### D1: Packaging per component

| Target | Product type | Platforms | Embed folder in the app | Entry point |
|---|---|---|---|---|
| NetworkFilter | System extension | macOS | `Contents/Library/SystemExtensions` | `NEProviderClasses` → `filter-data` |
| TransparentProxy | System extension | macOS | `Contents/Library/SystemExtensions` | `NEProviderClasses` → `app-proxy` |
| DNSProxy | System extension | macOS | `Contents/Library/SystemExtensions` | `NEProviderClasses` → `dns-proxy` |
| URLFilter | ExtensionKit extension | macOS, iOS | `Extensions` | `com.apple.networkextension.url-filter-control` |
| PacketTunnel | App extension | iOS, tvOS | `PlugIns` | `com.apple.networkextension.packet-tunnel` |
| SafariWebExtension | App extension | macOS, iOS | `PlugIns` | `com.apple.Safari.web-extension` |
| MailExtension | App extension (MailKit) | macOS | `PlugIns` | `com.apple.email.extension` |
| Agent | Login item app (`SMAppService`) | macOS | `Contents/Library/LoginItems` | `LSUIElement` app |

- The SDK declares `NEURLFilterControlProvider` as an `AppExtension`, so the URL filter is an ExtensionKit bundle. That is not a Foundation `NSExtension`.
- Sources are in `Extensions/<Target>/` and `Services/Agent/`, as the [roadmap layout](../../roadmap/README.md#repository-layout) shows. Build settings are in `Configurations/extensions/<Target>.xcconfig`.
- The app depends on each target with a platform filter. Each embed has the same filter, so an iOS or tvOS app embeds only its own shells.
- A system extension is named `<bundle ID>.systemextension`. App Store validation rejects any other name (ITMS 90939), and `scripts/verify-entitlements.py` checks it. Each shell sets `CFBundleDisplayName`, which App Store validation also requires.

### D2: Shells fail closed (T1)

A shell can start only by an explicit system action: the user approves a system extension, or an MDM or the app saves a configuration. With no policy, a running provider would decide on no basis. So every shell refuses to work:

| Shell | Behavior |
|---|---|
| NE providers | `startFilter`, `startProxy` and `startTunnel` complete with an error. The system routes no flow, query or packet to them |
| URL filter | `start()` throws; `fetchPrefilter` returns `nil` |
| Safari handler | Cancels every native message without reading it |
| Mail extension | Declares no `MEExtensionCapabilities`; returns no handler |
| Agent | Exits at launch. Nothing registers it with `SMAppService` |
| Safari manifest | Manifest V3 with empty `permissions` and `host_permissions` |

### D3: The package holds exactly the reviewed set (T2)

`EmbeddedBundlesTests` checks the running host. `scripts/verify-entitlements.py` (`EXPECTED_NESTED`) checks every archive. Both require exactly the set of D1 for the platform: no more, no fewer, no duplicate. A new embedded bundle needs an amendment to this ADR first.

### D4: Mach services start with the App Group (T3)

Each system extension sets `NEMachServiceName` to `$(APP_GROUP_ID).<component>`. The system then allows the lookup only from members of the group ([ADR 0002](0002-app-store-signing-identifiers.md) D3). `EmbeddedBundlesTests` checks the prefix.

### D5: Entitlements of the new bundles

| Bundle | App Store file | Content |
|---|---|---|
| SafariWebExtension | `SafariWebExtension-macOS`, `SafariWebExtension-iOS` | App Sandbox (macOS), App Group |
| MailExtension | `MailExtension` | App Sandbox, App Group |
| Agent | `Agent` | App Sandbox, App Group, Keychain groups (private group first, then shared) |

None of these bundles has a NetworkExtension key. The Agent joins the shared Keychain group, because it authenticates to the server (ADR 0002 D5). The other new bundles store no secret.

### D6: The Lab build embeds no shell (T4)

The Lab build (ADR 0003) exists for the EndpointSecurity track and needs none of the shells yet. Its app keeps `App-Lab.entitlements` unchanged, with no NE value and no `system-extension.install` ([ADR 0004](0004-network-extension-entitlements.md) D6).

- `app-lab.xcconfig` sets `EXCLUDED_SOURCE_FILE_NAMES` to the shell products. An embed phase cannot vary per configuration, but this filter removes the products from it.
- The shells stay app dependencies, so the Lab build still compiles them, with `CODE_SIGNING_ALLOWED = NO` in Lab. No lab profile exists for their IDs. `SKIP_INSTALL` keeps them out of a lab archive.
- A shell joins the lab only with its real logic. It then gets a lab entitlements file with the Developer ID values and its own profile, through an amendment to this ADR and ADR 0004 D6.

## Alternatives considered

- **Shells that pass everything.** An approved filter or proxy would carry traffic with no policy. That is silent, and it looks like protection to the user. Rejected (T1).
- **Embed the shells in the Lab build too.** The lab would exercise packaging early, but it needs seven Developer ID App IDs and profiles, and `-systemextension` values for components with no logic. Rejected: cost and signing surface with no test value yet.
- **Name system extensions after their target.** `OSSystemExtensionRequest` finds an extension by its `Info.plist` identifier, so the system accepts it, but App Store validation rejects it (ITMS 90939). Rejected.
- **One Safari entitlements file for macOS and iOS.** The sandbox key must not appear in an iOS signature (ADR 0004 D4). Rejected.

## Consequences

- Each new App Store App ID needs registration before a signed build succeeds. Each NE App ID gets only its own capability (ADR 0004).
- The lab signing setup is unchanged: no new lab App ID or profile.
- Each shell replaces its refusal with real logic in its own phase. That change needs its own threat review.
