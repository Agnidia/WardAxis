# Lab build

The lab build is a macOS-only, Developer ID signed build of WardAxis for the EndpointSecurity (ES) track. It is never distributed and never uploaded to App Store Connect. Decisions and rationale: [ADR 0003](adr/0003-lab-build-signing.md). The test devices and the macOS test VM are in [TEST-DEVICES.md](TEST-DEVICES.md).

| Item | Value |
|---|---|
| Scheme | `WardAxisLab` |
| Configuration | `Lab` (`Configurations/lab.xcconfig`, `Configurations/app/app-lab.xcconfig`) |
| Bundle ID | `com.agnidia.wardaxis.lab` |
| Product | `WardAxis Lab.app` |
| Compilation condition | `WARDAXIS_LAB` |
| Signing | Manual, `Developer ID Application`, profile `WardAxis Lab Developer ID` |
| Export options | `Configurations/export/developer-id.plist` |

## Entitlement requests

Apple approves a restricted entitlement per team. Record every change of status here.

| Entitlement | Requested | Status | Apple reference | Updated |
|---|---|---|---|---|
| `com.apple.developer.endpoint-security.client` | 2026-11-25 | Submitted | Request ID `2S8NC8ZH3L` | 2026-11-25 |

Status values: `To submit`, `Submitted`, `Approved`, `Rejected`.

### Submitted justification

The Account Holder submitted the System Extension and EndpointSecurity request form on 2026-11-25 for the bundle ID `com.agnidia.wardaxis.lab`. Text as submitted:

> **App description**
>
> WardAxis is an open-source security product for macOS, iOS/iPadOS and tvOS. It provides network filtering, AI data-loss prevention and enterprise management. The App Store version is fully sandboxed and does **not** use EndpointSecurity.
>
> We request the EndpointSecurity client entitlement for a separate **internal research build** ("lab build") of the macOS app. Its bundle ID is `com.agnidia.wardaxis.lab`. It is signed with Developer ID, runs only on our own test Macs and virtual machines, and is never distributed or uploaded to the App Store.
>
> **How the lab build uses EndpointSecurity**
>
> An ES client runs as a system extension and builds an event-driven runtime security engine. It subscribes to:
>
> - **Process lifecycle:** `ES_EVENT_TYPE_NOTIFY_EXEC`, `NOTIFY_FORK`, `NOTIFY_EXIT`. These build a process graph from audit tokens, parent identity, signing identifier, Team ID and code-signing status.
> - **File activity:** `NOTIFY_CREATE`, `NOTIFY_RENAME`, `NOTIFY_UNLINK`, `NOTIFY_WRITE`, `NOTIFY_MOUNT`. These detect persistence, such as new Launch Agents, Launch Daemons and Login Items, and changes to protected test files.
> - **Authorization:** `ES_EVENT_TYPE_AUTH_EXEC` and `AUTH_OPEN`, evaluated against a local policy snapshot. Audit mode is the default, and the client answers every event once, before its deadline, with no network or disk I/O on the decision path. At first, enforcement applies only to test executables and test files.
>
> Detection rules map to MITRE ATT&CK macOS techniques (T1543.001, T1543.004, T1547.015, T1059.004). We test them with harmless fixtures and replay.
>
> Events stay on the device. The client normalizes them and sends them over authenticated XPC to a local agent. They contain no file contents and are not sent to third parties. We do not disable SIP or other system protections. The client needs Full Disk Access, which the tester grants by hand.

A new request, or a change of scope, gets its own row in the table above and its submitted text here.

## One-time signing setup

Done on 2026-11-25 under the individual team. Repeat after ORG-001 (#192).

1. Register the explicit App ID `com.agnidia.wardaxis.lab` (macOS). Add the App Groups capability with `<team>.com.agnidia.wardaxis.lab`.
2. Create a Developer ID Application certificate (Account Holder only) and install it in the login keychain of the build Mac. Keep the private key in the keychain; never export it into the repository.
3. Create a Developer ID provisioning profile for `com.agnidia.wardaxis.lab` named exactly `WardAxis Lab Developer ID`, and install it. Keep one installed profile with that name: the specifier is a name, and two matches are ambiguous.

## Build and archive

```bash
# Build
xcodebuild -project WardAxis.xcodeproj -scheme WardAxisLab -configuration Lab \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile build

# Archive and export
xcodebuild -project WardAxis.xcodeproj -scheme WardAxisLab -configuration Lab \
  -destination 'generic/platform=macOS' -archivePath build/WardAxisLab.xcarchive \
  -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile archive
xcodebuild -exportArchive -archivePath build/WardAxisLab.xcarchive \
  -exportOptionsPlist Configurations/export/developer-id.plist -exportPath build/lab

# Check the signature: expect "Authority=Developer ID Application: …"
codesign -dvv "build/lab/WardAxis Lab.app"
```

Without the certificate and profile, check that the configuration compiles with `CODE_SIGNING_ALLOWED=NO` added to the build command.

`python3 -I scripts/verify-entitlements.py build/WardAxisLab.xcarchive` must **fail** on a lab archive: it rejects the Developer ID authority and the `lab` bundle ID. A pass means the App Store check is broken.

## After approval

The ES entitlement belongs to the ES system extension only, never to the app ([ADR 0003](adr/0003-lab-build-signing.md#d4-the-es-entitlement-comes-after-approval-on-a-lab-only-target)).

1. Register an explicit App ID for the ES system extension under the lab root, for example `com.agnidia.wardaxis.lab.endpointsecurity`. Take the real ID from the `*_BUNDLE_ID` setting that the extension target adds to `Configurations/base.xcconfig`.
2. Create a Developer ID profile for that App ID. On the "Additional Entitlements" step, select the EndpointSecurity client entitlement. The step appears only after approval.
3. Add the System Extension capability (`com.apple.developer.system-extension.install`) to the app App ID `com.agnidia.wardaxis.lab`, then regenerate `WardAxis Lab Developer ID`. Add the same key to `Configurations/Entitlements/App-Lab.entitlements`. The app profile never carries the ES entitlement.
4. Add the ES entitlement only to the lab-only entitlements file of the ES system-extension target. Never add it to an app entitlements file in `Configurations/Entitlements/`.
5. Update the status table above.
