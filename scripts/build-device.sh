#!/usr/bin/env bash
# Build and install Daily Ascent (iOS + Watch) to physical devices.
#
# Usage:
#   ./scripts/build-device.sh          # builds to iPhone (Watch app included)
#   ./scripts/build-device.sh phone    # same as above
#   ./scripts/build-device.sh watch    # same — Watch deploys via iPhone
#   ./scripts/build-device.sh both     # same — one build covers both

set -euo pipefail

# UDIDs as reported by xcrun xctrace (used by xcodebuild).
# Note: these differ from xcrun devicectl UDIDs — xcodebuild uses xctrace.
IPHONE_UDID="00008110-001609380E3B801E"
WATCH_UDID="00008006-001E2C2414C3402E"

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
