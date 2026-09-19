#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly WRAPPER="$REPOSITORY_ROOT/scripts/local-screenshots.sh"
readonly MANIFEST="$REPOSITORY_ROOT/.asc/screenshots/manifest.json"
bash -n "$WRAPPER"
if grep -Fq 'simctl uninstall' "$WRAPPER"; then
    printf 'capture must not uninstall the app from a caller-selected simulator\n' >&2
    exit 1
fi
jq -e '
    .version == 1
    and (.screenshots | length == 7)
    and ([.screenshots[] | select(.blocked == null)] | length == 7)
    and ([.screenshots[] | select(.id == "05-hoof-photos" and .stage == "active" and (.actions | length) > 0)] | length == 1)
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

for photo_index in {1..6}; do
    [[ -f "$REPOSITORY_ROOT/.asc/screenshots/fixtures/hoof-photos/Hoof-Image-$photo_index.jpeg" ]]
done
(cd "$REPOSITORY_ROOT/.asc/screenshots/fixtures/hoof-photos" \
    && shasum -a 256 -c SHA256SUMS >/dev/null)

printf 'local screenshot wrapper contract tests passed\n'
