#!/usr/bin/env bash
set -euo pipefail

APPLE_TEAM_ID="${APPLE_TEAM_ID:-T46A6Q874U}"
SIGN_IDENTITY="${SIGN_IDENTITY:-${CODESIGN_IDENTITY:-}}"

if [ -n "$SIGN_IDENTITY" ]; then
    printf '%s\n' "$SIGN_IDENTITY"
    exit 0
fi

if [ -n "${SECURITY_FIND_IDENTITY_OUTPUT:-}" ]; then
    IDENTITY_OUTPUT="$SECURITY_FIND_IDENTITY_OUTPUT"
else
    IDENTITY_OUTPUT="$(security find-identity -v -p codesigning 2>/dev/null || true)"
fi

find_identity() {
    local certificate_type="$1"
    local team_required="$2"

    while IFS= read -r identity; do
        if [[ "$identity" == *"$certificate_type"* ]]; then
            if [ "$team_required" = "0" ] || [[ "$identity" == *"($APPLE_TEAM_ID)"* ]]; then
                printf '%s\n' "$identity"
                return 0
            fi
        fi
    done < <(printf '%s\n' "$IDENTITY_OUTPUT" | awk -F '"' '/"/ { print $2 }')

    return 1
}

find_identity "Developer ID Application:" 1 && exit 0
find_identity "Apple Distribution:" 1 && exit 0
find_identity "Apple Development:" 1 && exit 0
find_identity "Developer ID Application:" 0 && exit 0
find_identity "Apple Distribution:" 0 && exit 0
find_identity "Apple Development:" 0 && exit 0

exit 0
