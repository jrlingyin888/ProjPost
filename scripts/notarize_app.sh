#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-JJPost}"
APP_VERSION="${APP_VERSION:-1.0.0}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-T46A6Q874U}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_DIR="${APP_DIR:-$DIST_DIR/$APP_NAME.app}"
NOTARY_ARCHIVE_PATH="${NOTARY_ARCHIVE_PATH:-$DIST_DIR/$APP_NAME-$APP_VERSION-notary-submit.zip}"
DRY_RUN="${DRY_RUN:-0}"

if [ ! -d "$APP_DIR" ]; then
    echo "App bundle not found: $APP_DIR" >&2
    exit 1
fi

AUTH_ARGS=()
AUTH_DESCRIPTION=""

if [ -n "${NOTARYTOOL_PROFILE:-}" ]; then
    AUTH_ARGS=(--keychain-profile "$NOTARYTOOL_PROFILE")
    AUTH_DESCRIPTION="--keychain-profile $NOTARYTOOL_PROFILE"
elif [ -n "${APPLE_ID:-}" ] && [ -n "${APP_SPECIFIC_PASSWORD:-}" ]; then
    AUTH_ARGS=(--apple-id "$APPLE_ID" --password "$APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID")
    AUTH_DESCRIPTION="--apple-id $APPLE_ID --password ******** --team-id $APPLE_TEAM_ID"
elif [ -n "${ASC_KEY_PATH:-}" ] && [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ]; then
    AUTH_ARGS=(--key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID")
    AUTH_DESCRIPTION="--key $ASC_KEY_PATH --key-id $ASC_KEY_ID --issuer $ASC_ISSUER_ID"
else
    cat >&2 <<EOF
Missing notarization credentials.

Use one of:
  NOTARYTOOL_PROFILE=JJPostNotary
  APPLE_ID=<apple-id> APP_SPECIFIC_PASSWORD=<app-specific-password>
  ASC_KEY_PATH=<AuthKey_XXXX.p8> ASC_KEY_ID=<key-id> ASC_ISSUER_ID=<issuer-id>

Recommended one-time setup:
  xcrun notarytool store-credentials JJPostNotary --apple-id <apple-id> --team-id $APPLE_TEAM_ID --password <app-specific-password>
EOF
    exit 2
fi

mkdir -p "$DIST_DIR"

if [ "$DRY_RUN" = "1" ]; then
    echo "Would run: ditto -c -k --keepParent $APP_DIR $NOTARY_ARCHIVE_PATH"
    echo "Would run: xcrun notarytool submit $NOTARY_ARCHIVE_PATH $AUTH_DESCRIPTION --wait"
    echo "Would run: xcrun stapler staple $APP_DIR"
    echo "Would run: spctl --assess --type execute -vv $APP_DIR"
    exit 0
fi

rm -f "$NOTARY_ARCHIVE_PATH"
ditto -c -k --keepParent "$APP_DIR" "$NOTARY_ARCHIVE_PATH"

xcrun notarytool submit "$NOTARY_ARCHIVE_PATH" "${AUTH_ARGS[@]}" --wait
xcrun stapler staple "$APP_DIR"
spctl --assess --type execute -vv "$APP_DIR"

echo "Notarized and stapled $APP_DIR"
