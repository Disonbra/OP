#!/bin/bash
# install_on_device.sh
# Uses xcrun devicectl to install the built app onto a physical device.

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_BUILD_DIR="${REPO_DIR}/ios_build/xcode_output"
BUNDLE_ID="org.alpha3.launcher.Alpha3"

# 1. Find the built .app
echo "=== 1. Locating build ==="
# Look for the device build specifically
APP_PATH=$(find "${XCODE_BUILD_DIR}/Build/Products/Release-iphoneos" -name "*.app" | head -1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Could not find device build at ${XCODE_BUILD_DIR}/Build/Products/Release-iphoneos"
    echo "Please run 'buildscripts/package_ipa.sh' first (without the 'sim' flag)."
    exit 1
fi

echo "Found app: $APP_PATH"

# 2. Find a device
echo "=== 2. Detecting device ==="
# Get the first device identifier that isn't a header
DEVICE_ID=$(xcrun devicectl list devices --hide-headers --columns identifier | head -1 | tr -d '[:space:]')

if [ -z "$DEVICE_ID" ] || [[ "$DEVICE_ID" == *"No"* ]]; then
    echo "ERROR: No physical device found. Is it plugged in and unlocked?"
    echo "Run 'xcrun devicectl list devices' to check manually."
    exit 1
fi

echo "Target Device UDID: $DEVICE_ID"

# 3. Install
echo "=== 3. Installing to device ==="
# Note: This requires the device to be trusted and developer mode enabled.
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

# 4. Launch
echo "=== 4. Launching app ==="
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"

echo "=== Done! ==="
