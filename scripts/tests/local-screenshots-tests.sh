#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly WRAPPER="$REPOSITORY_ROOT/scripts/local-screenshots.sh"
readonly MANIFEST="$REPOSITORY_ROOT/.asc/screenshots/manifest.json"
readonly BLOCKED_OUTPUT="$(mktemp -t farrierflow-screenshot-05.XXXXXX)"

trap 'rm -f "$BLOCKED_OUTPUT"' EXIT

bash -n "$WRAPPER"
if grep -Fq 'simctl uninstall' "$WRAPPER"; then
    printf 'capture must not uninstall the app from a caller-selected simulator\n' >&2
    exit 1
fi
jq -e '
    .version == 1
    and (.screenshots | length == 7)
    and ([.screenshots[] | select(.blocked == null)] | length == 6)
    and ([.screenshots[] | select(.id == "05-hoof-photos" and .blocked != null)] | length == 1)
    and ([.screenshots[].stage] | all(. == "active" or . == "completed"))
' "$MANIFEST" >/dev/null

for forbidden in \
    'screenshots apply' \
    'screenshots upload' \
    'metadata apply' \
    'asc publish' \
    'asc submit'
do
    if grep -Fq "$forbidden" "$WRAPPER"; then
        printf 'forbidden remote operation found in wrapper: %s\n' "$forbidden" >&2
        exit 1
    fi
done

if "$WRAPPER" capture 05-hoof-photos >"$BLOCKED_OUTPUT" 2>&1; then
    printf 'blocked screenshot 05 unexpectedly succeeded\n' >&2
    exit 1
fi
grep -Fiq 'approved original synthetic hoof-photo source assets are required' \
    "$BLOCKED_OUTPUT"

printf 'local screenshot wrapper contract tests passed\n'
