#!/usr/bin/env zsh
# upload-testflight.sh — Archive, export, and upload Daily Ascent to TestFlight
#
# Credentials stored in macOS Keychain:
#   security add-generic-password -s "daily-ascent-apple-id" -a "apple_id" -w "your@email.com"
#   security add-generic-password -s "daily-ascent-apple-id" -a "app_specific_password" -w "xxxx-xxxx-xxxx-xxxx"

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Branch guard ──────────────────────────────────────────────────────────────
CURRENT_BRANCH="$(git -C "$SCRIPT_DIR" rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo "❌ Must be on main branch to upload. Currently on: $CURRENT_BRANCH"
  exit 1
fi
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ARCHIVE_PATH=/tmp/daily-ascent.xcarchive
EXPORT_PATH=/tmp/daily-ascent-export
EXPORT_OPTIONS="$SCRIPT_DIR/ExportOptions.plist"

# ── Credentials ──────────────────────────────────────────────────────────────
APPLE_ID="$(security find-generic-password -s daily-ascent-apple-id -a apple_id -w 2>/dev/null)"
APP_PASSWORD="$(security find-generic-password -s daily-ascent-apple-id -a app_specific_password -w 2>/dev/null)"

if [[ -z "$APPLE_ID" || -z "$APP_PASSWORD" ]]; then
  echo "❌ Credentials not found in Keychain. Add them with:"
  echo "   security add-generic-password -s daily-ascent-apple-id -a apple_id -w your@email.com"
  echo "   security add-generic-password -s daily-ascent-apple-id -a app_specific_password -w xxxx-xxxx-xxxx-xxxx"
  exit 1
fi

# ── Build number ─────────────────────────────────────────────────────────────
cd "$PROJECT_DIR/inch"
CURRENT=$(agvtool what-version -terse)
NEW=$((CURRENT + 1))
echo "📦 Bumping build number: $CURRENT → $NEW"
agvtool new-version -all "$NEW" > /dev/null

# ── Archive ───────────────────────────────────────────────────────────────────
echo "🔨 Archiving..."
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
xcodebuild clean archive \
  -scheme inch \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)' | tail -5

# ── Export ────────────────────────────────────────────────────────────────────
echo "📤 Exporting IPA..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates \
  | tail -3

# ── Upload ────────────────────────────────────────────────────────────────────
echo "🚀 Uploading to TestFlight (build $NEW)..."
xcrun altool --upload-app \
  -f "$EXPORT_PATH/inch.ipa" \
  --username "$APPLE_ID" \
  --password "$APP_PASSWORD" \
  2>&1 | grep -v "^$"

echo "✅ Done — build $NEW submitted. Check App Store Connect for processing status."
