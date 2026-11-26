# Removal and recovery

How to turn off and remove every WardAxis component on each platform, and how to recover a device from an invalid configuration. Roadmap task: PRE-010 ([roadmap/00-preparation.md](../roadmap/00-preparation.md)). The clean lab snapshot is in [TEST-DEVICES.md](TEST-DEVICES.md#clean-lab-snapshot).

Trust boundaries: TB2 (host app, embedded components and their data) and TB3 (Keychain groups) of the [threat model](THREAT-MODEL.md#trust-boundaries).

| Threat | Example |
|---|---|
| R1: A component outlives the app | The app is gone, but a system extension, a network configuration or a browser extension stays active |
| R2: Data outlives the app | A container, an App Group container or a Keychain item stays on the device after removal |
| R3: Recovery weakens the device | A tester turns SIP off to run `systemextensionsctl uninstall`, and the device stops being a valid test target |

## Rules

- **Recover without weakening the device.** Never turn SIP off. Never run `systemextensionsctl developer`, `systemextensionsctl reset` or `systemextensionsctl uninstall`: all three need SIP off. When the procedures below do not recover a test device, restore the clean snapshot or erase the device.
- **Remove the app with the system UI.** On macOS, move the app to the Trash in Finder. Finder tells the system to uninstall the app's system extensions; `rm` in Terminal does not, and the extension stays registered.
- **Record every run** in the [results log](TEST-DEVICES.md#results-log) of TEST-DEVICES.md, with bundle IDs only, never a device identifier.

## What each component leaves behind

State of the shells today: every shell fails closed ([ADR 0005](adr/0005-extension-shells.md) D2), and the app saves no network configuration ([ADR 0006](adr/0006-debug-system-extension-activation.md) D3). Only a Debug build can activate a component, the NetworkFilter system extension.

| Component | Platforms | Turned on by | Turn it off | Removed with the app |
|---|---|---|---|---|
| NetworkFilter, TransparentProxy, DNSProxy (system extensions) | macOS | User approval in System Settings. Today only NetworkFilter, from Settings → Developer in a Debug build | Settings → Developer → **Deactivate network filter**, or the **Network Extension** switch under System Settings → General → Login Items & Extensions → **WardAxis Extensions** (ⓘ) | Yes, when Finder moves the app to the Trash. The row reads `[terminated waiting to uninstall on reboot]` until the next restart |
| Network configurations of these providers | macOS | A configuration saved by the app or an MDM profile. None today | System Settings → Network → Filters: select the WardAxis entry and delete it | One saved by the app, yes. One from MDM only with its profile |
| URLFilter | macOS, iOS | A saved URL filter configuration. None today | macOS: the `url-filter-control` switch under **WardAxis Extensions**. iOS: delete the app | Yes |
| PacketTunnel | iOS, tvOS | A saved VPN configuration. None today | iOS: Settings → General → VPN & Device Management. tvOS: delete the app | Yes |
| SafariWebExtension | macOS, iOS | The user, in Safari | macOS: Safari → Settings → Extensions → clear **WardAxis**. iOS: Settings → Apps → Safari → Extensions → WardAxis → off | Yes |
| MailExtension | macOS | The user, in Mail | Mail → Settings → Extensions → clear **WardAxis** | Yes |
| Agent (login item) | macOS | Nothing registers it today | System Settings → General → Login Items & Extensions → Open at Login: remove **WardAxis** if it appears | Yes |

| Data | Platforms | Removed with the app | Remove it by hand |
|---|---|---|---|
| App container `com.agnidia.wardaxis` (configuration cache, erase marker, log files) | macOS | **No** | Move `~/Library/Containers/com.agnidia.wardaxis` to the Trash |
| Extension containers `com.agnidia.wardaxis.<component>` | macOS | **No** | Move each `~/Library/Containers/com.agnidia.wardaxis.*` to the Trash |
| App Group container `<team>.com.agnidia.wardaxis` | macOS | **No** | Move `~/Library/Group Containers/<team>.com.agnidia.wardaxis` to the Trash |
| App, extension and App Group containers | iOS, tvOS | Yes | — |
| Keychain items in the private and shared groups ([ADR 0002](adr/0002-app-store-signing-identifiers.md) D5) | All | **No**. Keychain items outlive the app on every platform | None is written today: the app has no enrollment (`NoClientIdentityProvider`). The unenrollment flow must erase them through `SecureItemVault` ([known gap](THREAT-MODEL.md#known-gaps)); a device erase removes them in every case |

macOS asks for permission before one app reads or deletes the container of another. Confirm the prompt, or use Finder. The lab build (`com.agnidia.wardaxis.lab`, [LAB.md](LAB.md)) embeds no shell. Remove it the same way, together with its `com.agnidia.wardaxis.lab*` containers.

## Remove WardAxis

### macOS

1. A Debug build only: open WardAxis → Settings → Developer, and select **Deactivate network filter**.
2. Open System Settings → General → Login Items & Extensions → **WardAxis Extensions** (ⓘ). Turn off every switch, select **Done** and enter your password.
3. Open System Settings → Network → Filters. Delete every WardAxis entry.
4. Open System Settings → General → Device Management. Remove every profile that configures WardAxis.
5. Turn off the Safari and Mail extensions, as the [component table](#what-each-component-leaves-behind) shows.
6. Quit WardAxis. In Finder, move `/Applications/WardAxis.app` to the Trash and empty the Trash.
7. Restart the Mac.
8. Check the result. Each command prints nothing:
   ```bash
   systemextensionsctl list | grep com.agnidia.wardaxis
   ls ~/Library/Containers ~/Library/Group\ Containers | grep -i wardaxis
   ```
9. If a container is still listed, move it to the Trash in Finder (see the [data table](#what-each-component-leaves-behind)).
10. If a system extension row is still listed after the restart, copy the same build to `/Applications` again, open it, and deactivate the extension. Then do steps 6 to 8 again. On a test VM, restore the [clean snapshot](TEST-DEVICES.md#restore-the-snapshot) instead.

### iOS and iPadOS

1. Turn off the Safari extension in Settings → Apps → Safari → Extensions.
2. Open Settings → General → VPN & Device Management. Delete every WardAxis VPN, filter or DNS configuration, and every profile that configures WardAxis.
3. Touch and hold the WardAxis icon, and select **Remove App** → **Delete App**. Over USB: `xcrun devicectl device uninstall app --device <device> com.agnidia.wardaxis`.
4. Check the result. The command lists no app:
   `xcrun devicectl device info apps --device <device> --bundle-id com.agnidia.wardaxis`
5. Supervision does not belong to WardAxis. It stays on the iPad until the iPad is erased ([TEST-DEVICES.md](TEST-DEVICES.md#supervise-the-ipad)).

`<device>` is the device name that `xcrun devicectl list devices` prints. Type it on the command line only; never put it in the repository.

### tvOS

1. Select the WardAxis icon, press and hold the clickpad center, and select **Delete App**. Over the network: `xcrun devicectl device uninstall app --device <device> com.agnidia.wardaxis`.
2. Check the result with the `devicectl device info apps` command of the iOS procedure.

## Recover from an invalid configuration

| Invalid state | What you see | Recovery |
|---|---|---|
| The configuration cache file is truncated, oversize or of another schema, or an earlier enrollment left it | Nothing: the app works | Open the app. At launch the app reports the device as unenrolled and deletes the cache (`RootView`, `ConfigurationService`). An enrolled app also deletes a file that fails the bounds or the decode (`FileConfigurationCache.load`) |
| `API_BASE_URL` is missing or malformed, or is plain `http` to a host that is not loopback | The configuration feed stays idle. The log reads "Configuration feed idle: no usable https server URL" | Correct `API_BASE_URL` in the xcconfig and rebuild. Nothing to clean on the device |
| A system extension row reads `[terminated waiting to uninstall on reboot]`, and activation does not stay on | **Extension state** does not reach **Enabled** | Restart, then activate again from `/Applications` |
| Activation fails with `forbiddenBySystemPolicy` | The status shows the error | Remove the configuration profile in System Settings → General → Device Management, or restore the clean snapshot |
| A saved network configuration points at a shell that refuses to start ([ADR 0005](adr/0005-extension-shells.md) D2) | The configuration shows as not running. A VPN that routes all traffic can stop the network of the device | Turn the configuration off and delete it (macOS: Network → Filters or VPN; iOS: VPN & Device Management), or delete the app |
| Any other state that these steps do not fix | — | [Remove WardAxis](#remove-wardaxis) and install the build again. On a test device, restore the clean snapshot or erase the device |

### Recovery test

The test puts an invalid configuration cache on the device, and checks that the app removes it and keeps working. Run it on each platform after a change to the cache, the enrollment state or the launch path. `ConfigurationCacheTests` in `Packages/WardAxisManagement` cover the same cases as unit tests.

| Case | File content |
|---|---|
| Truncated | `{"schema":1,"version":7,"values":{"a":` |
| Oversize | 300 000 bytes of `[`, more than the 256 KiB limit of `ConfigurationLimits` |
| Unknown schema | `{"schema":99,"version":1,"values":{}}` |
| Stale but valid | `{"schema":1,"version":42,"values":{"feature.enabled":{"bool":true}}}` |

The cache path, relative to the app container:

| Platform | Path |
|---|---|
| macOS, iOS | `Library/Application Support/com.agnidia.wardaxis/Configuration/configuration.json` |
| tvOS | `Library/Caches/com.agnidia.wardaxis/Configuration/configuration.json` |

**macOS.** The app container is `~/Library/Containers/com.agnidia.wardaxis/Data`.

1. Quit WardAxis. Write one case into the cache path. Create the folders if they do not exist.
2. Open WardAxis.
3. Check that the file is gone, that the app still runs, and that Settings opens.
4. Do steps 1 to 3 again for each case.

**iOS, iPadOS and tvOS.** Use a Debug build installed from Xcode: `devicectl` can reach the container of a development-signed app only.

1. Write a case into `case.json` in a temporary folder.
2. Copy it into the container:
   `xcrun devicectl device copy to --device <device> --domain-type appDataContainer --domain-identifier com.agnidia.wardaxis --source case.json --destination "<cache path>"`
3. Cold-launch the app: `xcrun devicectl device process launch --terminate-existing --device <device> com.agnidia.wardaxis`.
   The flag terminates any running instance so each case reruns startup recovery.
4. Check that the file is gone:
   `xcrun devicectl device info files --device <device> --domain-type appDataContainer --domain-identifier com.agnidia.wardaxis --subdirectory "<cache folder>"`
5. Open Settings on the device. Do steps 1 to 5 again for each case.

The test passes when every case leaves the device in a working state: this is the acceptance criterion of PRE-010.
