# Lab build

The lab build is a macOS-only, Developer ID signed build of WardAxis for the EndpointSecurity (ES) track. It is never distributed and never uploaded to App Store Connect. Decisions and rationale: [ADR 0003](adr/0003-lab-build-signing.md).

| Item | Value |
|---|---|
| Scheme | `WardAxisLab` |
| Configuration | `Lab` (`Configurations/lab.xcconfig`, `Configurations/app/app-lab.xcconfig`) |
| Bundle ID | `com.agnidia.wardaxis.lab` |
| Compilation condition | `WARDAXIS_LAB` |
| Signing | Manual, `Developer ID Application`, profile `WardAxis Lab Developer ID` |
| Export options | `Configurations/export/developer-id.plist` |

## Entitlement requests

Apple approves a restricted entitlement per team. Record every change of status here.

| Entitlement | Requested | Status | Apple reference | Updated |
|---|---|---|---|---|
| `com.apple.developer.endpoint-security.client` | 2026-11-25 | Submitted | — | 2026-11-25 |

Status values: `To submit`, `Submitted`, `Approved`, `Rejected`.

### Submit the request

Only the Account Holder of the team can submit.

1. Sign in to the Apple Developer account as the Account Holder.
2. Open the System Extension and EndpointSecurity request form. It is linked from the [EndpointSecurity documentation](https://developer.apple.com/documentation/endpointsecurity) ("Request an entitlement"). Apple moves the form from time to time; follow the link from the documentation, not a saved URL.
3. Select the EndpointSecurity client entitlement and give the lab bundle ID `com.agnidia.wardaxis.lab`.
4. Describe the use. Draft:

   > WardAxis is a security product under development. We request the EndpointSecurity client entitlement for an internal research build that observes process and file events on dedicated test Macs and virtual machines. The build is signed with Developer ID, is never distributed, and is not part of the App Store app. The shipped App Store app does not use EndpointSecurity.

5. Record the submission date, the status `Submitted` and Apple's reference in the table above. Commit the change.

## One-time signing setup

1. Register the explicit App ID `com.agnidia.wardaxis.lab` (macOS). Add the App Groups capability with `<team>.com.agnidia.wardaxis.lab`.
2. Create a Developer ID Application certificate (Account Holder only) and install it in the login keychain of the build Mac. Keep the private key in the keychain; never export it into the repository.
3. Create a Developer ID provisioning profile for `com.agnidia.wardaxis.lab` named exactly `WardAxis Lab Developer ID`, and install it.

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
codesign -dvv build/lab/WardAxis.app
```

Without the certificate and profile, check that the configuration compiles with `CODE_SIGNING_ALLOWED=NO` added to the build command.

`python3 -I scripts/verify-entitlements.py build/WardAxisLab.xcarchive` must **fail** on a lab archive: it rejects the Developer ID authority and the `lab` bundle ID. A pass means the App Store check is broken.

## After approval

1. Regenerate the `WardAxis Lab Developer ID` profile. It then carries the ES entitlement.
2. Add the ES entitlement only to the lab-only entitlements file of the ES system-extension target. Never add it to `Resources/entitlement.entitlements`.
3. Update the status table above.
