#!/bin/bash
# macOS (Squark) release: electron-builder -> Xcode cloud-managed Developer ID signing -> Apple notarization.
#
# Xcode can only cloud-sign an archive, so the Electron app is wrapped in a hand-built .xcarchive and exported
# with `xcodebuild -exportArchive` (method developer-id, destination upload). This uses the developer account
# already signed in to Xcode: no local Developer ID certificate and no notarization password are needed.
#
#   TEAM=<team id> SIGN_ID=<local codesigning identity or its SHA-1> scripts/release-mac.sh
#
# SIGN_ID signs the app first so every nested binary carries its hardened-runtime entitlements; Xcode keeps
# those entitlements when it re-signs with Developer ID.
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM="${TEAM:?set TEAM to the Apple developer team ID}"
SIGN_ID="${SIGN_ID:?set SIGN_ID to a local codesigning identity (name or SHA-1)}"
SKIP_BUILD="${SKIP_BUILD:-0}"

APP_NAME="FlyByWire Installer"
VERSION=$(node -p "require('./package.json').version")
BUNDLE_ID="${BUNDLE_ID:-io.github.jason5545.squark-fbw-installer}"
OUT=dist/release
ARCHIVE="$OUT/$APP_NAME.xcarchive"

if [ "$SKIP_BUILD" != 1 ]; then
  echo "==> build and sign with $SIGN_ID"
  npm run build
  CSC_NAME="$SIGN_ID" npx electron-builder --mac dir --arm64 --publish=never -c.appId="$BUNDLE_ID"
fi

SRC_APP="dist/mac-arm64/$APP_NAME.app"
codesign --verify --deep --strict "$SRC_APP"

echo "==> wrap in $ARCHIVE"
rm -rf "$OUT" && mkdir -p "$ARCHIVE/Products/Applications"
ditto "$SRC_APP" "$ARCHIVE/Products/Applications/$APP_NAME.app"
cat > "$ARCHIVE/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>ApplicationProperties</key>
    <dict>
        <key>ApplicationPath</key><string>Applications/$APP_NAME.app</string>
        <key>Architectures</key><array><string>arm64</string></array>
        <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
        <key>CFBundleShortVersionString</key><string>$VERSION</string>
        <key>CFBundleVersion</key><string>$VERSION</string>
        <key>Team</key><string>$TEAM</string>
    </dict>
    <key>ArchiveVersion</key><integer>2</integer>
    <key>CreationDate</key><date>$(date -u +%Y-%m-%dT%H:%M:%SZ)</date>
    <key>Name</key><string>$APP_NAME</string>
    <key>SchemeName</key><string>$APP_NAME</string>
</dict>
</plist>
PLIST

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>developer-id</string>
    <key>signingStyle</key><string>automatic</string>
    <key>teamID</key><string>$TEAM</string>
    <key>destination</key><string>upload</string>
</dict>
</plist>
PLIST

echo "==> sign with Developer ID and upload for notarization"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -exportPath "$OUT/upload" -allowProvisioningUpdates

echo "==> waiting for notarization"
for i in $(seq 1 60); do
  if xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE" -exportPath "$OUT/notarized" >"$OUT/notarized.log" 2>&1; then
    break
  fi
  [ "$i" = 60 ] && { cat "$OUT/notarized.log"; echo "notarization did not finish in 30 minutes"; exit 1; }
  sleep 30
done

APP="$OUT/notarized/$APP_NAME.app"
codesign --verify --deep --strict "$APP"
xcrun stapler validate "$APP"
spctl -a -vv -t exec "$APP"

ditto -c -k --keepParent "$APP" "$OUT/FlyByWire-Installer-$VERSION-mac-arm64.zip"
echo "==> done: $APP"
