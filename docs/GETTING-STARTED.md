# Getting Started

The path from a fresh clone to a green build.

---

## Prerequisites

| Tool | Version | Note |
|---|---|---|
| Xcode | 26.4 or later | The project file is in the JSON format (`WardAxis.xcodeproj/project.xcproj`) that Xcode 26.4 introduced |
| Swift toolchain | 6.4 | The packages declare `swift-tools-version: 6.4`; the code compiles in Swift 6 language mode |
| `swiftformat` | Current (`brew install swiftformat`) | Reads `.swiftformat` |
| Docker Engine with Compose v2 | Current | Only to run the server stack |

Deployment targets (from `Configurations/base.xcconfig`):

| Platform | Minimum |
|---|---|
| iOS / iPadOS | 26.0 |
| macOS | 26.0 |
| tvOS | 26.0 |

---

## 1. Clone and open

```bash
git clone <repository-url>
cd WardAxis
open WardAxis.xcodeproj
```

`Source/`, `Resources/`, `Configurations/` and `Tests/` are synchronized folders. A new file under `Source/` joins the `WardAxis` target. A new test file joins no target until you add it to the `membership-exceptions` list in `project.xcproj`; see [TESTING.md](TESTING.md#add-a-test-file).

Xcode asks once to trust the OpenAPIGenerator build plugin of `WardAxisManagementAPI`. Accept it.

---

## 2. Signing

| Setting | File | Value |
|---|---|---|
| `APP_BUNDLE_ID` | `Configurations/base.xcconfig` | `com.agnidia.wardaxis` (test bundles add `.tests` and `.uitests`) |
| `DEVELOPMENT_TEAM` | `Configurations/sign.xcconfig` | Individual development team until the Agnidia organization enrollment (ORG-001, issue #192) |
| `CODE_SIGN_STYLE` | `Configurations/sign.xcconfig` | `Automatic` |

Do not commit a personal team ID. Change `sign.xcconfig` locally only when you must sign with another team.

---

## 3. Build and test

Every CLI call needs `-skipPackagePluginValidation` for the OpenAPIGenerator plugin. Pair it with `-onlyUsePackageVersionsFromResolvedFile`, so the trust covers only the versions pinned in the committed `Package.resolved`. The reason is in [AGENTS.md](../AGENTS.md#core-commands).

macOS:

```bash
xcodebuild -project WardAxis.xcodeproj \
           -scheme WardAxis \
           -configuration Debug \
           -destination 'platform=macOS' \
           -skipPackagePluginValidation \
           -onlyUsePackageVersionsFromResolvedFile \
           test
```

iOS and tvOS simulators (list the names with `xcrun simctl list devices available`):

```bash
xcodebuild -project WardAxis.xcodeproj -scheme WardAxis -configuration Debug \
           -destination 'platform=iOS Simulator,name=<iPhone simulator>' \
           -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile test

xcodebuild -project WardAxis.xcodeproj -scheme WardAxis -configuration Debug \
           -destination 'platform=tvOS Simulator,name=<Apple TV simulator>' \
           -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile test
```

Use `-configuration Debug` for tests: mocks, `AppContainer.preview()` and `AppContainer.testing()` exist only under `#if DEBUG`.

The scheme runs the `UnitTests` and `UITests` targets. It does not run the package suites. Run them separately:

```bash
(cd Packages/WardAxisTelemetry && swift test)
(cd Packages/WardAxisManagement && swift test)
(cd Packages/WardAxisManagementAPI && swift test)
```

In Xcode: select the `WardAxis` scheme, pick a destination, press ⌘R (run) or ⌘U (test).

See [TESTING.md](TESTING.md) for the test playbook.

---

## 4. Format

```bash
swiftformat .
```

| Fact | Detail |
|---|---|
| Configuration | `.swiftformat` (`--swift-version 6.4`) |
| File headers | `--header ignore` and `--disable headerFileName`: the formatter never changes a file header |
| Build phase | The `SwiftFormat` phase of the `WardAxis` target runs `scripts/formatter.py` on modified files in Xcode GUI builds only. It exits at once in an `xcodebuild` run |
| Helper options | `python3 scripts/formatter.py --all [path]`, `--check [path]`, `--staged` |

---

## 5. Pre-PR quality gate

The repository has no CI workflows. Run the gate locally:

```bash
swiftformat . \
  && xcodebuild -project WardAxis.xcodeproj -scheme WardAxis -configuration Debug \
       -destination 'platform=macOS' \
       -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile test \
  && (cd Packages/WardAxisTelemetry && swift test) \
  && (cd Packages/WardAxisManagement && swift test) \
  && (cd Packages/WardAxisManagementAPI && swift test)
```

Add `(cd Server && swift test)` when the change touches `Server/` or the contract.

---

## 6. Run the server

The server reference, with every variable and its default, is [Server/README.md](../Server/README.md). The short path:

```bash
docker compose -f Server/compose.yaml up -d --build
curl -i http://127.0.0.1:8080/v1/health
```

| Fact | Detail |
|---|---|
| Services | `postgres` (`postgres:18`) and `server` |
| Ports | Both bind to `127.0.0.1` only |
| Local overrides | `cp Server/.env.example Server/.env`; `Server/.env` is git-ignored |
| API reference | `http://127.0.0.1:8080/v1/docs` (development only) |
| Stop | `docker compose -f Server/compose.yaml down`; add `-v` to remove the database volume |

Compose runs plain HTTP in `development`, so the configuration feed is off in the compose stack. The feed needs TLS and `TLS_CLIENT_CA_PATH` (mutual TLS); see [Server/README.md](../Server/README.md#configuration).

### The app and the local server

Debug builds set `API_BASE_URL` to `http://127.0.0.1:8080` (`Configurations/app/app-debug.xcconfig`). The app does not connect to it today:

- `AppContainer.production()` uses `NoClientIdentityProvider`, because no enrollment flow exists yet.
- The feed accepts only `wss`, so a cleartext base URL never opens a socket.

Details: [ARCHITECTURE.md](ARCHITECTURE.md#configuration-feed).

---

## First-run checklist

- [ ] The macOS `xcodebuild ... test` command is green.
- [ ] The three package `swift test` runs are green.
- [ ] The app launches, and the splash screen changes to the tab view (Home, Settings).
- [ ] Settings → Logs shows entries in a Debug build (`Log.configure(for: .debug)` is wired).

If a step fails, compare with the [Quality Gates in AGENTS.md](../AGENTS.md#quality-gates-run-before-pr) or open an issue.

---

## Where to go next

- [ARCHITECTURE.md](ARCHITECTURE.md) - patterns and trust boundaries
- [PROJECT-STRUCTURE.md](PROJECT-STRUCTURE.md) - directory layout
- [FEATURE-DEVELOPMENT.md](FEATURE-DEVELOPMENT.md) - add your first screen
- [DESIGN.md](DESIGN.md) - design tokens
