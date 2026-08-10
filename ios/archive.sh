#!/bin/bash
# Archives and exports a TestFlight-ready .ipa. Validated end-to-end against
# the real NNFD7CKGLG (Tony Aboud) Apple Developer account: both the app and
# widget extension come out Apple Distribution-signed with the App Group
# entitlement present and beta-reports-active set, ready to upload via
# Transporter or `xcrun altool` / `xcrun notarytool`'s sibling for App Store
# Connect.
#
# -allowProvisioningUpdates lets xcodebuild register missing App ID
# capabilities (e.g. App Groups) via the Developer Portal API itself —
# without it, a first-ever archive for a brand-new bundle ID fails with
# "doesn't include the App Groups capability" until someone opens the
# project in Xcode once to let it auto-register things.
set -euo pipefail
cd "$(dirname "$0")"

xcodegen generate

ARCHIVE_PATH="build/ClassMusic.xcarchive"
EXPORT_PATH="build/export"
rm -rf build
mkdir -p build

xcodebuild -project ClassMusic.xcodeproj -scheme ClassMusic -configuration Release \
  -destination "generic/platform=iOS" archive -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates

xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist ExportOptions.plist -allowProvisioningUpdates

echo "Exported: $EXPORT_PATH/ClassMusic.ipa"
echo "Upload with Transporter.app, or: xcrun altool --upload-app -f \"$EXPORT_PATH/ClassMusic.ipa\" -t ios --apiKey <key> --apiIssuer <issuer>"
