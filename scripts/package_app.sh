#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="JJPost"
APP_VERSION="${APP_VERSION:-1.0.0}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-T46A6Q874U}"
EXECUTABLE_NAME="ProjPostApp"
BUILD_DIR="$ROOT_DIR/.build/$CONFIGURATION"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
RESOURCE_BUNDLE_NAME="ProjPost_ProjPostApp.bundle"
ICON_SOURCE="$ROOT_DIR/Sources/ProjPostApp/Resources/AppIcon.icns"
SIGN_IDENTITY="${SIGN_IDENTITY:-${CODESIGN_IDENTITY:-}}"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION" --product "$EXECUTABLE_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod 755 "$MACOS_DIR/$EXECUTABLE_NAME"

if [ -d "$BUILD_DIR/$RESOURCE_BUNDLE_NAME" ]; then
    cp -R "$BUILD_DIR/$RESOURCE_BUNDLE_NAME" "$RESOURCES_DIR/$RESOURCE_BUNDLE_NAME"
fi

if [ -f "$ICON_SOURCE" ]; then
    cp "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.icns"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>ProjPostApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.jjpost.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleDisplayName</key>
    <string>JJPost</string>
    <key>CFBundleName</key>
    <string>JJPost</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

if [ -z "$SIGN_IDENTITY" ] && [ "${DISABLE_AUTO_SIGN:-0}" != "1" ]; then
    SIGN_IDENTITY="$(APPLE_TEAM_ID="$APPLE_TEAM_ID" "$ROOT_DIR/scripts/select_signing_identity.sh")"
fi

if [ -n "$SIGN_IDENTITY" ]; then
    echo "Signing $APP_DIR with $SIGN_IDENTITY"
    if [[ "$SIGN_IDENTITY" == Apple\ Development:* ]]; then
        echo "Warning: Apple Development signing is suitable for local testing, not GitHub Releases distribution." >&2
    fi
    if ! codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"; then
        echo "Warning: signing with $SIGN_IDENTITY failed; falling back to ad-hoc signing." >&2
        codesign --force --deep --sign - "$APP_DIR"
    fi
else
    echo "Signing $APP_DIR with ad-hoc identity"
    codesign --force --deep --sign - "$APP_DIR"
fi

echo "Packaged $APP_DIR"
