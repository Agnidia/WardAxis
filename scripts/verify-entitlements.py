#!/usr/bin/env python3
"""
Verify the signed entitlements of an App Store build.

Checks the app and every nested code bundle (app extension, system extension,
XPC service, login item) in a .xcarchive or .app, including the
NetworkExtension provider types each bundle may claim (ADR 0004). Reads the code signature,
which is what the OS enforces, not the entitlements files.

Usage:
    python3 -I scripts/verify-entitlements.py <path.xcarchive | path.app>

Exit status: 0 when every bundle passes, 1 on any violation or unreadable input.
"""

from __future__ import annotations

import plistlib
import subprocess
import sys
from pathlib import Path

NESTED_SUFFIXES = (".app", ".appex", ".systemextension", ".xpc")

FORBIDDEN_KEYS = (
    "com.apple.developer.endpoint-security.client",
    "com.apple.security.cs.allow-dyld-environment-variables",
    "com.apple.security.cs.allow-jit",
    "com.apple.security.cs.allow-unsigned-executable-memory",
    "com.apple.security.cs.disable-executable-page-protection",
    "com.apple.security.cs.disable-library-validation",
    "com.apple.security.get-task-allow",
)
# App Review rejects new temporary exceptions; Xcode adds some only to test hosts.
FORBIDDEN_PREFIXES = ("com.apple.security.temporary-exception.",)
# Reserved for the Developer ID lab build (ADR 0003); never part of an App Store bundle ID.
LAB_SEGMENT = "lab"

NE_KEY = "com.apple.developer.networking.networkextension"
# Apple documents these variants for Developer ID profiles only.
NE_DEVELOPER_ID_SUFFIX = "-systemextension"
SYSTEM_EXTENSION_INSTALL_KEY = "com.apple.developer.system-extension.install"

# Provider types each bundle may claim, per platform (ADR 0004). Keyed by the
# bundle-ID suffix under the app root; "" is the app. A bundle or platform not
# listed may claim none, so a new target fails until ADR 0004 grants it a type.
NE_ALLOWED: dict[str, dict[str, frozenset[str]]] = {
    "": {
        "macos": frozenset({"app-proxy-provider", "content-filter-provider", "dns-proxy", "url-filter-provider"}),
        "ios": frozenset({"packet-tunnel-provider", "url-filter-provider"}),
        "tvos": frozenset({"packet-tunnel-provider"}),
    },
    ".networkfilter": {"macos": frozenset({"content-filter-provider"})},
    ".dnsproxy": {"macos": frozenset({"dns-proxy"})},
    ".transparentproxy": {"macos": frozenset({"app-proxy-provider"})},
    ".urlfilter": {
        "macos": frozenset({"url-filter-provider"}),
        "ios": frozenset({"url-filter-provider"}),
    },
    ".packettunnel": {
        "ios": frozenset({"packet-tunnel-provider"}),
        "tvos": frozenset({"packet-tunnel-provider"}),
    },
}


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def resolve_app(path: Path) -> Path:
    if path.suffix == ".app":
        return path
    if path.suffix == ".xcarchive":
        apps = sorted((path / "Products" / "Applications").glob("*.app"))
        if len(apps) != 1:
            fail(f"expected one app in {path}, found {len(apps)}")
        return apps[0]
    fail(f"not an .app or .xcarchive: {path}")
    raise AssertionError("unreachable")


def info_plist(bundle: Path) -> dict:
    for candidate in (bundle / "Contents" / "Info.plist", bundle / "Info.plist"):
        if candidate.is_file():
            with candidate.open("rb") as handle:
                return plistlib.load(handle)
    fail(f"no Info.plist in {bundle}")
    raise AssertionError("unreachable")


def codesign(arguments: list[str]) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(["/usr/bin/codesign", *arguments], capture_output=True, check=False)


def entitlements(bundle: Path) -> dict:
    result = codesign(["-d", "--entitlements", "-", "--xml", str(bundle)])
    if result.returncode != 0:
        fail(f"codesign could not read {bundle}")
    if not result.stdout.strip():
        return {}
    try:
        value = plistlib.loads(result.stdout)
    except plistlib.InvalidFileException:
        fail(f"unparseable entitlements in {bundle}")
    if not isinstance(value, dict):
        fail(f"entitlements of {bundle} are not a dictionary")
    return value


def authorities(bundle: Path) -> list[str]:
    result = codesign(["-dvv", str(bundle)])
    lines = result.stderr.decode("utf-8", errors="replace").splitlines()
    return [line.removeprefix("Authority=") for line in lines if line.startswith("Authority=")]


def nested_bundles(app: Path) -> list[Path]:
    found = [p for p in app.rglob("*") if p.is_dir() and p.suffix in NESTED_SUFFIXES]
    return [app, *sorted(found)]


def platform_of(app: Path) -> str:
    if (app / "Contents").is_dir():
        return "macos"
    platforms = info_plist(app).get("CFBundleSupportedPlatforms")
    if platforms == ["iPhoneOS"]:
        return "ios"
    if platforms == ["AppleTVOS"]:
        return "tvos"
    # The NE allowlist differs per platform; guessing would check the wrong one.
    fail(f"unknown platform {platforms!r} in {app.name}")
    raise AssertionError("unreachable")


def check_network_extension(name: str, values: dict, bundle_id: str, root_id: str, platform: str) -> list[str]:
    problems: list[str] = []
    claimed = values.get(NE_KEY, [])
    if not isinstance(claimed, list) or not all(isinstance(item, str) for item in claimed):
        return [f"{name}: {NE_KEY} is not an array of strings"]
    suffix = bundle_id.removeprefix(root_id)
    allowed = NE_ALLOWED.get(suffix, {}).get(platform, frozenset())
    for provider in claimed:
        if provider.endswith(NE_DEVELOPER_ID_SUFFIX):
            problems.append(f"{name}: NetworkExtension value {provider} is for Developer ID only")
        elif provider not in allowed:
            problems.append(f"{name}: NetworkExtension value {provider} is not granted to this bundle")

    if SYSTEM_EXTENSION_INSTALL_KEY in values and not (suffix == "" and platform == "macos"):
        problems.append(f"{name}: {SYSTEM_EXTENSION_INSTALL_KEY} is allowed on the macOS app only")
    return problems


def check_bundle(bundle: Path, root_id: str, platform: str) -> list[str]:
    problems: list[str] = []
    name = bundle.name
    values = entitlements(bundle)

    # The chain lists the Developer ID leaf and its intermediate CA; report the bundle once.
    if any(authority.startswith("Developer ID") for authority in authorities(bundle)):
        problems.append(f"{name}: signed by a Developer ID identity")

    for key in values:
        if key in FORBIDDEN_KEYS or key.startswith(FORBIDDEN_PREFIXES):
            problems.append(f"{name}: forbidden entitlement {key}")

    if platform == "macos" and values.get("com.apple.security.app-sandbox") is not True:
        problems.append(f"{name}: App Sandbox is off")

    team = values.get("com.apple.developer.team-identifier")
    app_identifier = values.get("com.apple.application-identifier") or values.get("application-identifier")
    bundle_id = info_plist(bundle).get("CFBundleIdentifier", "")
    if bundle_id != root_id and not bundle_id.startswith(f"{root_id}."):
        problems.append(f"{name}: bundle ID {bundle_id} is outside {root_id}")
    if LAB_SEGMENT in bundle_id.split("."):
        problems.append(f"{name}: bundle ID {bundle_id} is in the lab namespace")
    problems.extend(check_network_extension(name, values, bundle_id, root_id, platform))

    allowed_app_groups = {f"group.{root_id}", f"{team}.{root_id}"}
    for group in values.get("com.apple.security.application-groups", []):
        if group not in allowed_app_groups:
            problems.append(f"{name}: App Group {group} is outside the WardAxis group")

    keychain_groups = values.get("keychain-access-groups", [])
    if keychain_groups:
        if not isinstance(app_identifier, str) or not app_identifier.endswith(f".{bundle_id}"):
            problems.append(f"{name}: application identifier does not match {bundle_id}")
        else:
            prefix = app_identifier[: -len(bundle_id)]
            if keychain_groups[0] != app_identifier:
                problems.append(f"{name}: first Keychain group is not the bundle's private group")
            allowed_keychain_groups = {app_identifier, f"{prefix}{root_id}.shared"}
            for group in keychain_groups:
                if group not in allowed_keychain_groups:
                    problems.append(f"{name}: Keychain group {group} is outside the WardAxis groups")

    return problems


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 1
    app = resolve_app(Path(sys.argv[1]))
    platform = platform_of(app)
    root_id = info_plist(app).get("CFBundleIdentifier")
    if not isinstance(root_id, str) or not root_id:
        fail(f"{app.name} has no bundle identifier")

    problems: list[str] = []
    bundles = nested_bundles(app)
    for bundle in bundles:
        problems.extend(check_bundle(bundle, root_id, platform))

    for problem in problems:
        print(f"error: {problem}", file=sys.stderr)
    if problems:
        return 1
    print(f"ok: {len(bundles)} bundle(s) in {app.name} pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
