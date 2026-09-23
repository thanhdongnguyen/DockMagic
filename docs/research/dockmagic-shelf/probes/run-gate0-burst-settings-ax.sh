#!/usr/bin/env bash
set -euo pipefail

probe_dir="/private/tmp/dockmagic-shelf-probe"
mode="${1:-ax}"
edge="${2:-right}"
cycles="${3:-10}"
if [[ "$mode" != "ax" && "$mode" != "ax-observer" && "$mode" != "pointer" && "$mode" != "pointer-slow" && "$mode" != "pointer-helper" &&
      "$mode" != "applescript" && "$mode" != "applescript-observer" && "$mode" != "orca-helper" && "$mode" != "orca-no-helper" ]]; then
    echo "Usage: $0 [ax|ax-observer|pointer|pointer-slow|pointer-helper|applescript|applescript-observer|orca-helper|orca-no-helper] [bottom|left|right]" >&2
    exit 2
fi
if [[ "$edge" != "bottom" && "$edge" != "left" && "$edge" != "right" ]]; then
    echo "Unknown Dock edge: $edge" >&2
    exit 2
fi
[[ "$cycles" =~ ^[0-9]+$ ]] && (( cycles >= 1 && cycles <= 24 )) || {
    echo "Cycle count must be 1–24." >&2
    exit 2
}
[[ "$(defaults read com.apple.dock orientation)" == "$edge" ]] || {
    echo "This diagnostic requires Apple Dock on the $edge edge." >&2
    exit 2
}
original_autohide="$(osascript -e 'tell application "System Events" to get autohide of dock preferences')"
if [[ "$mode" == orca-* ]] && pgrep -f "$probe_dir/ReplacementDockProbe.app/Contents/MacOS/ReplacementDockProbe" >/dev/null; then
    echo "Close the existing probe before starting this diagnostic." >&2
    exit 2
fi
run_dir="$(mktemp -d "$probe_dir/burst-settings-$edge-XXXXXX")"
watcher_pid=""
capture_pid=""
preflight_pid=""
observer_pid=""
cleanup() {
    if [[ -n "$watcher_pid" ]]; then kill "$watcher_pid" 2>/dev/null || true; fi
    if [[ -n "$capture_pid" ]]; then kill "$capture_pid" 2>/dev/null || true; fi
    if [[ -n "$preflight_pid" ]]; then kill "$preflight_pid" 2>/dev/null || true; fi
    if [[ -n "$observer_pid" ]]; then kill "$observer_pid" 2>/dev/null || true; fi
    killall ReplacementDockProbe 2>/dev/null || true
    osascript -e "tell application \"System Events\" to set autohide of dock preferences to $original_autohide" >/dev/null
}
trap cleanup EXIT INT TERM

printf '%s\n' "$edge" > "$probe_dir/placement.txt"
osascript -e 'tell application "System Events" to set autohide of dock preferences to true'
# A pointer left at (0,0) keeps the bottom-edge panel hidden by its edge-yield
# policy, so move it to the center before checking that the panel can appear.
"$probe_dir/MovePointer" 900 500
open "$probe_dir/ReplacementDockProbe.app"
watch_seconds=30
capture_seconds=25
if [[ "$mode" == orca-* ]]; then
    watch_seconds=60
    capture_seconds=55
elif [[ "$mode" == pointer-helper ]]; then
    watch_seconds=35
    capture_seconds=30
elif [[ "$mode" == ax-observer || "$mode" == applescript-observer ]]; then
    watch_seconds=$(( cycles * 3 + 30 ))
    (( watch_seconds < 60 )) && watch_seconds=60
    capture_seconds=$(( watch_seconds - 5 ))
    (( capture_seconds > 75 )) && capture_seconds=75
fi
"$probe_dir/FastDockHandoff" "$watch_seconds" "$edge" > "$run_dir/watch.log" 2>&1 &
watcher_pid=$!

await_probe() {
    for _ in {1..40}; do
        if "$probe_dir/DockWindowDump" | rg -q 'owner=ReplacementDockProbe'; then return 0; fi
        sleep 0.1
    done
    return 1
}
await_probe || { echo "Probe did not appear." >&2; exit 3; }
if [[ "$mode" == ax-observer || "$mode" == applescript-observer ]]; then
    "$probe_dir/SettingsValueObserver" "$watch_seconds" --preempt > "$run_dir/settings-observer.log" 2>&1 &
    observer_pid=$!
    for _ in {1..50}; do
        if rg -q '^ready .* addStatus=0 ' "$run_dir/settings-observer.log"; then break; fi
        sleep 0.1
    done
    rg -q '^ready .* addStatus=0 ' "$run_dir/settings-observer.log" || {
        echo "Settings AX observer unavailable." >&2
        exit 11
    }
fi
if [[ "$mode" == orca-* || "$mode" == pointer-helper ]]; then
    open -a 'System Settings'
fi
if [[ "$mode" == "orca-helper" || "$mode" == "pointer-helper" ]]; then
    preflight_mode=checkbox
    if [[ "$mode" == pointer-helper ]]; then preflight_mode=all; fi
    "$probe_dir/DockInputPreflight" "$watch_seconds" "$preflight_mode" "$edge" > "$run_dir/input-preflight.log" 2>&1 &
    preflight_pid=$!
    for _ in {1..50}; do
        if rg -q '^ready ' "$run_dir/input-preflight.log"; then break; fi
        sleep 0.1
    done
    rg -q '^ready ' "$run_dir/input-preflight.log" || { echo "Input helper unavailable." >&2; exit 6; }
fi
if [[ "$mode" == orca-* ]]; then
    window_id="$(orca computer list-windows --app com.apple.systempreferences --json | jq -r '.result.windows[] | select(.title == "Desktop & Dock") | .id' | head -1)"
    [[ -n "$window_id" ]] || { echo "Desktop & Dock window missing." >&2; exit 7; }
fi
"$probe_dir/DockFrameCapture" "$edge" "$capture_seconds" > "$run_dir/capture.log" 2>&1 &
capture_pid=$!
for _ in {1..40}; do
    if rg -q '^ready ' "$run_dir/capture.log"; then break; fi
    sleep 0.1
done
rg -q '^ready ' "$run_dir/capture.log" || { echo "Capture did not start." >&2; exit 4; }
sleep 0.5
if [[ "$mode" == pointer-helper ]]; then
    case "$edge" in
        bottom) "$probe_dir/MovePointer" 986 1079 ;;
        left) "$probe_dir/MovePointer" -1511 610 ;;
        right) "$probe_dir/MovePointer" 1919 585 ;;
    esac
    sleep 0.9
    "$probe_dir/MovePointer" 900 500
    sleep 1.3
fi

for ((cycle = 1; cycle <= cycles; cycle++)); do
    await_probe || { echo "Probe missing at cycle $cycle" >&2; exit 5; }
    if [[ "$mode" == orca-* ]]; then
        open -a 'System Settings'
        orca computer get-app-state --app com.apple.systempreferences --window-id "$window_id" --no-screenshot --json > "$run_dir/settings-before-$cycle.json"
        jq -e '.result.snapshot.window.x == 790 and .result.snapshot.window.y == 48 and (.result.snapshot.treeText | contains("Automatically hide and show the Dock"))' "$run_dir/settings-before-$cycle.json" >/dev/null
        orca computer click --app com.apple.systempreferences --window-id "$window_id" --x 675 --y 346 --no-screenshot --json > "$run_dir/settings-$cycle.json" || true
        if ! jq -e '.ok == true' "$run_dir/settings-$cycle.json" >/dev/null; then
            jq -e '.error.code == "window_not_focused"' "$run_dir/settings-$cycle.json" >/dev/null || exit 9
            open -a 'System Settings'
            orca computer get-app-state --app com.apple.systempreferences --window-id "$window_id" --restore-window --no-screenshot --json > "$run_dir/settings-retry-before-$cycle.json" || true
            orca computer click --app com.apple.systempreferences --window-id "$window_id" --x 675 --y 346 --restore-window --no-screenshot --json > "$run_dir/settings-retry-$cycle.json" || true
            jq -e '.ok == true' "$run_dir/settings-retry-$cycle.json" >/dev/null || exit 10
        fi
    elif [[ "$mode" == "applescript" || "$mode" == "applescript-observer" ]]; then
        osascript -e 'tell application "System Events" to set autohide of dock preferences to false'
    elif [[ "$mode" == "pointer" || "$mode" == "pointer-slow" || "$mode" == "pointer-helper" ]]; then
        open -a 'System Settings'
        click_mode=--click
        if [[ "$mode" == pointer-helper || "$mode" == pointer-slow ]]; then click_mode=--click-slow; fi
        "$probe_dir/SettingsDockAX" "$click_mode" > "$run_dir/settings-$cycle.log"
    else
        "$probe_dir/SettingsDockAX" --press > "$run_dir/settings-$cycle.log"
    fi
    for _ in {1..40}; do
        if [[ "$(defaults read com.apple.dock autohide)" == "0" ]]; then break; fi
        sleep 0.05
    done
    [[ "$(defaults read com.apple.dock autohide)" == "0" ]] || {
        echo "Cycle $cycle did not disable auto-hide." >&2
        exit 8
    }
    printf 'cycle=%s autohide=0\n' "$cycle" >> "$run_dir/cycles.log"
    if [[ "$mode" == orca-* ]]; then sleep 0.8; else sleep 0.25; fi
    osascript -e 'tell application "System Events" to set autohide of dock preferences to true'
    if [[ "$mode" == orca-* ]]; then sleep 0.8; else sleep 0.25; fi
    printf 'cycle=%s restoredAutohide=%s\n' "$cycle" "$(defaults read com.apple.dock autohide)" >> "$run_dir/cycles.log"
done

wait "$capture_pid"
capture_pid=""
wait "$watcher_pid"
watcher_pid=""
if [[ -n "$preflight_pid" ]]; then
    wait "$preflight_pid"
    preflight_pid=""
fi
if [[ -n "$observer_pid" ]]; then
    wait "$observer_pid"
    observer_pid=""
fi
echo "run_dir=$run_dir"
echo "mode=$mode"
echo "edge=$edge"
cat "$run_dir/capture.log"
cat "$run_dir/watch.log"
cat "$run_dir/cycles.log"
if [[ -f "$run_dir/input-preflight.log" ]]; then cat "$run_dir/input-preflight.log"; fi
if [[ -f "$run_dir/settings-observer.log" ]]; then cat "$run_dir/settings-observer.log"; fi
