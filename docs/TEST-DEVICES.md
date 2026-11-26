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
| System extension test VM | macOS VM on the MacBook Air | TBD | TBD | TBD | — |
| Unsupervised iOS device | iPhone 16 Pro | `iPhone17,1` | iOS 27.2.1 | 24B156 | No |
| Supervised iOS device (planned) | iPad mini (A17 Pro) | `iPad16,1` | iPadOS 27.2.1 | 24B156 | No, see [Supervise the iPad](#supervise-the-ipad) |
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

1. Create a macOS VM on the MacBook Air with a Virtualization.framework host, for example UTM. Install macOS 26 or later.
2. Finish the setup with a local test account. Keep SIP on.
3. In the VM, read the provisioning UDID with `system_profiler SPHardwareDataType | grep "Provisioning UDID"`. Register it in the Apple Developer portal under Devices as a Mac. Do not record it anywhere else.
4. On the MacBook Air, build the `WardAxis` scheme once in Xcode with automatic signing. Xcode then regenerates the development profiles with the VM included.
5. Take a snapshot named `clean` and update the VM row of the [inventory](#inventory).

## System extension approval (macOS VM)

Prerequisite: the App IDs `com.agnidia.wardaxis` and `com.agnidia.wardaxis.networkfilter` are registered with the Network Extensions capability (see [GETTING-STARTED.md](GETTING-STARTED.md)).

1. On the MacBook Air, build the `WardAxis` scheme in the Debug configuration for macOS.
2. Copy `WardAxis.app` from the build products into `/Applications` in the VM, for example through a shared folder. The OS activates extensions only for an app in `/Applications`.
3. Start a log stream in the VM: `log stream --predicate 'subsystem == "com.apple.sx"' --level info`.
4. Open WardAxis → Settings → Developer, and select **Activate network filter**. The status reads "Allow the extension in System Settings…".
5. Open System Settings → General → Login Items & Extensions → Network Extensions, and allow WardAxis. The status changes to **Activated**.
6. Run `systemextensionsctl list`. The `com.agnidia.wardaxis.networkfilter` row shows `[activated enabled]`.
7. Open System Settings → Network → Filters. It lists no WardAxis filter, because activation saves no configuration (ADR 0006 D3).
8. Select **Deactivate network filter**. The status changes to **Deactivated**, and `systemextensionsctl list` no longer shows the row as `[activated enabled]`. The OS can show it as waiting to uninstall until the next restart.
9. Record the result in the [results log](#results-log) and revert the VM to the `clean` snapshot.

| Status shown | Cause | Fix |
|---|---|---|
| Failed: `unsupportedParentBundleLocation` | The app runs from the build folder | Copy it to `/Applications` |
| Failed: `missingEntitlement` | The profile has no Network Extensions or System Extension capability | Register the capabilities on both App IDs and rebuild |
| Failed: `codeSignatureInvalid` | The bundle changed after signing | Copy the app again from a fresh build |
| Failed: `invalidIdentifier` | `WANetworkFilterBundleIdentifier` is not `<app ID>.<segment>` | Check `NETWORK_FILTER_BUNDLE_ID` in `Configurations/base.xcconfig` |
| Failed: `forbiddenBySystemPolicy` | A configuration profile blocks the extension | Remove the profile, or revert the snapshot |
| Stays on "Allow the extension…" | The user has not approved it | Approve it in System Settings; the pending request then completes |

## Supervise the iPad

Supervision erases the iPad. Back it up first.

1. Install Apple Configurator from the Mac App Store on the MacBook Air.
2. Connect the iPad by USB and unlock it.
3. Select the iPad → Prepare → Manual Configuration. Select **Supervise devices** and **Allow devices to pair with other computers**, so that Xcode can still install builds.
4. Do not enroll in an MDM server. Enrollment is MDM-011 (Phase 5).
5. Create a supervising organization named `Agnidia Lab`. Configurator creates a supervision identity, which is a certificate and private key. Keep it in the MacBook Air keychain and export a backup to an encrypted store. Never put it in the repository.
6. Finish Prepare. The iPad is erased and restarts.
7. Check the result: the top of Settings → General → About reads "This iPad is supervised and managed by Agnidia Lab". Update the [inventory](#inventory).

## Install a test build on iPhone, iPad and Apple TV

1. **iPhone and iPad:** connect the device and trust the Mac. Turn on Settings → Privacy & Security → Developer Mode and restart.
2. **Apple TV:** on the Apple TV, open Settings → Remotes and Devices → Remote App and Devices. Pair it in Xcode → Window → Devices and Simulators.
3. Run the `WardAxis` scheme in Debug on each device from Xcode.
4. Check that the app launches and that Settings opens. The Developer section is macOS-only, so it does not appear.
5. Record the result in the [results log](#results-log).

The iOS and tvOS shells cannot be activated yet. The packet tunnel and the URL filter need a saved configuration, and that arrives in Phase 1. Enrollment behavior on iPad and Apple TV is tested with MDM in Phase 5 (MDM-011, MDM-012).

## Results log

Add one row per run. Never delete a row: a failure is a result too.

| Date | Device | Build | Step | Result |
|---|---|---|---|---|
| TBD | macOS VM | Debug | Activate, approve, deactivate | TBD |
| TBD | iPhone 16 Pro | Debug | Install and launch | TBD |
| TBD | iPad mini (A17 Pro) | — | Supervise with Apple Configurator | TBD |
| TBD | iPad mini (A17 Pro) | Debug | Install and launch | TBD |
| TBD | Apple TV 4K (2nd generation) | Debug | Install and launch | TBD |
