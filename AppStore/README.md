# App Store listing

The App Store listing for WardAxis, in the layout the
[App Store Connect CLI (`asc`)](https://github.com/rorkai/App-Store-Connect-CLI) reads and writes.
Credentials and the private publishing guide are outside this repo, in
`/Users/korich/Projects/igrsoft/AppStore/` (see its `README.md`). Never copy the `.p8` key into this repo.

| Path | Content | Managed with |
|---|---|---|
| `metadata/app-info/<locale>.json` | Name, subtitle, privacy policy URL | `asc metadata` |
| `metadata/version/<version>/<locale>.json` | Description, keywords, promotional text, support and marketing URLs; shared by macOS, iOS and tvOS, no `whatsNew` key | `asc metadata` |
| `whats-new/<macos\|ios\|tvos>/<version>/<locale>.txt` | Release notes per platform, from the first update after 1.0.0 | `asc localizations update` |
| `screenshots/<locale>/<device type>/` | Screenshots per locale and device, uploaded in file-name order | `asc screenshots` |
| `changelog.md` | Release history | by hand |

Locales: `en-US`, `uk`. App ID: `6839274307`. Bundle ID: `com.agnidia.wardaxis`. SKU: `WARDAXIS`.

The record lives in the App Store Connect account of team `DMP42GVPJ3` until the Agnidia organization enrollment
(ORG-001, #192) moves it by App Transfer ([ADR 0002](../docs/adr/0002-app-store-signing-identifiers.md)).
It was created with the `MAC_OS` platform. Add `IOS` and `TV_OS` to the same record (App Store Connect → the app →
Add Platform): one record for all three platforms gives Universal Purchase (ADR 0002 D2).

## Open before the first submission

| Item | State |
|---|---|
| App icon | `Resources/Assets.xcassets/AppIcon.appiconset` has no images. App Store validation fails (ITMS 90236) |
| Safari extension icons | `Extensions/SafariWebExtension/Resources/manifest.json` has no `icons` field. App Store validation fails |
| Privacy policy, terms, portfolio pages | `policy.html` and `terms.html` are drafted in the site repo (`public/info/app/wardaxis/`, branch `feature/wardaxis-legal-pages`); deploy them before submission. The portfolio page `agnidia.com/portfolio/wardaxis` needs the app icon and screenshots first |
| Description | Describes the 1.0 scope of the [roadmap](../roadmap/README.md). The listing must match what the build does (Guideline 2.3); trim it to the shipped features before submission |
| Ukrainian keywords | 85 characters, 139 bytes. If App Store Connect rejects them as too long, shorten them to 100 bytes |
| Screenshots | None yet; the app has no final UI |

## Character limits

| Field | Limit |
|---|---|
| Name, subtitle | 30 |
| Promotional text | 170 |
| Keywords | 100, comma-separated; do not repeat the app name |
| Description, What's New | 4000 |

Run `asc metadata validate --dir AppStore/metadata` after every edit; it checks limits, required fields and URLs.

## Screenshots

| Platform | Device type | Size (PNG, no alpha) |
|---|---|---|
| macOS | `APP_DESKTOP` | 2880×1800 |
| iPhone | `APP_IPHONE_69` | 1320×2868 |
| iPad | `APP_IPAD_PRO_3GEN_129` | 2048×2732 |
| Apple TV | `APP_APPLE_TV` | 3840×2160 |

Keep window content free of personal data and real matched content: use synthetic secrets and demo policies only.
For Mac slides, the shared backdrop and compositing steps are in the private publishing guide.

Check every slide with `sips -g pixelWidth -g pixelHeight -g hasAlpha`, then with `asc screenshots validate`.

## Publish a new version

From the repo root, with `<v>` the marketing version (for example `1.0.0`), `<P>` the platform (`MAC_OS`, `IOS` or
`TV_OS`) and `<p>` its folder name (`macos`, `ios` or `tvos`). Run the steps once per platform that ships in this
release.

1. Create the version in App Store Connect if it does not exist:
   `asc versions create --app 6839274307 --version <v> --platform <P>`
2. Pull into a temporary directory, never into `AppStore/metadata`, so the live What's New of one platform cannot
   overwrite the shared files:
   `asc metadata pull --app 6839274307 --version <v> --platform <P> --dir "$TMPDIR/asc-pull"`
3. Validate, then review what would change:
   ```
   asc metadata validate --dir AppStore/metadata
   asc metadata plan --app 6839274307 --version <v> --platform <P> --dir AppStore/metadata
   ```
4. Apply after review, then set the platform's release notes (not for the first version of a platform):
   ```
   asc metadata apply --app 6839274307 --version <v> --platform <P> --dir AppStore/metadata --confirm
   asc localizations update --app 6839274307 --version <v> --platform <P> --locale en-US --whats-new @file:AppStore/whats-new/<p>/<v>/en-US.txt
   asc localizations update --app 6839274307 --version <v> --platform <P> --locale uk --whats-new @file:AppStore/whats-new/<p>/<v>/uk.txt
   ```
5. Screenshots, one locale and device type at a time, with `--path` on that folder:
   ```
   asc screenshots validate --path AppStore/screenshots/en-US/APP_DESKTOP --device-type APP_DESKTOP
   asc screenshots upload --app 6839274307 --version <v> --platform MAC_OS --locale en-US --path AppStore/screenshots/en-US/APP_DESKTOP --device-type APP_DESKTOP --replace --confirm
   ```
6. Build, check and upload. The archive gate is in [AGENTS.md](../AGENTS.md#signing): never upload an archive that
   fails `scripts/verify-entitlements.py`.
   ```
   xcodebuild -project WardAxis.xcodeproj -scheme WardAxis -configuration Release \
     -destination 'generic/platform=macOS' -archivePath build/WardAxis-macOS.xcarchive \
     -skipPackagePluginValidation -onlyUsePackageVersionsFromResolvedFile archive
   python3 -I scripts/verify-entitlements.py build/WardAxis-macOS.xcarchive
   xcodebuild -exportArchive -archivePath build/WardAxis-macOS.xcarchive \
     -exportOptionsPlist Configurations/export/app-store.plist -exportPath build/export-macOS
   xcrun altool --validate-app -f build/export-macOS/WardAxis.pkg -t macos \
     --apiKey <KEY_ID> --apiIssuer <ISSUER_ID> --p8-file-path <path to .p8>
   asc builds upload --app 6839274307 --pkg build/export-macOS/WardAxis.pkg --version <v> --build-number <build>
   ```
   Use `generic/platform=iOS` or `tvOS` and `--ipa` for the other platforms.
7. Check readiness, attach the build and submit:
   ```
   asc status --app 6839274307
   asc validate --app 6839274307 --version-id <VERSION_ID>
   asc review submit --app 6839274307 --version <v> --build-number <build> --platform <P> --confirm
   ```

The build number must match `CURRENT_PROJECT_VERSION` in `Configurations/base.xcconfig`.

## Privacy label

The label is **Data Not Collected**. Classification runs on the device, matched content never leaves it, and
`Resources/PrivacyInfo.xcprivacy` declares no collected data types and no tracking. Diagnostics telemetry is opt-in
(`TelemetryService` drops every event without consent) and contains no matched content. When telemetry gains a
remote sink, or the management agent reports device data to a server that Agnidia operates, update the label, the
privacy manifests and the hosted policy together. Read the live label with `asc web privacy pull --app 6839274307`.

## App Review notes

Draft; complete it with the features of the submitted build. Paste it into the review notes of each platform version:

> WardAxis is a network and AI data protection app. No account or sign-in is needed.
> On the Mac, the app embeds three NetworkExtension system extensions (content filter, transparent proxy, DNS
> proxy), a URL filter app extension, a Safari Web Extension, a Mail extension and a sandboxed login item. Each
> protection starts only after the user turns it on and approves it in System Settings; the login item starts only
> after explicit opt-in. On iPhone and iPad, the app uses a URL filter and a packet tunnel; on Apple TV, a packet
> tunnel. The Safari extension requests access only to the AI and policy sites the user registers. Classification
> runs on the device; matched content never leaves it.
