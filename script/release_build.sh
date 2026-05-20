#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacAppGrid"
BUNDLE_ID="com.dudqks0319.MacAppGrid"
MIN_SYSTEM_VERSION="14.0"
VERSION="${VERSION:-0.1.0}"
VERSION="${VERSION#v}"
REQUIRE_SIGNED_RELEASE="${REQUIRE_SIGNED_RELEASE:-0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
DMG_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.dmg"
SHA256_PATH="$DMG_PATH.sha256"

if [[ "$REQUIRE_SIGNED_RELEASE" == "1" ]]; then
  if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    echo "REQUIRE_SIGNED_RELEASE=1 but DEVELOPER_ID_APPLICATION is not set." >&2
    exit 1
  fi
  if [[ -z "${NOTARYTOOL_PROFILE:-}" ]]; then
    echo "REQUIRE_SIGNED_RELEASE=1 but NOTARYTOOL_PROFILE is not set." >&2
    exit 1
  fi
fi

rm -rf "$RELEASE_DIR"
mkdir -p "$APP_MACOS"

swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

SIGNED=0
NOTARIZED=0

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP_BUNDLE"
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
  if [[ "${STRICT_APP_ASSESSMENT:-0}" == "1" ]]; then
    spctl --assess --type execute --verbose "$APP_BUNDLE"
  else
    spctl --assess --type execute --verbose "$APP_BUNDLE" || echo "App spctl assessment warning before notarization." >&2
  fi
  SIGNED=1
else
  echo "Unsigned local test build: set DEVELOPER_ID_APPLICATION to sign the app." >&2
fi

if [[ -f "$DMG_PATH" ]]; then
  rm -f "$DMG_PATH"
fi
if [[ -f "$SHA256_PATH" ]]; then
  rm -f "$SHA256_PATH"
fi
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_PATH"

if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
  if [[ "$SIGNED" != "1" ]]; then
    echo "NOTARYTOOL_PROFILE is set, but the app was not signed. Set DEVELOPER_ID_APPLICATION first." >&2
    exit 1
  fi
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH"
  NOTARIZED=1
else
  echo "Unsigned/not-notarized local DMG: set NOTARYTOOL_PROFILE to submit with notarytool." >&2
fi

shasum -a 256 "$DMG_PATH" > "$SHA256_PATH"

echo "App signed: $SIGNED"
echo "DMG notarized: $NOTARIZED"
echo "$DMG_PATH"
echo "$SHA256_PATH"
