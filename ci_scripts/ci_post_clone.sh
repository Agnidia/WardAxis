#!/bin/bash
set -e

# Allow automatic package resolution
defaults delete com.apple.dt.Xcode IDEPackageOnlyUseVersionsFromResolvedFile || true
defaults delete com.apple.dt.Xcode IDEDisableAutomaticPackageResolution || true
