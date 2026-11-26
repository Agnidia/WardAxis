# Phase 0 — Preparation

[Roadmap](README.md) | [Next phase](01-network-security.md)

**Release:** v0.0.1 (TestFlight internal) · **Estimate:** 12–18 hours

**Platforms:** macOS · iOS/iPadOS · tvOS

**Goal:** Establish a reproducible project that is signed for the App Store on all three platforms, and isolate external capability dependencies before implementation.

**Distribution:** All tasks are **Shipped** unless marked **Lab-only**.

## Tasks

- [x] PRE-001 — Create GitHub repository; select Apache-2.0 or MIT license; configure issue templates and milestones. Development uses a paid individual Apple Developer account; organization enrollment is [ORG-001](05-enterprise-management.md#50-prerequisite-organization-enrollment) at the start of Phase 5.
- [x] PRE-002 — Configure App Store signing: bundle-identifier scheme for the app, each extension, the Safari Web Extension and the Mail extension; App Group and Keychain access-group identifiers; App Store Connect app records with Universal Purchase for macOS, iOS and tvOS; Xcode automatic signing for App Store schemes.
- [x] PRE-003 — **Lab-only.** Request the restricted EndpointSecurity entitlement from Apple; track approval as an external dependency. Configure a separate Developer ID scheme for the lab build.
- [x] PRE-004 — Enable NetworkExtension capabilities per [TN3134](https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment): content filter, DNS proxy and app proxy as system extensions on macOS; URL filter on macOS and iOS; packet tunnel on iOS and tvOS. Add `com.apple.developer.system-extension.install` and the App Sandbox to every macOS target.
- [x] PRE-005 — Create Swift 6.4 packages (Swift 6 language mode) and a multiplatform Xcode app target with minimum versions macOS 26, iOS 26 and tvOS 26. Add extension targets as empty shells.
- [x] PRE-006 — Prepare test devices: a disposable macOS VM or dedicated Mac, an iPhone or iPad that can be supervised, and an Apple TV. Validate system extension approval and enrollment behavior on each.
- [ ] PRE-007 — Configure CI for compilation on macOS and the iOS and tvOS simulators, unit tests, formatting and static analysis. The workflow exists and is enabled after v1.0.0 ([ADR 0007](../docs/adr/0007-pull-request-ci.md)).
- [x] PRE-008 — Write initial threat model, trust boundaries and ADRs (ADR-001, ADR-005, ADR-015 first); define project scope and out-of-scope functionality. See [THREAT-MODEL.md](../docs/THREAT-MODEL.md), [ADR 0008](../docs/adr/0008-extensions-under-app-store.md), [ADR 0009](../docs/adr/0009-endpoint-security-lab-only.md) and [ADR 0010](../docs/adr/0010-app-store-only-distribution.md).
- [x] PRE-009 — Define versioned event, policy and application identity schemas; introduce synthetic data sources and fixtures. See [ADR 0011](../docs/adr/0011-versioned-schemas.md).
- [x] PRE-010 — Document how to disable and remove every extension, test recovery from an invalid configuration, and take a clean lab snapshot. See [RECOVERY.md](../docs/RECOVERY.md) and [TEST-DEVICES.md](../docs/TEST-DEVICES.md#clean-lab-snapshot).
- [ ] PRE-011 — Draft the privacy policy, consent-screen copy, App Privacy label inventory and privacy manifest (`PrivacyInfo.xcprivacy`) for the app and each extension.
- [ ] PRE-012 — Decide export compliance (`ITSAppUsesNonExemptEncryption`) and record the rationale.

## Capability dependencies

| Component | Prerequisite | Fallback |
|---|---|---|
| NetworkExtension (macOS system extensions) | Provider-specific capability, signing and provisioning | Policy and flow fixture tests |
| URL filter (macOS, iOS) | URL filter capability, OS 26 | Policy fixture tests |
| Packet tunnel (iOS, tvOS) | Packet tunnel capability (paid developer account); organization account for App Review (ORG-001) | Simulated tunnel fixtures |
| SystemExtensions | Host installation entitlement and signed embedded extension | Test host and lifecycle mock |
| Sandboxed agent (macOS) | Login item registration, App Group | In-app service fixture |
| Safari Web Extension | Embedded extension, user enables it in Safari | Headless JS/TS unit tests |
| Mail extension | Embedded MailKit extension, user enables it in Mail | Handler unit tests with fixture messages |
| App Store review | Organization account (ORG-001), privacy policy, review notes | TestFlight internal builds |
| MDM | HTTPS, MDM APNs credentials and supported enrollment | Simulated command and enrollment fixtures |
| EndpointSecurity (**Lab-only**) | Apple restricted entitlement, Developer ID signing and Full Disk Access | Synthetic event adapter; no claim of kernel integration |

Do not disable SIP or system security controls on the development machine to make installation work. Validate real integration separately from mock environments.

## Acceptance criteria

- [ ] Clean checkout builds for macOS, iOS and tvOS; pure Swift tests run in CI.
- [ ] Signing and entitlement requirements documented per target and per platform.
- [ ] All App Store schemes build sandboxed with no root-requiring or lab entitlements.
- [ ] Internal TestFlight upload succeeds for all three platforms.
- [ ] Privacy policy draft, consent copy and privacy manifests committed.
- [x] Lab-only: entitlement request submitted; status recorded.
- [ ] Test environment is recoverable; disable/removal procedure exists.
- [x] ADR template and initial threat model committed.
- [x] Initial schemas and synthetic adapters have fixture tests.

## Deliverables

Repository, multiplatform Xcode targets, packages, CI workflow, App Store Connect records, capability matrix, privacy drafts, lab instructions, initial architecture and threat model.

## References

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [TN3134](https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment)
- [Apple System Extensions](https://developer.apple.com/system-extensions/)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [EndpointSecurity](https://developer.apple.com/documentation/endpointsecurity) (lab track)
