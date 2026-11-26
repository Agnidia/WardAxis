# Privacy

This file is the source for the App Privacy label, the privacy manifests, the consent copy and the [privacy policy](privacy/PRIVACY-POLICY.md). Change it first. Then update the manifests, the label in App Store Connect and the hosted policy in the same change. The decisions are recorded in [ADR 0013](adr/0013-privacy-disclosures.md).

Guidelines: 5.1.1 (data collection and consent), 5.1.2 (data use and sharing), 2.5.14 (a visible indication when the app records or monitors activity), 2.4.5(iii) (no launch at login without consent).

## Data inventory

"Collected" has Apple's meaning: the data leaves the device in a way that lets Agnidia or a third party read it for longer than it takes to serve a request in real time.

| Data | Source | Where it stays | Leaves the device | Collected | Reason |
|---|---|---|---|---|---|
| Network flows, DNS queries, URLs | NetworkFilter, TransparentProxy, DNSProxy, URLFilter, PacketTunnel | In memory in the provider; the decision only | No | No | Classification runs on the device. The roadmap requires that no synchronous decision depends on a remote service |
| Web page text that the user sends on a registered AI or policy site | SafariWebExtension | In memory in the extension | No | No | Only the sites that the user or the organization registers. The manifest requests no other host |
| Outgoing mail content | MailExtension | In memory in the extension | No | No | Checked before sending on the device |
| Matched content (the text that a detector matched) | DLP engine (Phase 4) | Never stored and never logged | No | No | `LOGGING.md`: no log contains matched content, credentials or PII |
| Events and decisions (category, action, time; no matched content) | Enforcement components | App Group container, bounded store (planned) | No | No | Local history for the user only |
| Configuration and policy | Management server, when the organization enrolls the device | Configuration cache in the app container | Received, not sent | No | Data that flows to the device is not collected |
| Device client identity (mTLS key and certificate) | Enrollment | Keychain, `AfterFirstUnlockThisDeviceOnly`, not synchronizable | The certificate goes to the organization's server during the TLS handshake | No | The organization that manages the device operates the server. Agnidia receives nothing |
| Diagnostic log | `Log` (`WardAxisTelemetry`) | `Library/Logs/<bundle ID>/log.log` in the app container | Only when the user shares it from Settings | No | A share that the user starts and sends to a recipient of their choice is not collection |
| Usage events (`screenViewed`, `tabSelected`, `actionTapped`) | `TelemetryService` | Debug log only; there is no remote sink | No | No | Opt-in; off by default. The events carry UI element names only |

The tvOS app has a packet tunnel only. It has no Safari or Mail component.

## App Privacy label

**Data Not Collected**, on every platform. Each Apple data type gets the answer "not collected":

| Apple category | Answer | Inventory row |
|---|---|---|
| Contact Info, Health and Fitness, Financial Info, Location, Sensitive Info, Contacts, Purchases, Identifiers | Not collected | No component reads them |
| User Content (emails, other user content) | Not collected | Mail and Safari content stay on the device |
| Browsing History, Search History | Not collected | Flows, DNS and URLs stay on the device |
| Usage Data | Not collected | Telemetry has no remote sink |
| Diagnostics | Not collected | The log leaves only through a share by the user |
| Other Data | Not collected | — |

Tracking: none. No component uses a third-party SDK, an advertising identifier or a tracking domain.

These events change the label, the manifests and the policy together:

- Telemetry gets a remote sink (Usage Data, and possibly Diagnostics: "App Functionality" or "Analytics", not linked).
- Agnidia operates a management server, AI gateway or other service that receives device data.
- A crash reporter or any other third-party SDK is added. Its own privacy manifest then counts too.
- An event store syncs off the device.

Read the live label with `asc web privacy pull --app 6839274307`.

## Privacy manifests

Each bundle carries its own `PrivacyInfo.xcprivacy`. App Store validation reads the manifest of each bundle; the app's manifest does not cover an extension.

| Bundle | Manifest | Tracking | Collected data types | Required-reason APIs |
|---|---|---|---|---|
| WardAxis app (macOS, iOS, tvOS) | `Resources/PrivacyInfo.xcprivacy` | No | None | None |
| NetworkFilter | `Extensions/NetworkFilter/PrivacyInfo.xcprivacy` | No | None | None |
| TransparentProxy | `Extensions/TransparentProxy/PrivacyInfo.xcprivacy` | No | None | None |
| DNSProxy | `Extensions/DNSProxy/PrivacyInfo.xcprivacy` | No | None | None |
| URLFilter | `Extensions/URLFilter/PrivacyInfo.xcprivacy` | No | None | None |
| PacketTunnel | `Extensions/PacketTunnel/PrivacyInfo.xcprivacy` | No | None | None |
| SafariWebExtension | `Extensions/SafariWebExtension/PrivacyInfo.xcprivacy` | No | None | None |
| MailExtension | `Extensions/MailExtension/PrivacyInfo.xcprivacy` | No | None | None |
| Agent | `Services/Agent/PrivacyInfo.xcprivacy` | No | None | None |

The required-reason column comes from a symbol scan of the Release binaries. The local packages link statically into the app binary, so the scan covers them too. Run the scan again when a component gets real logic, or when a package starts to read file timestamps, `UserDefaults`, the system boot time or disk space:

```bash
APP=<path>/WardAxis.app
PAT='_(f|l)?stat(64|at)?$|getattrlist|_f?statv?fs(64)?$|_mach_absolute_time$|NSFileModificationDate|NSFileCreationDate|NSURL(Content)?(Modification|Creation|Access)DateKey|NSURLVolumeAvailableCapacity|NSFileSystem(Free)?Size|NSUserDefaults|UserDefaults|systemUptime|activeInputModes'
find "$APP" -type f -perm -u+x -path '*/MacOS/*' -exec sh -c 'echo "## $1"; nm -u "$1" | grep -E "$2"' _ {} "$PAT" \;
```

On iOS and tvOS, the executables are at the bundle root instead of in `Contents/MacOS`.

Gates:

| Check | Scope |
|---|---|
| `EmbeddedBundlesTests` ("Every bundle carries a privacy manifest that declares no tracking") | The test host and each bundle in its embed folders. The manifest decodes with typed keys and declares no tracking |
| `scripts/verify-entitlements.py` | Every bundle of an archive: the manifest is present, under 64 KiB, a property list, `NSPrivacyTracking` false, no tracking domain, both arrays present |
| App Store Connect validation | The privacy manifest warnings of each bundle in the uploaded build |

## Consent copy

Each protection shows its consent screen before the first system prompt (system extension approval, VPN or filter configuration, Safari or Mail enable, login item). The user can decline and still use the rest of the app. Each component can be turned off again in Settings. The copy names what the component inspects and states what it never sends. The text moves into `Localizable.xcstrings` (keys under `L.Consent`) when its screen ships. Until then, this table is the source.

### Common footer

| | Text |
|---|---|
| EN | WardAxis checks this on your device. Nothing it inspects is sent to Agnidia or anyone else. You can turn this off at any time in Settings. |
| UK | WardAxis перевіряє це на вашому пристрої. Нічого з перевіреного не надсилається Agnidia чи будь-кому іншому. Ви можете вимкнути це будь-коли в Налаштуваннях. |

### Per component

| Component | EN | UK |
|---|---|---|
| Content filter (NetworkFilter, macOS) | **Network content filter.** WardAxis sees the network connections that apps on this Mac open: the app, the destination host and port. It allows or blocks each connection by your policy. It does not read the content of encrypted connections. | **Фільтр мережевого вмісту.** WardAxis бачить мережеві з'єднання, які відкривають програми на цьому Mac: програму, вузол і порт призначення. Він дозволяє або блокує кожне з'єднання за вашою політикою. Він не читає вміст зашифрованих з'єднань. |
| Transparent proxy (TransparentProxy, macOS) | **Transparent proxy.** WardAxis routes the connections that your policy selects through itself, so that it can apply the policy to them. It sees the app, the destination and the amount of data. It does not decrypt the traffic. | **Прозорий проксі.** WardAxis пропускає через себе з'єднання, які вибирає ваша політика, щоб застосувати до них цю політику. Він бачить програму, призначення та обсяг даних. Він не розшифровує трафік. |
| DNS proxy (DNSProxy, macOS) | **DNS protection.** WardAxis sees the domain names that apps on this Mac look up, and it blocks the domains that your policy names. | **Захист DNS.** WardAxis бачить доменні імена, які шукають програми на цьому Mac, і блокує домени, які називає ваша політика. |
| URL filter (URLFilter, macOS, iOS) | **Web address filter.** WardAxis checks the web addresses that this device opens against your block list. The check runs on this device. | **Фільтр вебадрес.** WardAxis перевіряє вебадреси, які відкриває цей пристрій, за вашим списком блокування. Перевірка виконується на цьому пристрої. |
| Packet tunnel (PacketTunnel, iOS, tvOS) | **Network protection.** WardAxis adds a local VPN configuration, so that it can apply your policy to this device's network traffic. The traffic does not go to a WardAxis server, and the VPN icon is shown while it is on. | **Захист мережі.** WardAxis додає локальну конфігурацію VPN, щоб застосувати вашу політику до мережевого трафіку цього пристрою. Трафік не надходить на сервер WardAxis, а значок VPN показується, доки захист увімкнено. |
| Safari extension (SafariWebExtension, macOS, iOS) | **AI data protection in Safari.** On the AI and policy sites that you register, and only there, WardAxis reads the text that you are about to send and warns you or blocks it when it contains sensitive data. It does not read other sites. | **Захист даних для ШІ в Safari.** На зареєстрованих вами сайтах ШІ та політик, і лише там, WardAxis читає текст, який ви збираєтеся надіслати, і попереджає або блокує його, якщо він містить чутливі дані. Інші сайти він не читає. |
| Mail extension (MailExtension, macOS) | **Mail data protection.** Before a message is sent, WardAxis checks its recipients, text and attachments for sensitive data, and warns you. It does not read the messages that you receive. | **Захист даних у Пошті.** Перед надсиланням листа WardAxis перевіряє його адресатів, текст і вкладення на чутливі дані та попереджає вас. Він не читає отримані листи. |
| Login item (Agent, macOS) | **Background agent.** WardAxis starts a small helper at login. It keeps the protections that you turned on and your organization's policy up to date while the app is closed. It shows in System Settings > General > Login Items. | **Фоновий агент.** WardAxis запускає невеликий помічник під час входу. Він підтримує ввімкнений захист і політику вашої організації в актуальному стані, коли програма закрита. Його видно в Системних параметрах > Загальні > Об'єкти входу. |
| Telemetry (app, opt-in) | **Help improve WardAxis.** Share which screens and buttons you use. This never includes web addresses, host names, file names, message text or anything that WardAxis checks. Off unless you turn it on. | **Допоможіть покращити WardAxis.** Діліться тим, якими екранами та кнопками ви користуєтеся. Це ніколи не містить вебадрес, імен вузлів, імен файлів, тексту повідомлень чи будь-чого, що перевіряє WardAxis. Вимкнено, доки ви це не ввімкнете. |
| Organization management (enrollment) | **Managed by your organization.** This device gets its policy from your organization's server. The server sees that this device is enrolled and which policy it uses. It does not see the content that WardAxis checks. | **Керується вашою організацією.** Цей пристрій отримує політику із сервера вашої організації. Сервер бачить, що пристрій зареєстровано, і яку політику він використовує. Він не бачить вмісту, який перевіряє WardAxis. |

The telemetry copy promises a remote sink that does not exist yet. Ship that screen only together with the sink and the label change above. Until then, the Settings toggle stays bound to off (`SettingsView`).

### Visible indication (2.5.14)

Each protection's screen must show, while the protection runs, that it is on in Home and Settings, with the component name and an off switch. No protection runs yet (ADR 0005 D2). The system adds its own indicators: the VPN status icon for the packet tunnel, the System Settings entries for the network extensions and the login item, and the extension list in Safari and Mail.
