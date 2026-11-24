# syntax=docker/dockerfile:1
#
# Build from the repository root, because Server/ depends on Packages/WardAxisManagementAPI by path:
#   docker build -f Server/Dockerfile .
# Server/compose.yaml sets that context for you.

# ---- Build stage ----
FROM swift:6.4-noble AS build
WORKDIR /workspace

# Resolve dependencies in their own layer so a source edit does not refetch them.
COPY Packages/WardAxisManagementAPI ./Packages/WardAxisManagementAPI
COPY Server/Package.swift Server/Package.resolved ./Server/
RUN cd Server && swift package resolve --force-resolved-versions

# The manifest declares the ServerTests target, and SwiftPM rejects a declared target
# without its directory. Only the Server product is built, so tests never reach the image.
COPY Server/Sources ./Server/Sources
COPY Server/Tests ./Server/Tests
RUN cd Server \
    && swift build -c release --product Server --static-swift-stdlib \
    && mkdir /staging \
    && cp "$(swift build -c release --show-bin-path)/Server" /staging/Server \
    && cp -RL "$(swift build -c release --show-bin-path)/Server_ServerCore.resources" /staging/

# ---- Runtime stage ----
FROM ubuntu:noble

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --system --user-group --no-create-home --home-dir /app --shell /usr/sbin/nologin server
WORKDIR /app
COPY --from=build --chown=root:root --chmod=0755 /staging/Server /app/Server
# The Redoc script and its licences; Bundle.module looks for them next to the binary.
# Read-only for the server user, like the binary.
COPY --from=build --chown=root:root --chmod=u=rwX,go=rX /staging/Server_ServerCore.resources /app/Server_ServerCore.resources

USER server:server
EXPOSE 8080

# The probe follows the listener's scheme, because production refuses plain HTTP. It
# skips server certificate checks only on loopback: the certificate names the public
# host, not 127.0.0.1. With TLS_CLIENT_CA_PATH the listener refuses any handshake without
# a device-CA client certificate, so the probe presents the identity in
# HEALTHCHECK_CLIENT_CERTIFICATE_PATH and HEALTHCHECK_CLIENT_KEY_PATH (read by this shell
# only, never by the server); without them the probe fails and the container reports
# unhealthy. --noproxy keeps an inherited proxy variable from sending the probe off the
# host. Server/compose.yaml repeats this command; keep the two the same.
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
    CMD scheme=http; \
    if [ -n "${TLS_CERTIFICATE_CHAIN_PATH:-}" ]; then scheme=https; set -- --insecure; fi; \
    if [ -n "${TLS_CLIENT_CA_PATH:-}" ]; then set -- "$@" --cert "${HEALTHCHECK_CLIENT_CERTIFICATE_PATH:-}" --key "${HEALTHCHECK_CLIENT_KEY_PATH:-}"; fi; \
    curl -fsS --noproxy '*' --max-time 4 -o /dev/null "$@" "$scheme://127.0.0.1:${PORT:-8080}/v1/health" || exit 1

ENTRYPOINT ["/app/Server"]
