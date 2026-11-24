# Server

The Server is the WardAxis management back end. It uses Hummingbird 2 for HTTP and PostgresNIO for the database. The stack and its pins are recorded in [ADR 0001: Swift server stack](../docs/adr/0001-swift-server-stack.md).

The server serves `GET /v1/health`, the live configuration feed for enrolled agents at `GET /v1/config/stream` and, in development, an [API reference](#api-reference) at `GET /v1/docs`. Agents authenticate with a TLS client certificate issued by the device CA (mutual TLS). Administrator authentication is a separate surface and is not built yet.

## Prerequisites

| Tool | Version | Used for |
|---|---|---|
| Docker Engine with Compose v2 | Current | Running PostgreSQL 18 and the server |
| Swift toolchain | 6.4 | `swift test` in `Server/` |

## Run the stack

From the repository root:

```bash
docker compose -f Server/compose.yaml up -d --build
```

The stack starts two services. `postgres` runs `postgres:18`. `server` waits for a healthy `postgres`, then runs its migrations and starts.

Check the server:

```bash
curl -i http://127.0.0.1:8080/v1/health
```

Response shape with a reachable database (from `HealthStatus`; this stage did not start the stack):

```text
HTTP/1.1 200 OK
content-type: application/json; charset=utf-8

{"status":"ok","database":"ok"}
```

## Configuration

The server reads these variables from its environment. Compose sets the values for the container.

| Variable | Default | Required | Purpose |
|---|---|---|---|
| `HOST` | `0.0.0.0` | No | Address the server binds to |
| `PORT` | `8080` | No | Port the server binds to; must be 1 to 65535 |
| `DATABASE_URL` | None | Yes | `postgres://user:password@host:port/database?sslmode=mode` |
| `SERVER_ENVIRONMENT` | `production` | No | `development` or `production`; any other value fails start-up |
| `LOG_LEVEL` | `info` | No | One of `trace`, `debug`, `info`, `notice`, `warning`, `error`, `critical` |
| `API_DOCS_ENABLED` | `true` in `development`, `false` in `production` | No | `true` or `false` only; serves the [API reference](#api-reference) |
| `TLS_CERTIFICATE_CHAIN_PATH` | None | In `production` | Path to the PEM certificate chain the listener serves, leaf first |
| `TLS_PRIVATE_KEY_PATH` | None | In `production` | Path to the unencrypted PEM private key of that leaf |
| `TLS_CLIENT_CA_PATH` | None | For the config feed | Path to the PEM device CA bundle (one or more CA certificates). Every client certificate must chain to it. Without it the config feed is not served |

TLS rules, checked at start-up:

| Case | Result |
|---|---|
| Both TLS paths set | The listener serves TLS 1.2 or later only, with forward-secret AEAD suites, in any environment |
| Both TLS paths and `TLS_CLIENT_CA_PATH` set | Every TLS handshake must present a client certificate that chains to the device CA. A client without one, or with one from another CA, fails the handshake. No host name is checked: a device certificate names a device, not a host |
| `TLS_CLIENT_CA_PATH` set without both TLS paths | Start-up fails (`TLS_CLIENT_CA_PATH`): client certificates exist only inside TLS |
| One TLS path set | Start-up fails and names the missing variable |
| Neither set, `SERVER_ENVIRONMENT` unset or `production` | Start-up fails; production has no plain-HTTP option |
| Neither set, `SERVER_ENVIRONMENT=development` | Plain HTTP, as compose runs it on `127.0.0.1`. The config feed is not served |
| A file is unreadable, not PEM, or the key does not match the chain | Start-up fails before the listener binds; the error names the variable, never the path or the file's bytes |

With `TLS_CLIENT_CA_PATH` set, the client certificate is required on every route of the listener, `GET /v1/health` included. The image and compose healthchecks then present the probe identity in `HEALTHCHECK_CLIENT_CERTIFICATE_PATH` and `HEALTHCHECK_CLIENT_KEY_PATH` (read by the probe shell only, never by the server). Issue that identity from the device CA. Without it the container reports unhealthy, which fails closed.

Keep the certificate, key and CA files out of the repository and the image. Evidence: `ConfigurationTests`, `TLSListenerTests` and `ConfigStreamMutualTLSTests`.

`SERVER_ENVIRONMENT` defaults to `production`, so a deployment that omits it gets the strict checks. Set `development` only on a developer machine.

`DATABASE_URL` takes the `sslmode` query item. Its values and defaults:

| `sslmode` | Behaviour | Use |
|---|---|---|
| absent | Same as `require` | Default. Fails closed |
| `require` | TLS, with certificate chain and host name check | Any shared or remote database |
| `prefer` | TLS when offered, plain text otherwise | Not recommended; an on-path attacker can force plain text |
| `disable` | No TLS | Local or CI database only |

Compose sets `sslmode=disable` because the bundled `postgres:18` service has no TLS. Compose also reads these variables from a git-ignored file named `.env` next to `compose.yaml`. Copy the example file to that name to change them.

| Compose variable | Default | Purpose |
|---|---|---|
| `POSTGRES_USER` | `wardaxis` | Database user |
| `POSTGRES_PASSWORD` | `local-dev-not-a-secret` | Database password; use URL-safe characters only |
| `POSTGRES_DB` | `wardaxis` | Database name |
| `POSTGRES_PORT` | `5432` | Host port for PostgreSQL |
| `SERVER_PORT` | `8080` | Host port for the server |
| `LOG_LEVEL` | `info` | Server log level |
| `SERVER_ENVIRONMENT` | `development` | Allows plain HTTP on `127.0.0.1` |
| `API_DOCS_ENABLED` | Empty (the server default: on in `development`) | `true` or `false`; empty keeps the server default |
| `COMPOSE_PROJECT_NAME` | `wardaxis` | Compose project name; with `POSTGRES_PORT` and `SERVER_PORT` it runs a second stack beside the first |

The compose defaults are local-only development values. Do not use them outside a developer machine. Compose runs plain HTTP, so the config feed is off in the compose stack; the server logs one `notice` at start-up that says so. The server never prints a `DATABASE_URL` password or a TLS path. Errors name the variable only.

## API reference

The server can serve its own API reference. The routes are hand-written and are not part of the contract. Only `GET` is served; `HEAD` is not.

| Route | Content type | Body |
|---|---|---|
| `GET /v1/docs` | `text/html; charset=utf-8` | A Redoc page that loads the contract |
| `GET /v1/openapi.yaml` | `application/yaml` | The exact contract the server was built from, byte for byte |
| `GET /v1/docs/redoc/2.5.4/redoc.standalone.js` | `text/javascript; charset=utf-8` | The vendored Redoc script (about 1.1 MB), cached as immutable |

The script path holds the Redoc version, so an upgrade changes the URL and browsers fetch the new script.

With the compose stack up, open the reference in a browser:

```text
http://127.0.0.1:8080/v1/docs
```

### Switch

`API_DOCS_ENABLED` turns the three routes on or off together.

| Value | Result |
|---|---|
| `true` | The routes are served |
| `false` | `/v1/docs`, `/v1/openapi.yaml` and the script path answer `404` |
| Unset or empty | `true` in `development`, `false` in `production` |
| Anything else (`1`, `yes`, `TRUE`) | Start-up fails and names the variable |

### Security

| Control | Detail |
|---|---|
| Content Security Policy on `/v1/docs` | `default-src 'self'`, `script-src 'self'`, `object-src 'none'`, `frame-ancestors 'none'`; no remote origin and no string evaluation is allowed |
| Relaxed on purpose | `style-src` allows inline styles, `worker-src` allows `blob:` and `img-src` allows `data:`, because Redoc needs them |
| Other headers | `X-Content-Type-Options: nosniff` on all three routes; `Referrer-Policy: no-referrer` on `/v1/docs` |
| Redoc footer logo | Redoc loads it from `cdn.redoc.ly`. The policy blocks it on purpose, and Redoc hides the logo when the load fails. The browser console shows a CSP report for it |

The full policy is `DocsController.contentSecurityPolicy`.

Production: the docs routes are never mounted in production, so the reference is not served there. `API_DOCS_ENABLED=true` with `SERVER_ENVIRONMENT=production`, or with `SERVER_ENVIRONMENT` unset (which means production), makes start-up fail. The refusal keeps an unauthenticated 1.1 MB page off the public internet by mistake.

### Updating Redoc

Redoc is vendored. Nothing is downloaded at build or run time. The files are in `Server/Sources/ServerCore/Resources/APIDocs/`: `redoc.standalone.js`, its two licence files, `PROVENANCE.md`, and `openapi.yaml` (a symlink to the contract). The shipped version is `2.5.4`.

To upgrade, follow `PROVENANCE.md` and change these together:

| Item | Where |
|---|---|
| Version | `PROVENANCE.md` and `DocsController.redocVersion` (it sets the versioned script path) |
| npm `dist.integrity` of the tarball | `PROVENANCE.md` |
| SHA-256 of `redoc.standalone.js` | `PROVENANCE.md` |

Check the integrity of the tarball before you extract it. A version that differs between `PROVENANCE.md` and `redocVersion` is a defect.

## Network exposure

Compose publishes both ports on `127.0.0.1` only. Other hosts on the network cannot reach them.

Check the published bindings:

```bash
docker compose -f Server/compose.yaml config | grep host_ip
```

Output of this command in DC0 (both ports bind to loopback in the compose file; line `Server/compose.yaml:18` and `:48`):

```text
        host_ip: 127.0.0.1
        host_ip: 127.0.0.1
```

That command checks the configuration, not a running stack. QA0 did not probe a live stack. To check the real binding after `up`, run `lsof -iTCP:8080 -sTCP:LISTEN`; the local address must show `127.0.0.1:8080` (Docker Desktop may show its own proxy process).


## HTTP behaviour

The image `HEALTHCHECK` and the compose server healthcheck both probe `GET /v1/health` on `127.0.0.1`, so a container reports healthy only when that route answers.

| Behaviour | Detail |
|---|---|
| `GET /v1/health` | `200` with `{"status":"ok","database":"ok"}` when the database answers |
| `GET /v1/health` | `503` with `{"status":"unavailable","database":"unreachable"}` otherwise |
| Error bodies | Every 4xx and 5xx response from the router has an `ErrorResponse` body with `code`, `message` and `requestId`; no body holds an error's type, text, SQL or stack trace |
| Body limit | Bodies over 64 KiB (65,536 bytes) answer `413 Content Too Large` |
| Request ID | Every response carries `X-Request-ID`; an inbound value is kept only when it matches `[A-Za-z0-9._-]` and is 128 characters or fewer, otherwise the server generates one |

The request ID also appears in every log line for that request. A client can therefore quote it when it reports a problem.

## Config stream

`GET /v1/config/stream` is a WebSocket (RFC 6455) that carries the contract's `ConfigMessage` frames, one JSON object per text frame. The contract declares its security as `mutualTLS`.

Trust boundary: the TLS handshake. The route is registered only when the listener requires client certificates (`TLS_CLIENT_CA_PATH` set). Authorization is "holds a certificate issued by the device CA"; the feed is global configuration, so every such device may read it. Per-device authorization arrives with the Phase 5 device API. The server reads no identity from any header: `Authorization`, forwarded-certificate and device-ID headers are ignored. As a second gate, the route refuses (`500`, no upgrade) a connection whose channel holds no verified client certificate, so a composition error cannot serve the feed unauthenticated.

| Step | Behaviour |
|---|---|
| Handshake | The client presents its device certificate. No `Authorization` header is needed or read |
| First frame | `ConfigSnapshot` with the current version and every entry |
| Changes | One `ConfigDelta` per committed change, version + 1 each time, to every open stream |
| Keep-alive | `ConfigHeartbeat` with the stream's current version every 30 s, and a WebSocket ping every 45 s |

How the server refuses or ends a stream:

| Case | Client sees |
|---|---|
| No client certificate, or one that does not chain to the device CA | The TLS handshake fails; no HTTP exchange happens |
| Server without `TLS_CLIENT_CA_PATH` | No route: `404 not_found` on a plain `GET`, `400` with an empty body on a WebSocket handshake |
| Plain `GET` without `Upgrade: websocket` | `400 invalid_request` |
| Stream open for its lifetime: 15 min, less a random 0 to 3 min per stream | Close code `1000` with reason `lifetime`. Reconnect at once (a short random delay is enough) with a new TLS handshake |
| More than 5 open streams for one client certificate, in this server process | Upgrade, then close code `1013` (Try Again Later) before any frame. Reconnect with backoff |
| Stream opened right after start-up, while the change relay has not read its start version | The stream waits up to 10 s, then gets close code `1013` before any frame if the relay is still not running |
| No pong for 90 s | Close code `1001` |
| The server cannot read the configuration, or its change log has a gap | Close code `1011`; reconnect for a new snapshot |

The lifetime cap exists because the certificate is checked only in the handshake. It bounds how long a certificate that the server stops trusting (a rotated device CA bundle) keeps a stream. The server does not check certificate revocation (CRL or OCSP) yet; when it does, the same cap bounds how long a revoked certificate keeps the feed.

The per-certificate cap keys on the DER bytes of the verified leaf certificate. It is a slot key only: the server reads no name or serial from it.

### Changing the configuration

Configuration lives in PostgreSQL table `config_entries` (`key text`, `value jsonb`), created by migration 2. There is no write API: change it with SQL. Triggers give every SQL statement that changes something one new version, log the change in `config_changes` and notify the server.

| Rule | Reason |
|---|---|
| One statement is one version. A transaction with several statements gets several versions; `INSERT … ON CONFLICT DO UPDATE` can produce two | The triggers run once per statement |
| Start a multi-statement change with `SELECT 1 FROM config_version FOR UPDATE` | Takes the version lock first, so two admin transactions cannot deadlock |
| Use `DELETE`, never `TRUNCATE config_entries` | `TRUNCATE` fires no change trigger; the database refuses it |
| Do not set `session_replication_role = replica` for a change | It skips the triggers, so the change gets no version |

Example:

```sql
INSERT INTO config_entries (key, value) VALUES ('theme', '"dark"'), ('maxItems', '20')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
```

The server listens on the `config_changes` channel with one pooled connection and also polls the change log every 30 s, so a lost notification delays a change by at most 30 s. `LISTEN` does not work through a transaction-pooling proxy (PgBouncer in transaction mode); connect the server directly or in session mode. `config_changes` keeps every change; nothing prunes it yet.


## Migrations

The server applies every migration in `Server/Sources/ServerCore/Database/Migrations/` on start, in version order. Each migration and its `schema_migrations` row commit in one transaction.

| Version | Name | Content |
|---|---|---|
| 1 | `baseline` | No statements; marks the schema epoch |
| 2 | `create_configuration` | `config_entries`, `config_version`, `config_changes` and their triggers |

`Migrations.all` is append-only. Add a new migration with the next version. Never edit, renumber or remove a shipped migration. The runner reports a changed or missing migration as drift; `runService()` then ends with that error and the process exits with status 1.

A database created by an earlier development build holds versions this server does not know, so start-up fails with `databaseAhead` or `drift`. Recreate it (for compose: `docker compose -f Server/compose.yaml down -v`).

Start-up also fails in these cases:

| Case | Error |
|---|---|
| Versions in `Migrations.all` are not 1, 2, 3, … with no gap | `invalidOrder` |
| The database has a version the server does not know | `databaseAhead` |
| A pending migration has a lower version than one the database already applied | `pendingBelowApplied` |

## Tests

Run the unit suites from `Server/`:

```bash
cd Server && swift test
```

The TLS and config stream suites mint a throwaway CA, server and client certificates per run in a private temporary directory, and delete them. The PostgreSQL suites run only when `TEST_DATABASE_URL` is set:

```bash
TEST_DATABASE_URL="postgres://wardaxis:local-dev-not-a-secret@127.0.0.1:5432/wardaxis_test?sslmode=disable" swift test
```

| Warning | Action |
|---|---|
| The database suites drop `schema_migrations` and every server table, and empty the configuration tables | Point `TEST_DATABASE_URL` at a disposable database |
| Never point it at the database that holds data | Create a separate database for tests before the run |
