#!/usr/bin/env bash
# Remove every localization pack (*.lproj) from an IPA or .app except
# en.lproj and ko.lproj. Covers Spotify.app itself, its frameworks and the
# injected EeveeSpotify.bundle. Modifies in place.
#
# Base.lproj is NOT a language pack (it holds the storyboards/xibs the UI is
# laid out from), so it is always kept; removing it would break the app.
# A directory's other .lproj folders are only removed when that directory also
# has en.lproj or Base.lproj, so nothing is left without a fallback.
#
# Usage: Tools/strip-lproj.sh path/to/Eevee.ipa
#        Tools/strip-lproj.sh path/to/Spotify.app

set -euo pipefail

TARGET="${1:-}"
[ -n "$TARGET" ] && [ -e "$TARGET" ] || { echo "usage: $0 path/to/Eevee.ipa|Spotify.app" >&2; exit 1; }

KEEP_NAMES=("en.lproj" "ko.lproj" "Base.lproj")

is_kept() {
    local n
    for n in "${KEEP_NAMES[@]}"; do [ "$1" = "$n" ] && return 0; done
    return 1
}

prune_app() {
    local app="$1" removed=0 kept=0 dir name parent
    while IFS= read -r -d '' dir; do
        name=$(basename "$dir")
        if is_kept "$name"; then kept=$((kept + 1)); continue; fi
        parent=$(dirname "$dir")
        if [ -d "$parent/en.lproj" ] || [ -d "$parent/Base.lproj" ]; then
            rm -rf "$dir"
            removed=$((removed + 1))
        fi
    done < <(find "$app" -type d -name '*.lproj' -prune -print0)
    echo "[strip-lproj] removed $removed language pack(s), kept $kept (en/ko/Base)"
}

if [ -d "$TARGET" ]; then
    prune_app "$TARGET"
    exit 0
fi

IPA_ABS=$(cd "$(dirname "$TARGET")" && pwd)/$(basename "$TARGET")
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

( cd "$WORK" && unzip -q "$IPA_ABS" )

APP=$(find "$WORK/Payload" -maxdepth 2 -name '*.app' -type d | head -1)
[ -n "$APP" ] || { echo "no .app under Payload/" >&2; exit 1; }

prune_app "$APP"

# zip -u doesn't reliably drop removed entries — rebuild fresh.
rm -f "$IPA_ABS"
( cd "$WORK" && zip -qry "$IPA_ABS" Payload )

echo "stripped language packs: $IPA_ABS"
