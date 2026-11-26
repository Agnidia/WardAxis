# Test devices

The physical devices and the VM that WardAxis is tested on, how to prepare each one, and the results. Roadmap task: PRE-006 ([roadmap/00-preparation.md](../roadmap/00-preparation.md)). The activation control used here is recorded in [ADR 0006](adr/0006-debug-system-extension-activation.md).

## Rules

- **No device identifiers in the repository.** Record only role, model, model identifier, OS version and build, and supervision state. Never record a serial number, UDID, provisioning UDID, ECID, IMEI, MAC address, hardware UUID, CoreDevice ID or a device name that contains a person's name. You register a UDID in the Apple Developer portal only.
- **Do not weaken the test devices.** Keep SIP on. Never run `systemextensionsctl developer on`. Never install a lab root certificate outside MDM (Phase 5).
- **Treat test devices as disposable.** Test system extensions in the macOS VM, never on the development Mac. Supervision erases an iOS device, so back it up first.

## Inventory

| Role | Model | Model identifier | OS | Build | Supervised |
|---|---|---|---|---|---|
| Development and build Mac, VM host | MacBook Air (Apple M3, 16 GB) | `Mac15,13` | macOS 27.2.1 | 26B131 | — |
| System extension test VM | macOS VM on the MacBook Air (UTM, Apple backend, 8 GB) | `VirtualMac2,1` | macOS 27.2.1 | 26B131 | — |
| Unsupervised iOS device | iPhone 16 Pro | `iPhone17,1` | iOS 27.2.1 | 24B156 | No |
| Supervised iOS device | iPad mini (A17 Pro) | `iPad16,1` | iPadOS 27.2.1 | 24B156 | Yes, by `Agnidia Lab` (Apple Configurator, no MDM) |
| Apple TV | Apple TV 4K (2nd generation) | `AppleTV11,1` | tvOS 27.2.1 | 24K157 | — |

The iPhone stays unsupervised. The roadmap requires that the URL filter works without supervision (NET, Phase 1). The iPad becomes the supervised device for the content filter and DNS proxy profiles (Phase 5).

### Collect the values

These commands print only the fields of the table.

```bash
# Mac or VM
sw_vers
system_profiler SPHardwareDataType | grep -E "Model Name|Model Identifier|Chip|Memory"
sysctl -n kern.hv_vmm_present   # 1 = VM, 0 = physical Mac

# iPhone, iPad, Apple TV (connected or paired, and unlocked)
xcrun devicectl list devices --json-output "$TMPDIR/devices.json" >/dev/null
jq -r '.result.devices[] | [.hardwareProperties.marketingName, .hardwareProperties.productType, .deviceProperties.osVersionNumber, .deviceProperties.osBuildUpdate] | @tsv' "$TMPDIR/devices.json"
rm "$TMPDIR/devices.json"   # the file also holds UDIDs and device names
```

Do not paste the full `system_profiler` or `devicectl` output anywhere: it contains the identifiers listed in [Rules](#rules).

## macOS test VM

1. Create a macOS VM on the MacBook Air in UTM with the Apple Virtualization backend. Install macOS 26 or later. Give it at most half of the host memory (8 GB on a 16 GB host).
2. Finish the setup with a local test account. Keep SIP on.
3. In the VM, read the provisioning UDID with `system_profiler SPHardwareDataType | grep "Provisioning UDID"`. Register it in the Apple Developer portal under Devices as a Mac. Do not record it anywhere else.
4. On the MacBook Air, build the `WardAxis` scheme once in Xcode with automatic signing. Xcode then regenerates the development profiles with the VM included.
5. In UTM, add a shared directory for build transfer (VM settings → Sharing; the VM must be shut down, not suspended). The guest mounts it under `/Volumes/My Shared Files`.
6. Take the [clean lab snapshot](#clean-lab-snapshot).
7. Update the VM row of the [inventory](#inventory).

## System extension approval (macOS VM)

Prerequisite: the App IDs `com.agnidia.wardaxis` and `com.agnidia.wardaxis.networkfilter` are registered with the Network Extensions capability (see [GETTING-STARTED.md](GETTING-STARTED.md)).

1. On the MacBook Air, build the `WardAxis` scheme in the Debug configuration for macOS.
2. Archive the app with `ditto -c -k --keepParent WardAxis.app WardAxis-Debug.zip`, which keeps the signatures, and put it in the shared directory. In the VM, unpack it into `/Applications`: `ditto -x -k "/Volumes/My Shared Files/WardAxis-Debug.zip" /Applications`. The OS activates extensions only for an app in `/Applications`.
   Check that the development profile includes the VM; it prints `1` when it does: `security cms -D -i /Applications/WardAxis.app/Contents/embedded.provisionprofile | grep -c "$(system_profiler SPHardwareDataType | awk '/Provisioning UDID/ {print $3}')"`
3. Start a log stream in the VM: `log stream --predicate 'subsystem == "com.apple.sx"' --level info`.
4. Open WardAxis → Settings → Developer, and select **Activate network filter**. macOS shows "“WardAxis” would like to use a new network extension", and the status reads "Allow the extension in System Settings…". **Extension state** reads **Waiting for approval**.
5. In the prompt, select **Open System Settings**; it opens the WardAxis system extension directly. **OK** only closes the prompt: then open System Settings → General → Login Items & Extensions → **WardAxis Extensions** (ⓘ) yourself. Turn on **Network Extension**, select **Done** and enter your password. Within a second, **Extension state** reads **Enabled** and the status changes to **Activated**. The same sheet lists `com.apple.networkextension.url-filter-control`, switched on: that is the URLFilter app extension, which needs no approval and does nothing without a saved configuration. If an earlier copy shows `terminated waiting to uninstall on reboot` and the switch does not stay on, restart the VM and activate again.
6. Run `systemextensionsctl list`. The `com.agnidia.wardaxis.networkfilter` row shows `[activated enabled]`.
7. Open System Settings → Network → Filters. It lists no WardAxis filter, because activation saves no configuration (ADR 0006 D3).
8. Select **Deactivate network filter**. The status changes to **Deactivated**, and `systemextensionsctl list` no longer shows the row as `[activated enabled]`. The OS can show it as waiting to uninstall until the next restart.
9. Record the result in the [results log](#results-log). [Restore the clean snapshot](#restore-the-snapshot).

| Status shown | Cause | Fix |
|---|---|---|
| Failed: `unsupportedParentBundleLocation` | The app runs from the build folder | Copy it to `/Applications` |
| Failed: `missingEntitlement` | The profile has no Network Extensions or System Extension capability | Register the capabilities on both App IDs and rebuild |
| Failed: `codeSignatureInvalid` | The bundle changed after signing | Copy the app again from a fresh build |
| Failed: `invalidIdentifier` | `WANetworkFilterBundleIdentifier` is not `<app ID>.<segment>` | Check `NETWORK_FILTER_BUNDLE_ID` in `Configurations/base.xcconfig` |
| Failed: `forbiddenBySystemPolicy` | A configuration profile blocks the extension | Remove the profile, or restore the clean VM copy |
| Stays on "Allow the extension…"; Extension state reads **Waiting for approval** | macOS has no approval recorded (`systemextensionsctl list` shows `[activated waiting for user]`). The URL filter switch being on is not the approval | Turn on **Network Extension** under WardAxis Extensions and enter your password; restart first if an earlier copy waits to uninstall |

## Supervise the iPad

Supervision erases the iPad. Back it up first.

1. Install Apple Configurator from the Mac App Store on the MacBook Air.
2. Connect the iPad by USB and unlock it.
3. Select the iPad → Prepare → Manual Configuration. Select **Supervise devices** and **Allow devices to pair with other computers**, so that Xcode can still install builds. Clear **Add to Apple School Manager or Apple Business**: it needs an Apple Business Manager account, which the team does not have before the organization enrollment (ORG-001). With it selected, Prepare fails with "cannot manage devices in Apple School Manager or Apple Business".
4. At Server, choose **Do not enroll in MDM**. Enrollment is MDM-011 (Phase 5). Skip the Apple School Manager or Apple Business sign-in.
5. Create a new organization named `Agnidia Lab` and choose **Generate a new supervision identity**. The identity is a certificate and private key. Keep it in the MacBook Air keychain and export a backup to an encrypted store. Never put it in the repository.
6. Finish Prepare. The iPad is erased and restarts.
7. Check the result: the top of Settings → General → About reads "This iPad is supervised and managed by Agnidia Lab". Update the [inventory](#inventory).

## Install a test build on iPhone, iPad and Apple TV

1. **iPhone and iPad:** connect the device and trust the Mac. Turn on Settings → Privacy & Security → Developer Mode and restart.
2. **Apple TV:** on the Apple TV, open Settings → Remotes and Devices → Remote App and Devices. Pair it in Xcode → Window → Devices and Simulators.
3. Run the `WardAxis` scheme in Debug on each device from Xcode.
4. Check that the app launches and that Settings opens. The Developer section is macOS-only, so it does not appear.
5. Record the result in the [results log](#results-log).

The iOS and tvOS shells cannot be activated yet. The packet tunnel and the URL filter need a saved configuration, and that arrives in Phase 1. Enrollment behavior on iPad and Apple TV is tested with MDM in Phase 5 (MDM-011, MDM-012).

## Clean lab snapshot

A clean snapshot is a test device with no WardAxis app, extension, configuration, profile or container. Every system extension test starts from it and ends by restoring it. The removal and recovery steps are in [RECOVERY.md](RECOVERY.md).

### Take the snapshot (macOS VM)

UTM has no snapshots with the Apple backend, so the snapshot is a clone of the VM bundle. An APFS clone takes no extra space until the copies differ. The clone keeps the machine identifier of the VM, so the provisioning UDID registered in the Developer portal stays valid.

1. Start the VM and check that it is clean. Each command prints nothing:
   ```bash
   systemextensionsctl list | grep com.agnidia.wardaxis
   ls /Applications ~/Library/Containers ~/Library/Group\ Containers | grep -i wardaxis
   ```
   Then check that System Settings → General → Device Management lists no profile, and that `csrutil status` reads `enabled`.
2. Shut the VM down. Do not suspend it: a suspended VM keeps its memory state in the bundle.
3. Replace the old snapshot with a new clone:
   ```bash
   cd ~/Library/Containers/com.utmapp.UTM/Data/Documents
   rm -rf macOS-clean.utm
   cp -c -R macOS.utm macOS-clean.utm
   ```
4. Record the snapshot in the [results log](#results-log), with the macOS version and build.

Take a new snapshot after a macOS update and after a change to the shared directory. Never take one while a WardAxis build is installed.

### Restore the snapshot

1. Shut the VM down.
2. Replace the used VM with a clone of the snapshot:
   ```bash
   cd ~/Library/Containers/com.utmapp.UTM/Data/Documents
   rm -rf macOS.utm
   cp -c -R macOS-clean.utm macOS.utm
   ```
3. Start the VM, and do the checks of step 1 of [Take the snapshot](#take-the-snapshot-macos-vm).

### iPhone, iPad and Apple TV

These devices have no snapshot. Their clean state is the result of the [removal procedure](RECOVERY.md#remove-wardaxis). When that procedure does not give a clean state, erase the device:

- iPhone, iPad: Settings → General → Transfer or Reset → **Erase All Content and Settings**. The iPad then needs [supervision](#supervise-the-ipad) again.
- Apple TV: Settings → System → Reset → **Reset**.

## Results log

Add one row per run. Never delete a row: a failure is a result too.

| Date | Device | Build | Step | Result |
|---|---|---|---|---|
| 2026-11-26 | MacBook Air (development Mac), macOS 27.2.1 | Debug (`7ccb9b4` plus the uncommitted state display) | Activate, approve, deactivate, from `/Applications` | Pass, outside the VM procedure. First runs: `unsupportedParentBundleLocation` when run from Xcode; then the status stayed on approval because only the URL filter switch was on. After turning on **Network Extension** under WardAxis Extensions, the app showed **Enabled** and **Activated**. Deactivation: the Network Extension switch turned off, and `systemextensionsctl list` shows the only copy as `[terminated waiting to uninstall on reboot]` |
| 2026-11-26 | macOS VM, `VirtualMac2,1`, macOS 27.2.1, SIP on | Debug (`7ccb9b4` plus the uncommitted state display) | Activate, approve, deactivate, from `/Applications` | Pass. Activate: macOS prompt, then **Open System Settings** → **Network Extension** on; `systemextensionsctl list` shows `[activated enabled]`, no provider process runs, and no configuration is saved. Deactivate: the only copy shows `[terminated waiting to uninstall on reboot]`. Before the run, the new VM was registered in the Developer portal and Xcode's cached development profiles were refreshed |
| 2026-11-26 | iPhone 16 Pro, iOS 27.2.1, unsupervised | Debug (`3106424` plus uncommitted edits to `RootView` and `AlertPresenter`) | Install and launch over USB with `devicectl` | Pass: installed, launched and still running. Settings not yet opened by hand |
| 2026-11-26 | iPad mini (A17 Pro) | — | Supervise with Apple Configurator | Pass after a retry. The first Prepare failed: "Add to Apple School Manager or Apple Business" was on, and the iPad was already set up. Erased and prepared again. About shows "supervised and managed by Agnidia Lab" |
| 2026-11-26 | iPad mini (A17 Pro), iPadOS 27.2.1, unsupervised | Debug (`3106424`) | Install and launch over USB with `devicectl` | Pass: installed, launched and still running. Settings not yet opened by hand |
| 2026-11-26 | iPad mini (A17 Pro), iPadOS 27.2.1, supervised | Debug (`3106424`) | Pair again, turn on Developer Mode, install and launch over USB with `devicectl` | Pass: installed, launched and still running. Settings not yet opened by hand |
| 2026-11-26 | Apple TV 4K (2nd generation), tvOS 27.2.1 | Debug (working tree, installed from Xcode) | Install and launch | Fail: launches, but shows string keys such as `main.tab.home`. Cause: the Ukrainian table translated 11 of 86 keys, and the OS does not fall back to English per key |
| 2026-11-26 | Apple TV 4K (2nd generation), tvOS 27.2.1 | Debug (working tree, complete Ukrainian catalog) | Install and launch | Pass: localized text on every screen checked by the tester |
| 2026-11-26 | MacBook Air (development Mac), macOS 27.2.1 | Debug (`e0ff997`), run from the build folder | Recovery test: truncated, oversize, unknown-schema and stale cache files ([RECOVERY.md](RECOVERY.md#recovery-test)) | Pass: at each launch the app deleted the file and kept running. Leftovers of earlier installs found: the `com.agnidia.wardaxis`, `.safari`, `.mail` and `.lab.mail` containers, the App Group container, and the NetworkFilter row `[terminated waiting to uninstall on reboot]` |
