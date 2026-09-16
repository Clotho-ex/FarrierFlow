#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly CONFIG="$REPOSITORY_ROOT/.asc/screenshots/creative-proof.yml"
readonly CREATIVE_DIR="$REPOSITORY_ROOT/.asc/screenshots/creative"
readonly OUTPUT_ROOT="$REPOSITORY_ROOT/output/screenshots/creative-proof"
readonly STAGING_DIR="$OUTPUT_ROOT/staging"
readonly NEW_DIR="$OUTPUT_ROOT/new"
readonly REVIEW_DIR="$OUTPUT_ROOT/review"
readonly BASELINE_DIR="$OUTPUT_ROOT/baseline"
readonly RAW_DIR="$REPOSITORY_ROOT/output/screenshots/raw"
readonly FIGMA_BASELINE_ROOT="${FARRIERFLOW_FIGMA_BASELINE_DIR:-$HOME/Desktop/Updated-Screenshots-Figma-Export}"
readonly FIGMA_SLIDE_01="${FARRIERFLOW_FIGMA_SLIDE_01:-$FIGMA_BASELINE_ROOT/01-today-run-sheet.jpg}"
readonly FIGMA_SLIDE_03="${FARRIERFLOW_FIGMA_SLIDE_03:-$FIGMA_BASELINE_ROOT/06-work-to-invoice.jpg}"
readonly ISOLATED_KOUBOU_LOCATION="${FARRIERFLOW_KOUBOU_BIN:-$HOME/.local/share/farrierflow-tools/koubou-0.18.1/bin}"
if [[ -d "$ISOLATED_KOUBOU_LOCATION" ]]; then
  readonly ISOLATED_KOUBOU_BIN="$ISOLATED_KOUBOU_LOCATION/kou"
else
  readonly ISOLATED_KOUBOU_BIN="$ISOLATED_KOUBOU_LOCATION"
fi
readonly GLOBAL_KOUBOU_BIN="${FARRIERFLOW_CREATIVE_KOUBOU_BIN:-$(command -v kou 2>/dev/null || true)}"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

version_for() {
  "$1" --version 2>/dev/null | sed -E 's/^[^0-9]*([0-9]+\.[0-9]+\.[0-9]+).*$/\1/'
}

dimensions_for() {
  local image_path="$1"
  local width height
  width="$(sips -g pixelWidth "$image_path" 2>/dev/null | awk '/pixelWidth/ { print $2 }')"
  height="$(sips -g pixelHeight "$image_path" 2>/dev/null | awk '/pixelHeight/ { print $2 }')"
  printf '%sx%s' "$width" "$height"
}

validate_raw_source() {
  local filename="$1"
  local image_path="$RAW_DIR/$filename"
  [[ -f "$image_path" ]] || fail "missing raw source: $image_path (run the existing capture pipeline first)"
  local dimensions
  dimensions="$(dimensions_for "$image_path")"
  [[ "$dimensions" == "1320x2868" ]] || fail "$filename must be 1320x2868, found $dimensions"
  printf 'raw source: %s (%s)\n' "$filename" "$dimensions"
}

validate_figma_baseline() {
  local image_path="$1"
  local filename
  filename="$(basename "$image_path")"
  [[ -f "$image_path" ]] || fail "missing owner-provided Figma baseline: $image_path"
  local dimensions
  dimensions="$(dimensions_for "$image_path")"
  [[ "$dimensions" == "1320x2868" ]] || fail "$filename must be 1320x2868, found $dimensions"
  printf 'Figma baseline: %s (%s)\n' "$filename" "$dimensions"
}

validate_html_runtime() {
  local shebang runtime_python
  shebang="$(head -n 1 "$GLOBAL_KOUBOU_BIN")"
  runtime_python="${shebang#\#!}"
  [[ -x "$runtime_python" ]] || fail "cannot resolve global Koubou Python runtime from $GLOBAL_KOUBOU_BIN"

  "$runtime_python" - <<'PY'
from koubou.html_setup import check_html_environment

status = check_html_environment()
if not status.ready:
    raise SystemExit("error: Koubou HTML runtime is not ready; run 'kou setup-html' explicitly")
print("html renderer: ready")
PY
}

doctor() {
  [[ -n "$GLOBAL_KOUBOU_BIN" && -x "$GLOBAL_KOUBOU_BIN" ]] || fail "global Koubou is unavailable; install Koubou 0.20.0 explicitly"
  [[ -x "$ISOLATED_KOUBOU_BIN" ]] || fail "isolated Koubou is unavailable at $ISOLATED_KOUBOU_BIN; set FARRIERFLOW_KOUBOU_BIN or create the documented 0.18.1 environment"
  command -v sips >/dev/null || fail "sips is required"

  local global_version isolated_version
  global_version="$(version_for "$GLOBAL_KOUBOU_BIN")"
  isolated_version="$(version_for "$ISOLATED_KOUBOU_BIN")"
  [[ "$global_version" == "0.20.0" ]] || fail "creative rendering requires global Koubou 0.20.0, found $global_version at $GLOBAL_KOUBOU_BIN"
  [[ "$isolated_version" == "0.18.1" ]] || fail "ASC compatibility requires isolated Koubou 0.18.1, found $isolated_version at $ISOLATED_KOUBOU_BIN"

  printf 'global Koubou: %s (%s)\n' "$global_version" "$GLOBAL_KOUBOU_BIN"
  printf 'isolated Koubou: %s (%s)\n' "$isolated_version" "$ISOLATED_KOUBOU_BIN"
  validate_html_runtime
  validate_raw_source "01-today-run-sheet.png"
  validate_raw_source "03-work-to-invoice.png"
  validate_figma_baseline "$FIGMA_SLIDE_01"
  validate_figma_baseline "$FIGMA_SLIDE_03"

  if grep -ERn 'https?://' "$CONFIG" "$CREATIVE_DIR" >/dev/null; then
    fail "creative proof templates must not reference remote resources"
  fi
  printf 'network assets: none\n'
}

render() {
  doctor

  rm -rf "$STAGING_DIR" "$NEW_DIR" "$REVIEW_DIR" "$BASELINE_DIR"
  mkdir -p "$STAGING_DIR" "$NEW_DIR" "$REVIEW_DIR" "$BASELINE_DIR"

  "$GLOBAL_KOUBOU_BIN" generate "$CONFIG" --output json > "$OUTPUT_ROOT/koubou-result.json"

  local device_dir="$STAGING_DIR/iPhone_17_Pro_Max_-_Deep_Blue_-_Portrait"
  for filename in 01-today-run-sheet.png 03-work-to-invoice.png; do
    [[ -f "$device_dir/$filename" ]] || fail "Koubou did not produce $filename"
    cp "$device_dir/$filename" "$NEW_DIR/$filename"
    cp "${device_dir}/${filename%.png}.layout.json" "$NEW_DIR/${filename%.png}.layout.json"
    [[ "$(dimensions_for "$NEW_DIR/$filename")" == "1320x2868" ]] || fail "$filename has an unexpected output size"
  done

  cp "$FIGMA_SLIDE_01" "$BASELINE_DIR/01-today-run-sheet.jpg"
  cp "$FIGMA_SLIDE_03" "$BASELINE_DIR/03-work-to-invoice.jpg"
  cp "$CREATIVE_DIR/review.html" "$REVIEW_DIR/index.html"
  printf 'proof: %s\n' "$NEW_DIR/01-today-run-sheet.png"
  printf 'proof: %s\n' "$NEW_DIR/03-work-to-invoice.png"
  printf 'review: %s\n' "$REVIEW_DIR/index.html"
}

usage() {
  printf 'Usage: %s {doctor|render}\n' "$(basename "$0")"
}

case "${1:-}" in
  doctor) doctor ;;
  render) render ;;
  *) usage; exit 64 ;;
esac
