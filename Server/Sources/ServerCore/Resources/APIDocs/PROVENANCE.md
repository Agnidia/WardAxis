# Provenance of the API reference assets

The server serves these files at `GET /v1/docs` and on the asset path. They are not
downloaded at build or run time; the copies in this directory are the ones that ship.

## Redoc

| Field | Value |
|---|---|
| Package | `redoc` (npm) |
| Version | `2.5.4` |
| Tarball | `https://registry.npmjs.org/redoc/-/redoc-2.5.4.tgz` |
| npm `dist.integrity` of the tarball | `sha512-M6jWhG1qoBnH6TFmzJnstyCZ87HmOY/UzDm78mHiYihEdlV/YcS9ogOo1NlElnJMeLsyxHFe2yFc4sNjHTrABQ==` |
| File taken from the tarball | `package/bundles/redoc.standalone.js` |
| SHA-256 of `redoc.standalone.js` | `dcaf76612bc4a3fbcc923a8966dee2f6146a5f32e5ce1b6f02dd60cbbf89500b` |
| Licence | MIT, `redoc-LICENSE.txt` (from `package/LICENSE`) |
| Bundled third-party notices | `redoc.standalone.js.LICENSE.txt` (from `package/bundles/`) |
| Vendored on | 2026-10-14 |

The integrity value was checked against the downloaded tarball before extraction:

```bash
openssl dgst -sha512 -binary redoc-2.5.4.tgz | base64
```

Only the three files above were copied. Nothing from the tarball was executed.

To check the vendored copy:

```bash
shasum -a 256 Server/Sources/ServerCore/Resources/APIDocs/redoc.standalone.js
```

## Bundled components

`redoc.standalone.js` contains these libraries. No lockfile lists them, so no
dependency scanner sees them.

| Component | Version | How it was identified |
|---|---|---|
| DOMPurify | `3.4.13` | Banner in `redoc.standalone.js.LICENSE.txt` |
| js-yaml | `4.3.0` or `4.3.1` | Code fingerprint: `maxTotalMergeKeys` is present, and `mergeMappings` lacks the 4.3.2 `chargeMergeWork` call |
| React | `18.3.1` | Security review SR-L1 |
| styled-components | `5.3.11` | Security review SR-L1 |
| Prism | `>=1.30` | Security review SR-L1 |
| marked | `^4.3.0` | Security review SR-L1 |
| perfect-scrollbar | `1.5.3` | Security review SR-L1 |
| mark.js | `8.11.1` | Security review SR-L1 |

The Ajv version cannot be identified.

## Advisories reviewed (2026-10-14)

| Component | Advisory | Severity | Fixed in | Reachable? |
|---|---|---|---|---|
| DOMPurify | GHSA-p98j-92pf-mc4p / CVE-2026-109344 | LOW (CWE-79) | `3.4.16` | No. It applies to `IN_PLACE` mode only. Redoc never sets it. |
| DOMPurify | GHSA-6688-9rhm-gjv2 / CVE-2026-109345 | LOW (CWE-79) | `3.4.16` | No. It applies to `IN_PLACE` mode only. Redoc never sets it. |
| js-yaml | GHSA-2883-xcg3-v3hh / CVE-2026-84375 | HIGH upstream (CPU DoS from empty merge sources) | `4.3.2` | Not from outside. js-yaml parses only the first-party `/v1/openapi.yaml`. |
| js-yaml | GHSA-5p4m-2wfm-xmqj (`!!omap`), possible | Not recorded | `4.3.1` | Not from outside. Same reason. |

Decision: accepted for Redoc 2.5.4 (user decision, 2026-10-14). Docs are never
served in production. The move to Redoc 3.x (candidate 3.0.1) is tracked in a
follow-up issue. Check OSV again on each Redoc release.

## Upgrading

1. Pick an exact `2.x.y` version on `registry.npmjs.org/redoc`.
2. Download the tarball into a new empty directory. Compare the sha512 with the
   registry's `dist.integrity` before you extract it.
3. Replace the three files, update this record, and set `DocsController.redocVersion`
   to the new version. The asset path contains the version, so browsers fetch the new
   script instead of a cached one.

## openapi.yaml

`openapi.yaml` here is a symlink to
`Packages/WardAxisManagementAPI/Sources/WardAxisAPIServer/openapi.yaml`. The build embeds the
target's bytes, so `GET /v1/openapi.yaml` always serves the contract the server was built
from.
