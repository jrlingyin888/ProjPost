#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-JJPost}"
APP_VERSION="${APP_VERSION:-1.0.0}"
RELEASE_KIND="${RELEASE_KIND:-dev-id}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_DIR="${APP_DIR:-$DIST_DIR/$APP_NAME.app}"
BUILD_IF_MISSING="${BUILD_IF_MISSING:-1}"
ZIP_PATH="${ZIP_PATH:-$DIST_DIR/$APP_NAME-$APP_VERSION-$RELEASE_KIND.zip}"

if [ ! -d "$APP_DIR" ]; then
    if [ "$BUILD_IF_MISSING" = "0" ]; then
        echo "App bundle not found: $APP_DIR" >&2
        exit 1
    fi

    APP_VERSION="$APP_VERSION" "$ROOT_DIR/scripts/package_app.sh"
fi

mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Created $ZIP_PATH"
