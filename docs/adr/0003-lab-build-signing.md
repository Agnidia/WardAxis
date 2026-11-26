# ADR 0003: Lab build signing and isolation

## Status

Accepted on 2026-11-25 (PRE-003, #3).

## Context

The EndpointSecurity (ES) track is lab-only ([roadmap](../../roadmap/00-preparation.md#capability-dependencies)). An ES client needs the restricted `com.apple.developer.endpoint-security.client` entitlement, Developer ID signing and Full Disk Access. App Review does not accept any of them. [ADR 0002](0002-app-store-signing-identifiers.md) D1 requires a separate lab scheme with Developer ID signing, and no lab entitlement on an App Store target.

Trust boundary: the shipped app (its signing identity, Keychain groups and App Group container) on one side, the lab build on the other.

| Threat | Example |
|---|---|
| T1: A lab binary or lab entitlement reaches App Store Connect | An archive of the wrong configuration is uploaded |
| T2: A lab build reads the shipped app's secrets | The lab app on a dev Mac reads the enrollment token from the shared Keychain group |
| T3: Lab code paths ship | `WARDAXIS_LAB` is defined in a configuration that an App Store scheme archives |

## Decision

### D1: A `Lab` configuration and a `WardAxisLab` scheme

| Item | Value | Source |
|---|---|---|
| Configuration | `Lab`, built on `Release` | `Configurations/lab.xcconfig`, `Configurations/app/app-lab.xcconfig` |
| Scheme | `WardAxisLab`: every action uses `Lab`; no test action targets | `WardAxis.xcodeproj/xcshareddata/xcschemes/WardAxisLab.xcscheme` |
| Platform | macOS only (`SUPPORTED_PLATFORMS = macosx`) | `lab.xcconfig` |
| Compilation condition | `WARDAXIS_LAB` | `lab.xcconfig` |
| Product | `WardAxis Lab.app`, so a tester grants Full Disk Access to the right binary | `app-lab.xcconfig` |

The App Store scheme `WardAxis` still archives `Release`. No App Store configuration defines `WARDAXIS_LAB`.

### D2: A disjoint bundle-ID root

`lab.xcconfig` sets `APP_BUNDLE_ID = com.agnidia.wardaxis.lab`. Every derived identifier moves with it:

| Identifier | App Store | Lab |
|---|---|---|
| App | `com.agnidia.wardaxis` | `com.agnidia.wardaxis.lab` |
| App Group (macOS) | `<team>.com.agnidia.wardaxis` | `<team>.com.agnidia.wardaxis.lab` |
| Shared Keychain group | `com.agnidia.wardaxis.shared` | `com.agnidia.wardaxis.lab.shared` |

The lab build shares no Keychain group and no container with the shipped app (T2). The entitlements file stays the same; only the variables change. App Store Connect has no record for the lab ID, so an upload fails (T1). The `lab` segment is reserved: no App Store bundle ID contains it.

### D3: Manual Developer ID signing

| Item | Value |
|---|---|
| Style | `Manual` |
| Identity | `Developer ID Application` |
| Profile | `WardAxis Lab Developer ID` (Developer ID profile for `com.agnidia.wardaxis.lab`) |
| Export | `Configurations/export/developer-id.plist`, method `developer-id` |

A restricted entitlement reaches a signature only through a manually generated profile. On macOS, the `keychain-access-groups` entitlement also needs a profile. So the lab build signs manually from the start. The ES entitlement later goes on a separate Developer ID profile for the ES extension's App ID (D4); this app profile never carries it.

### D4: The ES entitlement comes after approval, on a lab-only target

No target carries `com.apple.developer.endpoint-security.client` until Apple approves the request ([LAB.md](../LAB.md#entitlement-requests)). Then it goes into a lab-only entitlements file of the ES system-extension target, signed with that extension's own Developer ID profile. The app App ID gains only the System Extension capability, so the app can install the extension but cannot be an ES client. No app entitlements file in `Configurations/Entitlements/` carries it. The app keeps the App Sandbox and the Hardened Runtime in the lab build too: the ES client is a separate process and the app needs no extra privilege.

### D5: Exclusion layers

| Layer | Check | Threat |
|---|---|---|
| Scheme | Only `WardAxisLab` archives `Lab` | T1, T3 |
| Bundle ID | No App Store record for `com.agnidia.wardaxis.lab` | T1 |
| Export method | `app-store-connect` accepts only Apple Distribution | T1 |
| `scripts/verify-entitlements.py` | Rejects a Developer ID authority, the ES entitlement, and any bundle ID with a `lab` segment | T1 |
| `LabExclusionTests` | The App Store test host defines no `WARDAXIS_LAB` and has no `lab` segment in its bundle ID | T3 |

`scripts/verify-entitlements.py` is the gate on an archive: it runs on every archive before an App Store upload (AGENTS.md, Signing). The other layers stop a wrong archive earlier or at upload, but only the script inspects the signed product. `LabExclusionTests` runs the `WardAxis` test action, which builds `Debug`; it proves that the shared configuration chain does not define `WARDAXIS_LAB`, and the script covers the archived `Release` product.

## Alternatives considered

- **Same bundle ID as the App Store app.** No extra App ID, but the lab build would join the shipped app's Keychain groups and App Group container on the same Mac. Rejected (T2).
- **A separate lab target.** It duplicates every target setting, and the copies drift. Rejected.
- **Automatic signing with a `developer-id` export only.** A plain build would be signed Apple Development, not Developer ID, and automatic signing cannot carry a restricted entitlement. Rejected.
- **`WARDAXIS_LAB` set in `Release` behind a setting.** One changed setting would ship lab code. Rejected (T3).

## Consequences

- The Account Holder must register the App ID `com.agnidia.wardaxis.lab`, create a Developer ID Application certificate and the `WardAxis Lab Developer ID` profile before a signed lab build works. Steps are in [LAB.md](../LAB.md).
- A lab archive fails `scripts/verify-entitlements.py` by design. That failure is the evidence that the check catches it.
- The lab build is not debuggable from Xcode: Developer ID signing with the Hardened Runtime does not carry `get-task-allow`. Debug app logic with the `WardAxis` scheme.
- After ORG-001 (#192), the lab App ID, certificate and profile are created again under the organization team.
