#!/usr/bin/env bash
# Build and install Inch (iOS + Watch) to physical devices.
#
# Usage:
#   ./scripts/build-device.sh          # builds to iPhone (Watch app included)
#   ./scripts/build-device.sh phone    # same as above
#   ./scripts/build-device.sh watch    # same — Watch deploys via iPhone
#   ./scripts/build-device.sh both     # same — one build covers both

set -euo pipefail

IPHONE_UDID="FA7530FD-7656-5A9B-8732-A84A93F5F87B"
WATCH_UDID="1BF95A8D-949E-556B-9A45-D2ACB43AA04F"

PROJECT_DIR="$(cd "$(dirname "$0")/../inch" && pwd)"
SCHEME="inch"
CONFIG="Debug"

echo "Building $SCHEME ($CONFIG) → iPhone ($IPHONE_UDID)"
echo "Watch app will be embedded and pushed automatically."
echo ""

xcodebuild \
  -project "$PROJECT_DIR/inch.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "platform=iOS,id=$IPHONE_UDID" \
  -configuration "$CONFIG" \
  -allowProvisioningUpdates \
  build install \
  | xcpretty 2>/dev/null || cat  # fall back to raw output if xcpretty not installed

echo ""
echo "Done. Check your iPhone and paired Watch."
