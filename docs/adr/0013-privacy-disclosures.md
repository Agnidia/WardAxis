# ADR 0013: Privacy disclosures and per-bundle manifests

## Status

Accepted on 2026-11-26 (PRE-011, #11).

## Context

App Review requires a privacy policy, an App Privacy label that matches what the app does, and consent before any monitoring. Each bundle that ships must carry its own privacy manifest. WardAxis inspects network traffic, web pages and mail, so its disclosures are part of the security claim.

| Constraint | Source |
|---|---|
| Privacy policy, consent and data minimization | Guidelines 5.1.1, 5.1.2 |
| A visible indication while the app monitors activity | Guideline 2.5.14 |
| No launch at login without consent | Guideline 2.4.5(iii) |
| A privacy manifest per bundle; required-reason APIs declared with an approved reason | [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) |
| Classification runs on the device; telemetry is opt-in and has no matched content | [roadmap](../../roadmap/README.md#app-store-constraints) |

Trust boundary: TB1 (the signed archive) and the user's consent for each component in TB2.

| Threat | Example |
|---|---|
| T1: An undeclared data flow | A component starts to send device data, and the label still says Data Not Collected |
| T2: A bundle without a manifest, or with a false one | An extension ships with no manifest; validation warns, or a reviewer finds an undeclared required-reason API |
| T3: Inspection without consent | A filter or extension inspects content before the user agrees to it |
| T4: Disclosures drift apart | The policy, the label and the manifests describe different data |

## Decision

### D1: The label is Data Not Collected (T1)

No data leaves the device in a way that lets Agnidia or a third party read it. The inventory in [PRIVACY.md](../PRIVACY.md#data-inventory) gives the reason for each flow:

- Flows, DNS, URLs, page text and mail stay in memory in the component that inspects them.
- Telemetry has no remote sink.
- The diagnostic log leaves only when the user shares it.
- The management server belongs to the organization that enrolls the device.

PRIVACY.md lists the events that change the label. Each such change updates the label, the manifests and the policy together.

### D2: One manifest per bundle, from evidence (T2)

The app and each of the eight embedded bundles of [ADR 0005](0005-extension-shells.md) D1 carry a `PrivacyInfo.xcprivacy`. Each one declares no tracking and no collected data. Each one lists only the required-reason APIs that a symbol scan of its Release binary finds. The scan found none, so the app's `NSPrivacyAccessedAPICategoryFileTimestamp` (`C617.1`) entry was removed: it came from the project template, and no code calls a file timestamp API.

### D3: Gates fail closed (T2)

- `EmbeddedBundlesTests` requires a manifest in the host and in each embedded bundle. Each manifest must decode with typed keys and must declare no tracking.
- `scripts/verify-entitlements.py` requires the same for every bundle of an archive. The manifest must be present, at most 64 KiB, and a property list, with `NSPrivacyTracking` false and no tracking domain.

A missing or malformed manifest fails both gates.

### D4: Consent comes before the system prompt (T3)

Each component shows its own consent screen before the system approval that it needs. The screen uses the copy in [PRIVACY.md](../PRIVACY.md#consent-copy): what the component inspects, and that nothing it inspects is sent. The user can decline one component and keep the others. The shells stay fail-closed until their consent screen ships ([ADR 0005](0005-extension-shells.md) D2).

### D5: One source for the disclosures (T4)

PRIVACY.md is the source for the label, the manifests and the consent copy. [privacy/PRIVACY-POLICY.md](../privacy/PRIVACY-POLICY.md) is the source for the hosted `policy.html`, and it states only what the inventory states.

## Alternatives considered

- **The app's manifest only.** Less to maintain. Rejected: validation reads each bundle's own manifest (T2).
- **Declare data types and API reasons defensively.** Fewer review questions now. Rejected: a label that claims collection that does not happen hides the real flows when they arrive, and an unused API reason is a false statement (T1, T4).
- **One consent screen for all components.** Fewer screens. Rejected: the user cannot agree to the Safari extension without the mail check, and 5.1.1 asks for consent to each kind of data (T3).
- **Keep the policy text only in the site repository.** It already exists there. Rejected: it would drift from the inventory, which changes in this repository (T4).

## Consequences

- A component that gets real logic runs the symbol scan again and updates its manifest in the same change.
- A remote telemetry sink, an Agnidia-operated service or a third-party SDK needs a label change first.
- The consent screens move the copy into `Localizable.xcstrings` when they ship.
- Open: the policy's contact address, and the deployment of `policy.html` before submission ([AppStore/README.md](../../AppStore/README.md)).

## Validation

| Check | Kind | Scope | Decision |
|---|---|---|---|
| `EmbeddedBundlesTests` (privacy manifest cases) | Test | Test host and its embedded bundles; a missing or incomplete manifest | D2, D3 |
| `scripts/verify-entitlements.py` | Script | Every bundle of an archive | D2, D3 |
| Required-reason symbol scan in [PRIVACY.md](../PRIVACY.md#privacy-manifests) | Manual step | Release binaries of each bundle | D2 |
| App Store Connect validation | Upload | Privacy manifest warnings of the build | D2 |
| Review of PRIVACY.md and the policy against each component's data flow | Review | Each change that adds a data flow | D1, D4, D5 |
