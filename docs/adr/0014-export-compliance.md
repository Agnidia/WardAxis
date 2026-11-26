# ADR 0014: Export compliance declaration

## Status

Accepted on 2026-11-27 (PRE-012, #12).

## Context

App Store Connect asks each build whether the app uses encryption, and whether that use is exempt from US export regulations. Until a build answers, TestFlight does not release it. The `ITSAppUsesNonExemptEncryption` Info.plist key answers the question in the build itself. WardAxis is a security product, so the answer is a legal statement that must match the code.

| Constraint | Source |
|---|---|
| Each build declares its encryption use; a missing answer blocks TestFlight | [Complying with encryption export regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations) |
| `ITSAppUsesNonExemptEncryption` answers the question in the build | [Information Property List](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption) |
| Encryption that the OS provides, and encryption used only for authentication or integrity, is exempt | US EAR Category 5 Part 2, as summarized in the App Store Connect export compliance questions |
| The shipped proxy forwards and never terminates TLS; the tvOS packet tunnel filters DNS only | [roadmap 02](../../roadmap/02-tls-pki.md), [roadmap 01](../../roadmap/01-network-security.md) (NET-025) |

Trust boundary: TB1 (the signed archive) in [THREAT-MODEL.md](../THREAT-MODEL.md#trust-boundaries).

| Threat | Example |
|---|---|
| T1: A false declaration | A component bundles its own cipher or a VPN, and the build still declares `false` |
| T2: A bundle without the key, or with a drifted value | An extension omits the key, or one Info.plist says `true`; App Store Connect asks again and the upload stops before TestFlight |
| T3: A new crypto use arrives without a new decision | A dependency update pulls in a crypto library, and nobody reviews the declaration |

## Decision

### D1: Declare `false` (T1)

Every use of encryption in the client is exempt:

| Use | Implementation | Why exempt |
|---|---|---|
| TLS to the management server (TB4) | `URLSession`, Network.framework | Provided by the OS |
| mTLS client identity (roadmap 05) | Security framework, identity in the Keychain | Provided by the OS; authentication only |
| Signed policy check (roadmap 05) | CryptoKit Ed25519 (`Curve25519.Signing`) | Provided by the OS; integrity and authentication only |
| Keychain and file protection | Data Protection, Keychain | Provided by the OS |

No component encrypts user data with its own code. The client package graph holds no crypto library (`Package.resolved`: OpenAPI generator and runtime, OpenAPIKit, Yams, swift-algorithms, swift-numerics, swift-http-types, swift-argument-parser). `NIOSSL` is in `Server/` only and is not part of the App Store archive.

### D2: One source for every bundle (T2)

`Configurations/base.xcconfig` sets `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`. Xcode merges the value into each target's Info.plist, the explicit files and the generated Agent plist alike. No Info.plist file sets the key, so no copy can drift.

### D3: Re-decide on a trigger (T3)

Each of these changes amends this ADR before it merges:

- The packet tunnel or any other component encrypts traffic itself (for example a VPN).
- A crypto library enters the client graph (swift-crypto, BoringSSL, libsodium or similar).
- A proprietary or non-standard algorithm is used anywhere.
- Data at rest is encrypted outside Data Protection and the Keychain.
- Server code ships inside the app.

## Alternatives considered

- **Declare `true` and file an export document.** Covers any future use. Rejected: the statement would be false today, and it adds annual self-classification work for no reason (T1).
- **Answer in App Store Connect for each build.** No code change. Rejected: a manual step on every upload, which blocks TestFlight when forgotten (T2).
- **Set the key in each Info.plist.** Visible next to the other keys. Rejected: the Agent has no Info.plist file, and nine copies can drift (T2).

## Consequences

- Uploads reach TestFlight without the export compliance question.
- A reviewer of a dependency change checks D3 together with the privacy manifests ([ADR 0013](0013-privacy-disclosures.md)).

## Validation

| Check | Kind | Scope | Decision |
|---|---|---|---|
| `EmbeddedBundlesTests` (`Every bundle declares only exempt encryption`) | Test | Test host and its embedded bundles; a missing or non-boolean key fails | D2 |
| `scripts/verify-entitlements.py` (`check_export_compliance`) | Script | Every bundle of an archive | D2 |
| App Store Connect upload | Upload | The build reaches TestFlight with no export compliance question | D1, D2 |
| Review of the client package graph and of new crypto calls | Review | Each change that adds a dependency or a crypto API | D1, D3 |
