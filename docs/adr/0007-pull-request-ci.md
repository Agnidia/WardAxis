# ADR 0007: Pull request CI on hosted runners

## Status

Accepted on 2026-11-26 (PRE-007, #7). The workflow is in the repository but disabled until after v1.0.0 (D7).

## Context

PRE-007 requires CI that builds for macOS and the iOS and tvOS simulators, runs unit tests, and gates formatting and static analysis. The workflow is `.github/workflows/PullRequest.yml`.

Trust boundary: code from a pull request, which can come from anyone, runs on a GitHub-hosted runner. The runner reaches the network and the repository token.

| Threat | Example |
|---|---|
| T1: PR code steals secrets or writes to the repository | A test or build plugin reads `GITHUB_TOKEN` or a signing key and pushes a commit or uploads a build |
| T2: A changed dependency runs in CI | A moved action tag, an unpinned SwiftFormat binary, or a newly resolved package version runs attacker code |
| T3: A poisoned cache reaches a trusted job | A PR job writes build products to a cache that a later job restores |
| T4: CI passes but proves less than it claims | Signing is removed for CI, so an entitlement regression goes green |
| T5: Warnings accumulate | New compiler warnings hide a real defect |

## Decision

### D1: `pull_request` only, read-only token, no secrets (T1)

The trigger is `pull_request` (and `workflow_dispatch`), never `pull_request_target`: fork code runs without repository secrets. The workflow sets `permissions: contents: read` and references no secret. Checkout uses `persist-credentials: false`, so the token is not left in `.git/config` for build scripts to read. Signing material never enters this workflow; it belongs to a separate release workflow (roadmap 6.6).

### D2: Every third-party input is pinned (T2)

- `actions/checkout` is pinned by full commit SHA. It is the only action.
- SwiftFormat is downloaded from its GitHub release at a fixed version and checked against a SHA-256 before it runs.
- `xcodebuild` runs with `-skipPackagePluginValidation` only together with `-onlyUsePackageVersionsFromResolvedFile`, and `swift test` with `--force-resolved-versions`: the build plugin trust covers only the reviewed versions in `Package.resolved`.
- The runner image (`xcode-27`) and the Xcode path are fixed in the workflow. The image is a GitHub public preview; the Swift 6.4 tools in `Package.swift` need Xcode 27.

### D3: No caches (T3)

The workflow uses no cache action. Every job builds from a clean checkout. This costs build time and removes cache poisoning between PRs.

### D4: CI builds unsigned and skips `EntitlementsTests` (T4)

Hosted runners have no team certificate. All targets build with `CODE_SIGNING_ALLOWED=NO`. On macOS the linker's ad hoc signature lets the test host launch; an ad hoc signature with an identity (`CODE_SIGN_IDENTITY=-`) is refused because the extension targets require a provisioning profile. The binaries carry no entitlements, so `EntitlementsTests` (which reads the team signature of the host app) is skipped with `-skip-testing:UnitTests/EntitlementsTests`. Entitlements stay enforced elsewhere:

- `scripts/verify-entitlements.py` on every archive before upload (AGENTS.md).
- `EntitlementsTests` in the local signed gate and on the test devices.

UITests do not run in CI; they need a GUI session. Server suites do not run; they need PostgreSQL.

### D5: Warnings are errors in project targets only (T5)

CI passes `WA_WARNINGS_AS_ERRORS=YES`. `Configurations/base.xcconfig` maps it to `SWIFT_TREAT_WARNINGS_AS_ERRORS` and `GCC_TREAT_WARNINGS_AS_ERRORS`, so it reaches only targets that use the project xcconfigs. Setting `SWIFT_TREAT_WARNINGS_AS_ERRORS` on the command line also reaches remote package targets, which build with `-suppress-warnings`, and the two flags conflict. Local builds keep the default `NO`.

### D6: Static analysis is `xcodebuild analyze` (T5)

Each platform job runs `xcodebuild analyze` after the tests, with the same warning policy. It adds no tool and no configuration to review.

### D7: Disabled by a repository variable until after v1.0.0

Every job has `if: vars.CI_ENABLED == 'true'`. Until the variable is set, the jobs show as skipped and the local gate in AGENTS.md remains the only gate. To enable CI, set the repository variable `CI_ENABLED` to `true`; no code change is needed.

## Alternatives considered

- **`pull_request_target`.** Runs with secrets and a write token on fork code. Rejected (T1).
- **SwiftLint.** More rules, but a new binary to pin and a configuration to review, and an initial cleanup. Rejected for now; `xcodebuild analyze` plus warnings-as-errors covers PRE-007.
- **Ad hoc signing with entitlements on macOS.** AMFI refuses restricted entitlements under an ad hoc signature, and the extension targets require a profile. Rejected (D4).
- **Install SwiftFormat with Homebrew.** The formula version moves. Rejected (T2).
- **Disable with `workflow_dispatch` only, or park the file outside `.github/workflows/`.** Both need a code change to enable. Rejected in favor of D7.

## Consequences

- An entitlement regression is caught by the archive check or the local gate, not by CI.
- A new compiler warning fails CI once it is enabled; fix it, do not suppress it without a documented reason.
- When GitHub moves the `xcode-27` image or removes the Xcode version, update `runs-on` and `XCODE_APP` together.
