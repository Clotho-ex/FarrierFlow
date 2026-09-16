#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly WRAPPER="$REPOSITORY_ROOT/scripts/local-screenshots-creative-proof.sh"

bash -n "$WRAPPER"

doctor_output="$($WRAPPER doctor)"
grep -Fq 'global Koubou: 0.20.0' <<<"$doctor_output"
grep -Fq 'isolated Koubou: 0.18.1' <<<"$doctor_output"
grep -Fq 'raw source: 01-today-run-sheet.png (1320x2868)' <<<"$doctor_output"
grep -Fq 'raw source: 03-work-to-invoice.png (1320x2868)' <<<"$doctor_output"
grep -Fq 'Figma baseline: 01-today-run-sheet.jpg (1320x2868)' <<<"$doctor_output"
grep -Fq 'Figma baseline: 06-work-to-invoice.jpg (1320x2868)' <<<"$doctor_output"

printf 'creative proof wrapper contract tests passed\n'
