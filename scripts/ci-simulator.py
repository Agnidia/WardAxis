#!/usr/bin/env python3
"""Print the UDID of an available simulator for CI.

Usage: python3 -I scripts/ci-simulator.py <iOS|tvOS>

Picks the newest installed runtime of the platform, then the first device whose
name starts with the platform's device family. Exits non-zero when nothing
matches, so a runner image without the runtime fails the job instead of
falling back to another destination.
"""

import json
import re
import subprocess
import sys

FAMILY = {"iOS": "iPhone", "tvOS": "Apple TV"}
RUNTIME = re.compile(r"^com\.apple\.CoreSimulator\.SimRuntime\.(iOS|tvOS)-(\d+)-(\d+)$")


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in FAMILY:
        print("usage: ci-simulator.py <iOS|tvOS>", file=sys.stderr)
        return 2
    platform = sys.argv[1]
    family = FAMILY[platform]

    listing = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    devices = json.loads(listing).get("devices", {})
    if not isinstance(devices, dict):
        print("simctl returned an unexpected listing", file=sys.stderr)
        return 1

    runtimes = []
    for key, entries in devices.items():
        match = RUNTIME.match(key)
        if match and match.group(1) == platform and isinstance(entries, list):
            runtimes.append(((int(match.group(2)), int(match.group(3))), entries))

    for _, entries in sorted(runtimes, key=lambda item: item[0], reverse=True):
        for device in entries:
            name = device.get("name") if isinstance(device, dict) else None
            udid = device.get("udid") if isinstance(device, dict) else None
            if isinstance(name, str) and isinstance(udid, str) and name.startswith(family):
                print(udid)
                return 0

    print(f"no available {platform} simulator", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
