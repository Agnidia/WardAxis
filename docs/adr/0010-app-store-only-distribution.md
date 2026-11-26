# ADR 0010: App Store-only distribution and platform matrix

## Status

Accepted on 2026-11-26 (PRE-008, #8). Roadmap ID: ADR-015.

Amended on 2026-11-26 (#9): the typed schemas and the typed read of feed values exist. See [D3](#d3-no-custom-updater-no-downloaded-code-t2-t3) and [ADR 0011](0011-versioned-schemas.md).

## Context

WardAxis targets macOS 26, iOS/iPadOS 26 and tvOS 26. A security product can ship through the App Store, through Developer ID on macOS, or both. The channel decides what the product can do and how it reaches a fleet.

| Constraint | Source |
|---|---|
| Sandboxing, single bundle, consent, no downloaded code, no root, App Store updates only | Guideline 2.4.5(i)–(v), (vii) |
| Privacy policy, consent, data minimization, visible activity logging | Guidelines 5.1.1, 5.1.2, 2.5.14 |
| A packet tunnel (`NEVPNManager`) app comes from an organization account | Guideline 5.4 |
| The app ships no MDM feature or configuration profile | Guideline 5.5 |
| Provider availability per platform and packaging | [TN3134](https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment), revision 2025-08-19 |

Trust boundary: the distribution channel, from the signed archive to the device (TB1 in [THREAT-MODEL.md](../THREAT-MODEL.md#trust-boundaries)).

| Threat | Example |
|---|---|
| T1: A tampered or unreviewed build reaches a user | A build is offered from a website or a mirror and is not the reviewed one |
| T2: A custom updater becomes a code-delivery channel | An attacker who controls the update server ships code to every device |
| T3: Policy data becomes code | A detector rule format grows an expression language that the extension evaluates |
| T4: The product claims a capability that the platform does not give | The iOS listing promises a content filter that works only on supervised devices |
| T5: Lab material reaches the store | A Developer ID or lab archive is uploaded |

## Decision

### D1: The App Store is the only shipped channel (T1, T5)

The shipped build reaches users only through the Mac App Store, the App Store for iOS and tvOS, and TestFlight. Universal Purchase links the three platforms. Organizations get it through Apple Business Manager managed distribution. The only other build is the lab build ([ADR 0003](0003-lab-build-signing.md), [ADR 0009](0009-endpoint-security-lab-only.md)), which is never published.

### D2: Signing follows the channel (T1, T5)

App Store archives are signed Apple Distribution and exported with the `app-store-connect` method ([ADR 0002](0002-app-store-signing-identifiers.md)). Developer ID signing exists only in the `Lab` configuration. No App Store entitlements file has a `-systemextension` value ([ADR 0004](0004-network-extension-entitlements.md) D2).

### D3: No custom updater, no downloaded code (T2, T3)

The App Store delivers every update. The app downloads no executable code. ML models ship in the bundle. Policies, detector rules and the configuration feed are data:

- The feed envelope is typed and size-bounded at decode. Its `values` are schemaless JSON (`ConfigurationValue`), bounded only in size and nesting depth (32). The feed does not type them.
- Every consumer decodes the values it reads into its own typed `Codable` model and rejects anything else. No consumer interprets a raw `ConfigurationValue` tree as rules ([THREAT-MODEL.md](../THREAT-MODEL.md#threats-of-this-file) TM5). A consumer reads a value with `ManagedConfiguration.document(_:forKey:)`, which decodes it through `SchemaCodec` ([ADR 0011](0011-versioned-schemas.md)).
- A rule format that could express control flow needs its own ADR first.

### D4: The platform matrix is the source of truth for capability claims (T4)

The [platform capability matrix](../../roadmap/README.md#platform-capability-matrix) lists what each platform supports. It is not copied here. Its consequences for the product:

| Platform | Shipped enforcement |
|---|---|
| macOS | Content filter, DNS proxy, transparent proxy (system extensions); URL filter; Safari and Mail extensions; sandboxed agent |
| iOS/iPadOS | URL filter; packet tunnel; Safari extension |
| tvOS | Packet tunnel only, no per-app mode. No Safari, no Mail extension |

The iOS content filter and DNS proxy that TN3134 allows on supervised or managed devices are **not shipped**: no iOS target or entitlement exists for them ([ADR 0004](0004-network-extension-entitlements.md) D1, `EXPECTED_NESTED`). Adding them needs an amendment to ADR 0004 and [ADR 0005](0005-extension-shells.md) first, and then this table.

The App Store listing and every document describe a capability only for the platforms in this table. A new TN3134 revision triggers a review of the matrix and of this table.

### D5: Account and App Review prerequisites

Development uses an individual team. Organization enrollment (ORG-001, #192) comes before the first App Review submission with a packet tunnel (guideline 5.4). The app ships no MDM profile or feature; the separate NanoMDM server delivers profiles (guideline 5.5).

## Alternatives considered

- **Developer ID direct download on macOS.** Allows `-systemextension` NE values, EndpointSecurity and faster releases. It needs notarization, a custom updater (T2) and its own distribution site (T1), and it splits the product. Rejected.
- **Dual channel: App Store and Developer ID.** Reaches both audiences. It doubles signing, release and support, and two builds with the same name drift. Rejected for v1.0.0; a later ADR can revisit it.
- **Enterprise (in-house) distribution on iOS.** Not available to this team, and Apple restricts it to internal use. Rejected.

## Consequences

- Features that need root or a Developer ID entitlement stay in the lab ([ADR 0009](0009-endpoint-security-lab-only.md)).
- Release timing depends on App Review. TestFlight internal builds cover testing before review.
- App Store and TestFlight updates are the only upgrade path to test (roadmap 6.x).
- Packet tunnel builds are blocked from App Review until ORG-001.

## Validation

| Check | Kind | Scope | Decision |
|---|---|---|---|
| `scripts/verify-entitlements.py` | Archive script, before every upload | No Developer ID authority, no `-systemextension` value, no lab entitlement or bundle-ID segment | D1, D2 |
| `Configurations/export/app-store.plist` | Build | Method `app-store-connect`, which signs only with Apple Distribution and App Store profiles | D2 |
| TestFlight upload per platform | Upload | App Store Connect accepts the archive for macOS, iOS and tvOS (Phase 0 acceptance) | D1 |
| Size-bounded decode | Unit tests | The configuration feed rejects oversize, too-deep and malformed frames (`ConfigurationWireTests`) | D3 |
| Typed decode per consumer | Code review; `ConfigurationSchemaTests`, `SchemaFixtureTests` | Each consumer of configuration values has a typed model and a test that rejects a wrong shape | D3 |
| Matrix review | Manual, per TN3134 revision and per listing change | Listing and docs claim no capability outside D4 | D4 |
| Account check | Manual, before the first packet tunnel submission | ORG-001 is done | D5 |
