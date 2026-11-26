# ADR 0006: DEBUG activation of the NetworkFilter system extension

## Status

Accepted on 2026-11-25 (PRE-006, #6).

## Context

PRE-006 requires that system extension approval works on the test Mac. The app has no product code that activates an extension yet. The shells of [ADR 0005](0005-extension-shells.md) refuse to start (D2), and they stay that way. To test approval, the app must submit an `OSSystemExtensionRequest` for its own embedded extension. The user then allows the extension in System Settings.

Trust boundary: the host app and `sysextd`. The app asks the OS to install or remove a bundle that runs as root, outside the app sandbox.

| Threat | Example |
|---|---|
| T1: A shipped control installs extensions | A release user, or a script driving the UI, installs a system extension that the product does not yet use |
| T2: The request names a foreign extension | A wrong build setting makes the app request an identifier outside its own namespace |
| T3: An activated shell carries traffic | An approved filter receives flows with no policy |
| T4: Testing weakens the test Mac | A tester turns SIP off or enables `systemextensionsctl developer` to skip the `/Applications` rule |

## Decision

### D1: The control exists only in DEBUG builds on macOS (T1)

The Developer section of Settings, its buttons and `SystemExtensionDebugViewModel` compile only under `#if DEBUG` (the view adds `os(macOS)`). Release and Lab builds contain no UI path to a request. `SystemExtensionService` itself ships, because Phase 1 activation builds on it. It does nothing until code calls it.

### D2: The identifier comes from the build and must be a direct child of the app ID (T2)

`Resources/Info.plist` carries `WANetworkFilterBundleIdentifier = $(NETWORK_FILTER_BUNDLE_ID)`. `SystemExtensionIdentifier.resolve` accepts the value only when it is `<app bundle ID>.<segment>`, where the segment is one non-empty run of `[A-Za-z0-9-]`, and the value is at most 255 bytes. Any other value, including an unexpanded `$(…)`, fails closed with `invalidIdentifier`, and the app sends no request. The OS activates only extensions embedded in the calling app anyway. This check catches a build error before the OS sees it.

### D3: Activation saves no network configuration (T3)

The service submits only activation and deactivation requests. It never creates or saves an `NEFilterManager` configuration, so the OS starts no provider and routes no flow. ADR 0005 D2 still applies: a started shell fails.

### D4: Replacement is allowed (T1, T3)

The delegate answers `.replace` to a version change. The OS offers a replacement only for the extension embedded in this signed app, so a newer debug build replaces the installed one. That replacement is a shell too.

### D5: No security control is relaxed (T4)

The tester copies the app to `/Applications` and approves it in System Settings. Testing never disables SIP and never enables `systemextensionsctl developer`. Approval tests run in a disposable macOS VM, which is restored from a clean copy afterward ([TEST-DEVICES.md](../TEST-DEVICES.md)).

### D6: The state display only reads, and only while it is visible (T1)

The Developer section shows the extension's state from `OSSystemExtensionRequest.propertiesRequest`, polled once a second. The query changes nothing: its delegate never approves and refuses any replacement. Polling runs in a task bound to the section, so it stops when Settings closes, and it compiles only where the section does (D1). When the OS finished an approval without a callback to the app, the polled state ends the pending request in the UI; the request's late outcome is then ignored.

## Alternatives considered

- **Wait for Phase 1 activation code.** PRE-006 would then not prove approval on the Mac. Rejected.
- **A launch argument that triggers activation.** Any process that can launch the app could install an extension, and the argument would ship unless it is compiled out as well. Rejected: a DEBUG-only UI is simpler to audit.
- **`systemextensionsctl developer on`.** It loads extensions from any path, but it requires SIP off. Rejected (T4).
- **Hardcode the identifier, or derive it from the app ID plus a fixed suffix.** The AGENTS.md rules forbid hardcoded bundle IDs, and the build setting is already the single source. Rejected.

## Consequences

- An Apple Development build needs the NetworkFilter App ID registered on the team. In a VM, the VM must also be registered as a Mac device, so that the development profiles include it.
- Phase 1 reuses `SystemExtensionService` for the shipped activation flow, with its own threat review and its own UI.
