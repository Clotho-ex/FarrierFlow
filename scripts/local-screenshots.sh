#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly MANIFEST="$REPOSITORY_ROOT/.asc/screenshots/manifest.json"
readonly KOUBOU_CONFIG_DIR="$REPOSITORY_ROOT/.asc/screenshots/koubou"
readonly SHOWCASE_PHOTO_DIR="$REPOSITORY_ROOT/.asc/screenshots/fixtures/hoof-photos"
readonly OUTPUT_ROOT="$REPOSITORY_ROOT/output/screenshots"
readonly DERIVED_DATA="$OUTPUT_ROOT/DerivedData"
readonly RAW_DIR="$OUTPUT_ROOT/raw"
readonly COMPOSED_DIR="$OUTPUT_ROOT/composed"
readonly KOUBOU_OUTPUT_DIR="$OUTPUT_ROOT/koubou"
readonly REVIEW_DIR="$OUTPUT_ROOT/review"
readonly TEMP_DIR="$OUTPUT_ROOT/tmp"
readonly APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/FarrierFlow.app"
readonly BUNDLE_ID="com.farrierflow.yusufcan.FarrierFlow"
readonly SCREENSHOT_SIMULATOR_NAME="FarrierFlow Screenshots"
readonly SCREENSHOT_DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"
readonly REQUIRED_ASC_VERSION="5.3.2"
readonly REQUIRED_AXE_VERSION="1.8.0"
readonly REQUIRED_KOUBOU_VERSION="0.18.1"
readonly DEFAULT_KOUBOU_BIN="$HOME/.local/share/farrierflow-tools/koubou-0.18.1/bin"

KOUBOU_BIN="${FARRIERFLOW_KOUBOU_BIN:-$DEFAULT_KOUBOU_BIN}"
SCREENSHOT_UDID=""
SIMULATOR_BOOTED_BY_PIPELINE=0
STATUS_BAR_OVERRIDDEN=0

usage() {
    printf '%s\n' \
        "Usage: scripts/local-screenshots.sh <doctor|build|capture|compose|review|all> [screenshot-id]" \
        "" \
        "Ready screenshot IDs are 01 through 07 as listed in:" \
        "  .asc/screenshots/manifest.json"
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

note() {
    printf '==> %s\n' "$*"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Missing '$1'. $2"
}

cleanup_simulator() {
    if [[ -n "$SCREENSHOT_UDID" && "$STATUS_BAR_OVERRIDDEN" -eq 1 ]]; then
        xcrun simctl status_bar "$SCREENSHOT_UDID" clear >/dev/null 2>&1 || true
    fi
    if [[ -n "$SCREENSHOT_UDID" && "$SIMULATOR_BOOTED_BY_PIPELINE" -eq 1 ]]; then
        xcrun simctl shutdown "$SCREENSHOT_UDID" >/dev/null 2>&1 || true
    fi
}

trap cleanup_simulator EXIT INT TERM

doctor() {
    require_command xcodebuild "Install Xcode and select it with xcode-select."
    require_command xcrun "Install Xcode command-line tools."
    require_command asc "Install asc 5.3.2 locally."
    require_command axe "Install AXe with: brew install cameroncooke/axe/axe"
    require_command jq "Install jq with Homebrew."
    require_command open "open is included with macOS."
    require_command sips "sips is included with macOS."
    require_command shasum "shasum is included with macOS."

    [[ -x "$KOUBOU_BIN/kou" ]] || fail \
        "Koubou was not found at '$KOUBOU_BIN/kou'. Set FARRIERFLOW_KOUBOU_BIN or create the documented isolated 0.18.1 environment."

    local asc_version axe_version koubou_version branch
    asc_version="$(asc --version | awk '{print $1}')"
    axe_version="$(axe --version | awk '{print $1}')"
    koubou_version="$("$KOUBOU_BIN/kou" --version | awk '{print $NF}' | sed 's/^v//')"
    [[ "$asc_version" == "$REQUIRED_ASC_VERSION" ]] || fail \
        "asc $REQUIRED_ASC_VERSION is required; found $asc_version."
    [[ "$axe_version" == "$REQUIRED_AXE_VERSION" ]] || fail \
        "AXe $REQUIRED_AXE_VERSION is required; found $axe_version."
    [[ "$koubou_version" == "$REQUIRED_KOUBOU_VERSION" ]] || fail \
        "Koubou $REQUIRED_KOUBOU_VERSION is required; found $koubou_version at '$KOUBOU_BIN/kou'."

    branch="$(git -C "$REPOSITORY_ROOT" branch --show-current)"
    [[ "$branch" == "growth/v1.0.1-analytics" ]] || fail \
        "Run this workflow only from growth/v1.0.1-analytics; current branch is '$branch'."
    [[ -f "$MANIFEST" ]] || fail "Missing screenshot manifest: $MANIFEST"
    jq -e '
        .version == 1
        and .reference_date == "2026-09-06T13:41:00Z"
        and ([.screenshots[] | select(.blocked == null)] | length == 7)
        and ([.screenshots[] | select(.id == "05-hoof-photos" and .blocked == null)] | length == 1)
        and (([.screenshots[].id] | length) == ([.screenshots[].id] | unique | length))
    ' "$MANIFEST" >/dev/null || fail "Screenshot manifest validation failed."

    while IFS= read -r screenshot_id; do
        [[ -f "$KOUBOU_CONFIG_DIR/$screenshot_id.yml" ]] || fail \
            "Missing Koubou config for $screenshot_id."
    done < <(jq -r '.screenshots[] | select(.blocked == null) | .id' "$MANIFEST")

    local photo_index
    for photo_index in {1..6}; do
        [[ -f "$SHOWCASE_PHOTO_DIR/Hoof-Image-$photo_index.jpeg" ]] || fail \
            "Missing approved showcase photo Hoof-Image-$photo_index.jpeg."
    done
    (cd "$SHOWCASE_PHOTO_DIR" && shasum -a 256 -c SHA256SUMS >/dev/null) || fail \
        "Approved showcase photo checksums do not match the published source assets."

    axe list-simulators >/dev/null
    xcrun simctl list runtimes available >/dev/null

    note "doctor passed"
    printf 'asc: %s\nAXe: %s\nKoubou: %s (%s)\nbranch: %s\n' \
        "$asc_version" "$axe_version" "$koubou_version" "$KOUBOU_BIN/kou" "$branch"
}

build_app() {
    note "building DEBUG simulator app"
    mkdir -p "$OUTPUT_ROOT"
    xcodebuild \
        -project "$REPOSITORY_ROOT/FarrierFlow.xcodeproj" \
        -scheme FarrierFlow \
        -configuration Debug \
        -sdk iphonesimulator \
        -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath "$DERIVED_DATA" \
        -parallel-testing-enabled NO \
        CODE_SIGNING_ALLOWED=NO \
        build
    [[ -d "$APP_PATH" ]] || fail "Build completed without producing $APP_PATH"
}

resolve_screenshot_ids() {
    local requested="${1:-all}"
    SCREENSHOT_IDS=()
    if [[ "$requested" == "all" ]]; then
        while IFS= read -r screenshot_id; do
            SCREENSHOT_IDS+=("$screenshot_id")
        done < <(jq -r '.screenshots[] | select(.blocked == null) | .id' "$MANIFEST")
        return
    fi

    jq -e --arg id "$requested" '.screenshots[] | select(.id == $id)' "$MANIFEST" \
        >/dev/null || fail "Unknown screenshot id '$requested'."
    local blocker
    blocker="$(jq -r --arg id "$requested" '.screenshots[] | select(.id == $id) | .blocked // empty' "$MANIFEST")"
    [[ -z "$blocker" ]] || fail "$requested is blocked: $blocker"
    SCREENSHOT_IDS+=("$requested")
}

simulator_state() {
    xcrun simctl list devices -j | jq -r --arg udid "$1" \
        'first(.devices[][] | select(.udid == $udid) | .state) // empty'
}

ensure_screenshot_simulator() {
    if [[ -n "${FARRIERFLOW_SCREENSHOT_UDID:-}" ]]; then
        SCREENSHOT_UDID="$FARRIERFLOW_SCREENSHOT_UDID"
        [[ -n "$(simulator_state "$SCREENSHOT_UDID")" ]] || fail \
            "FARRIERFLOW_SCREENSHOT_UDID '$SCREENSHOT_UDID' is not an installed simulator."
    else
        SCREENSHOT_UDID="$(xcrun simctl list devices available -j | jq -r \
            --arg name "$SCREENSHOT_SIMULATOR_NAME" \
            'first(.devices[][] | select(.name == $name and .isAvailable == true) | .udid) // empty')"
        if [[ -z "$SCREENSHOT_UDID" ]]; then
            local runtime
            runtime="$(xcrun simctl list runtimes available -j | jq -r \
                'first([.runtimes[] | select(.platform == "iOS" and .isAvailable == true)] | sort_by(.version) | reverse[]) | .identifier // empty')"
            [[ -n "$runtime" ]] || fail "No available iOS Simulator runtime was found."
            SCREENSHOT_UDID="$(xcrun simctl create \
                "$SCREENSHOT_SIMULATOR_NAME" "$SCREENSHOT_DEVICE_TYPE" "$runtime")"
            note "created dedicated screenshot simulator $SCREENSHOT_UDID"
        fi
    fi

    if [[ "$(simulator_state "$SCREENSHOT_UDID")" != "Booted" ]]; then
        xcrun simctl boot "$SCREENSHOT_UDID"
        open -a Simulator --args -CurrentDeviceUDID "$SCREENSHOT_UDID"
        xcrun simctl bootstatus "$SCREENSHOT_UDID" -b
        SIMULATOR_BOOTED_BY_PIPELINE=1
    else
        open -a Simulator --args -CurrentDeviceUDID "$SCREENSHOT_UDID"
    fi

    xcrun simctl ui "$SCREENSHOT_UDID" appearance light
    xcrun simctl status_bar "$SCREENSHOT_UDID" override \
        --time 9:41 \
        --dataNetwork wifi \
        --wifiMode active \
        --wifiBars 3 \
        --cellularMode active \
        --cellularBars 4 \
        --batteryState charged \
        --batteryLevel 100
    STATUS_BAR_OVERRIDDEN=1
}

wait_for_element() {
    local selector_type="$1" selector="$2" attempt hierarchy
    for attempt in $(seq 1 60); do
        hierarchy="$(axe describe-ui --udid "$SCREENSHOT_UDID" 2>/dev/null || true)"
        if grep -Fq "$selector" <<<"$hierarchy"; then
            return
        fi
        sleep 0.25
    done
    fail "Timed out waiting for accessibility $selector_type '$selector'."
}

perform_actions() {
    local screenshot_id="$1" action action_type selector
    while IFS= read -r action; do
        action_type="$(jq -r '.action' <<<"$action")"
        case "$action_type" in
            wait_for)
                if selector="$(jq -er '.id' <<<"$action" 2>/dev/null)"; then
                    wait_for_element id "$selector"
                else
                    selector="$(jq -er '.label' <<<"$action")"
                    wait_for_element label "$selector"
                fi
                ;;
            tap)
                if jq -e '.x != null and .y != null' <<<"$action" >/dev/null; then
                    axe tap --udid "$SCREENSHOT_UDID" \
                        -x "$(jq -r '.x' <<<"$action")" \
                        -y "$(jq -r '.y' <<<"$action")" \
                        --post-delay 0.6
                elif selector="$(jq -er '.id' <<<"$action" 2>/dev/null)"; then
                    axe tap --udid "$SCREENSHOT_UDID" --id "$selector" \
                        --wait-timeout 15 --post-delay 0.6
                else
                    selector="$(jq -er '.label' <<<"$action")"
                    axe tap --udid "$SCREENSHOT_UDID" --label "$selector" \
                        --wait-timeout 15 --post-delay 0.6
                fi
                ;;
            swipe)
                axe swipe --udid "$SCREENSHOT_UDID" \
                    --start-x "$(jq -r '.start_x' <<<"$action")" \
                    --start-y "$(jq -r '.start_y' <<<"$action")" \
                    --end-x "$(jq -r '.end_x' <<<"$action")" \
                    --end-y "$(jq -r '.end_y' <<<"$action")" \
                    --duration "$(jq -r '.duration' <<<"$action")" \
                    --post-delay 0.6
                ;;
            wait)
                sleep "$(jq -r '.seconds' <<<"$action")"
                ;;
            *)
                fail "Unsupported action '$action_type' for $screenshot_id."
                ;;
        esac
    done < <(jq -c --arg id "$screenshot_id" \
        '.screenshots[] | select(.id == $id) | .actions[]' "$MANIFEST")
}

capture_one() {
    local screenshot_id="$1" stage plan output data_container photo_staging photo_index
    stage="$(jq -r --arg id "$screenshot_id" \
        '.screenshots[] | select(.id == $id) | .stage' "$MANIFEST")"
    plan="$TEMP_DIR/$screenshot_id-plan.json"
    output="$RAW_DIR/$screenshot_id.png"

    xcrun simctl terminate "$SCREENSHOT_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl install "$SCREENSHOT_UDID" "$APP_PATH"

    data_container="$(xcrun simctl get_app_container "$SCREENSHOT_UDID" "$BUNDLE_ID" data)"
    photo_staging="$data_container/Library/Application Support/UITests/ShowcaseHoofPhotos"
    mkdir -p "$photo_staging"
    for photo_index in {1..6}; do
        cp "$SHOWCASE_PHOTO_DIR/Hoof-Image-$photo_index.jpeg" "$photo_staging/"
    done

    note "launching $screenshot_id with isolated '$stage' fixture"
    SIMCTL_CHILD_FARRIERFLOW_SCREENSHOT_MODE=1 \
    SIMCTL_CHILD_FARRIERFLOW_UI_TEST_STORE="Screenshot-$screenshot_id" \
    SIMCTL_CHILD_FARRIERFLOW_UI_TEST_SCENARIO=app-store-showcase \
    SIMCTL_CHILD_FARRIERFLOW_UI_TEST_NOW=2026-09-06T13:41:00Z \
    SIMCTL_CHILD_FARRIERFLOW_SCREENSHOT_STAGE="$stage" \
    SIMCTL_CHILD_FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS=full \
    SIMCTL_CHILD_AppleLanguages='(en)' \
    SIMCTL_CHILD_AppleLocale=en_US \
    SIMCTL_CHILD_TZ=America/New_York \
        xcrun simctl launch --terminate-running-process "$SCREENSHOT_UDID" "$BUNDLE_ID" \
        -AppleLanguages '(en)' \
        -AppleLocale en_US \
        -AppleTimeZone America/New_York \
        >/dev/null

    perform_actions "$screenshot_id"

    jq -n --arg bundle "$BUNDLE_ID" --arg out "$RAW_DIR" --arg name "$screenshot_id" \
        '{version: 1, app: {bundle_id: $bundle, output_dir: $out}, steps: [{action: "screenshot", name: $name}]}' \
        >"$plan"
    asc screenshots run --plan "$plan" --udid "$SCREENSHOT_UDID" --output-dir "$RAW_DIR" \
        >/dev/null
    [[ -f "$output" ]] || fail "asc did not create $output"
    verify_dimensions "$output" 1320 2868
    xcrun simctl terminate "$SCREENSHOT_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
}

capture_screenshots() {
    local requested="${1:-all}" screenshot_id
    resolve_screenshot_ids "$requested"
    [[ -d "$APP_PATH" ]] || fail "Missing DEBUG app at $APP_PATH. Run 'scripts/local-screenshots.sh build' first."
    mkdir -p "$RAW_DIR" "$COMPOSED_DIR" "$KOUBOU_OUTPUT_DIR" "$TEMP_DIR"
    if [[ "$requested" == "all" ]]; then
        rm -rf "$RAW_DIR" "$COMPOSED_DIR" "$KOUBOU_OUTPUT_DIR" "$REVIEW_DIR" "$TEMP_DIR"
        mkdir -p "$RAW_DIR" "$COMPOSED_DIR" "$KOUBOU_OUTPUT_DIR" "$TEMP_DIR"
    else
        rm -f "$RAW_DIR/$requested.png" "$COMPOSED_DIR/$requested.png" \
            "$KOUBOU_OUTPUT_DIR/$requested.png"
        rm -rf "$REVIEW_DIR"
    fi
    ensure_screenshot_simulator
    for screenshot_id in "${SCREENSHOT_IDS[@]}"; do
        capture_one "$screenshot_id"
    done
}

verify_dimensions() {
    local path="$1" expected_width="$2" expected_height="$3" dimensions width height
    dimensions="$(sips -g pixelWidth -g pixelHeight "$path")"
    width="$(awk '/pixelWidth:/ {print $2}' <<<"$dimensions")"
    height="$(awk '/pixelHeight:/ {print $2}' <<<"$dimensions")"
    [[ "$width" == "$expected_width" && "$height" == "$expected_height" ]] || fail \
        "$path is ${width}x${height}; expected ${expected_width}x${expected_height}."
}

compose_screenshots() {
    local requested="${1:-all}" screenshot_id raw output config
    resolve_screenshot_ids "$requested"
    for screenshot_id in "${SCREENSHOT_IDS[@]}"; do
        [[ -f "$RAW_DIR/$screenshot_id.png" ]] || fail \
            "Missing raw screenshot $RAW_DIR/$screenshot_id.png. Run capture first."
    done
    mkdir -p "$COMPOSED_DIR" "$KOUBOU_OUTPUT_DIR"
    if [[ "$requested" == "all" ]]; then
        rm -rf "$COMPOSED_DIR" "$KOUBOU_OUTPUT_DIR" "$REVIEW_DIR"
        mkdir -p "$COMPOSED_DIR" "$KOUBOU_OUTPUT_DIR"
    else
        rm -f "$COMPOSED_DIR/$requested.png" "$KOUBOU_OUTPUT_DIR/$requested.png"
        rm -rf "$REVIEW_DIR"
    fi

    for screenshot_id in "${SCREENSHOT_IDS[@]}"; do
        raw="$RAW_DIR/$screenshot_id.png"
        output="$COMPOSED_DIR/$screenshot_id.png"
        config="$KOUBOU_CONFIG_DIR/$screenshot_id.yml"
        note "composing $screenshot_id with isolated Koubou $REQUIRED_KOUBOU_VERSION"
        env PATH="$KOUBOU_BIN:$PATH" asc screenshots frame \
            --config "$config" \
            --output-path "$output" \
            >/dev/null
        [[ -f "$output" ]] || fail "asc/Koubou did not create $output"
        verify_dimensions "$output" 1320 2868
    done
}

generate_review() {
    local screenshot_id
    while IFS= read -r screenshot_id; do
        [[ -f "$RAW_DIR/$screenshot_id.png" ]] || fail \
            "Missing raw screenshot $screenshot_id; capture all ready screenshots first."
        [[ -f "$COMPOSED_DIR/$screenshot_id.png" ]] || fail \
            "Missing composed screenshot $screenshot_id; compose all ready screenshots first."
    done < <(jq -r '.screenshots[] | select(.blocked == null) | .id' "$MANIFEST")
    rm -rf "$REVIEW_DIR"
    mkdir -p "$REVIEW_DIR"
    asc screenshots review-generate \
        --raw-dir "$RAW_DIR" \
        --framed-dir "$COMPOSED_DIR" \
        --output-dir "$REVIEW_DIR" \
        >/dev/null
    [[ -f "$REVIEW_DIR/index.html" ]] || fail "Review bundle was not generated."
    note "review bundle: $REVIEW_DIR/index.html"
}

main() {
    local command="${1:-}" requested="${2:-all}"
    case "$command" in
        doctor)
            [[ $# -eq 1 ]] || fail "doctor does not accept a screenshot id."
            doctor
            ;;
        build)
            [[ $# -eq 1 ]] || fail "build does not accept a screenshot id."
            doctor
            build_app
            ;;
        capture)
            [[ $# -le 2 ]] || fail "capture accepts at most one screenshot id."
            doctor
            capture_screenshots "$requested"
            ;;
        compose)
            [[ $# -le 2 ]] || fail "compose accepts at most one screenshot id."
            doctor
            compose_screenshots "$requested"
            ;;
        review)
            [[ $# -eq 1 ]] || fail "review does not accept a screenshot id."
            doctor
            generate_review
            ;;
        all)
            [[ $# -eq 1 ]] || fail "all does not accept a screenshot id."
            doctor
            build_app
            capture_screenshots all
            compose_screenshots all
            generate_review
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"
