#!/usr/bin/env bash
set -euo pipefail

probe_dir="/private/tmp/dockmagic-shelf-probe"
trigger="${1:-applescript}"
preempt_marker="$probe_dir/input-preempt.txt"
if [[ "$trigger" != "applescript" && "$trigger" != "settings-ax" && "$trigger" != "settings-pointer" && "$trigger" != "settings-pointer-preempt" && "$trigger" != "settings-pointer-helper" && "$trigger" != "settings-orca-helper" ]]; then
    echo "Usage: $0 [applescript|settings-ax|settings-pointer|settings-pointer-preempt|settings-pointer-helper|settings-orca-helper]" >&2
    exit 2
fi
if [[ "$(defaults read com.apple.dock orientation)" != "right" ]]; then
    echo "Set Apple Dock to the right edge before this diagnostic." >&2
    exit 2
fi
if [[ "$trigger" == "settings-pointer-preempt" || "$trigger" == "settings-pointer-helper" || "$trigger" == "settings-orca-helper" ]] && pgrep -f "$probe_dir/ReplacementDockProbe.app/Contents/MacOS/ReplacementDockProbe" >/dev/null; then
    echo "Close the existing probe before enabling the input tap." >&2
    exit 2
fi
original_autohide="$(osascript -e 'tell application "System Events" to get autohide of dock preferences')"
run_dir="$(mktemp -d "$probe_dir/frame-handoff-XXXXXX")"
watcher_pid=""
capture_pid=""
preflight_pid=""
cleanup() {
    if [[ -n "$watcher_pid" ]]; then kill "$watcher_pid" 2>/dev/null || true; fi
    if [[ -n "$capture_pid" ]]; then kill "$capture_pid" 2>/dev/null || true; fi
    if [[ -n "$preflight_pid" ]]; then kill "$preflight_pid" 2>/dev/null || true; fi
    if [[ "$trigger" == "settings-pointer-preempt" ]]; then
        killall ReplacementDockProbe 2>/dev/null || true
        rm -f "$preempt_marker"
    elif [[ "$trigger" == "settings-pointer-helper" || "$trigger" == "settings-orca-helper" ]]; then
        killall ReplacementDockProbe 2>/dev/null || true
    fi
    osascript -e "tell application \"System Events\" to set autohide of dock preferences to $original_autohide" >/dev/null
}
trap cleanup EXIT INT TERM

printf 'right\n' > "$probe_dir/placement.txt"
watch_seconds=12
capture_seconds=6
if [[ "$trigger" == "settings-orca-helper" ]]; then
    watch_seconds=25
    capture_seconds=18
fi
if [[ "$trigger" == "settings-pointer-preempt" ]]; then
    printf 'settings-click\n' > "$preempt_marker"
fi
osascript -e 'tell application "System Events" to set autohide of dock preferences to true'
open "$probe_dir/ReplacementDockProbe.app"
"$probe_dir/FastDockHandoff" "$watch_seconds" right > "$run_dir/watch.log" 2>&1 &
watcher_pid=$!
for _ in {1..50}; do
    if "$probe_dir/DockWindowDump" | rg -q 'owner=ReplacementDockProbe'; then break; fi
    sleep 0.1
done
if ! "$probe_dir/DockWindowDump" | rg -q 'owner=ReplacementDockProbe'; then
    echo "Probe never became visible; refusing to run capture." >&2
    exit 3
fi

if [[ "$trigger" == "settings-pointer-helper" || "$trigger" == "settings-orca-helper" ]]; then
    open -a 'System Settings'
    "$probe_dir/DockInputPreflight" "$watch_seconds" > "$run_dir/input-preflight.log" 2>&1 &
    preflight_pid=$!
    for _ in {1..50}; do
        if rg -q '^ready ' "$run_dir/input-preflight.log"; then break; fi
        sleep 0.1
    done
    if ! rg -q '^ready ' "$run_dir/input-preflight.log"; then
        echo "Input preflight did not start." >&2
        exit 5
    fi
fi

"$probe_dir/DockFrameCapture" right "$capture_seconds" > "$run_dir/capture.log" 2>&1 &
capture_pid=$!
for _ in {1..50}; do
    if rg -q '^ready ' "$run_dir/capture.log"; then break; fi
    sleep 0.1
done
if ! rg -q '^ready ' "$run_dir/capture.log"; then
    echo "Frame capture did not start." >&2
    exit 4
fi
sleep 0.6
if [[ "$trigger" == "settings-orca-helper" ]]; then
    open -a 'System Settings'
    window_id="$(orca computer list-windows --app com.apple.systempreferences --json | jq -r '.result.windows[] | select(.title == "Desktop & Dock") | .id' | head -1)"
    [[ -n "$window_id" ]] || { echo "Desktop & Dock window missing" >&2; exit 6; }
    orca computer get-app-state --app com.apple.systempreferences --window-id "$window_id" --no-screenshot --json > "$run_dir/settings-before.json"
    jq -e '.result.snapshot.window.x == 790 and .result.snapshot.window.y == 48 and (.result.snapshot.treeText | contains("Automatically hide and show the Dock"))' "$run_dir/settings-before.json" >/dev/null
    orca computer click --app com.apple.systempreferences --window-id "$window_id" --x 675 --y 346 --no-screenshot --json > "$run_dir/settings-orca-click.json"
    jq -e '.ok == true' "$run_dir/settings-orca-click.json" >/dev/null
    sleep 0.4
    osascript -e 'tell application "System Events" to set autohide of dock preferences to true'
elif [[ "$trigger" == "settings-pointer" || "$trigger" == "settings-pointer-preempt" || "$trigger" == "settings-pointer-helper" ]]; then
    open -a 'System Settings'
    sleep 0.2
    if [[ "$trigger" == "settings-pointer-helper" ]]; then
        "$probe_dir/SettingsDockAX" --click-slow > "$run_dir/settings-pointer.log"
    else
        "$probe_dir/SettingsDockAX" --click > "$run_dir/settings-pointer.log"
    fi
elif [[ "$trigger" == "settings-ax" ]]; then
    "$probe_dir/SettingsDockAX" --press > "$run_dir/settings-ax.log"
else
    osascript -e 'tell application "System Events" to set autohide of dock preferences to false'
fi
wait "$capture_pid"
capture_pid=""
wait "$watcher_pid"
watcher_pid=""
if [[ -n "$preflight_pid" ]]; then
    wait "$preflight_pid"
    preflight_pid=""
fi
echo "run_dir=$run_dir"
echo "trigger=$trigger"
cat "$run_dir/capture.log"
cat "$run_dir/watch.log"
if [[ -f "$run_dir/settings-ax.log" ]]; then cat "$run_dir/settings-ax.log"; fi
if [[ -f "$run_dir/settings-pointer.log" ]]; then cat "$run_dir/settings-pointer.log"; fi
if [[ -f "$run_dir/input-preflight.log" ]]; then cat "$run_dir/input-preflight.log"; fi
if [[ -f "$run_dir/settings-orca-click.json" ]]; then jq '{ok, action: .result.action}' "$run_dir/settings-orca-click.json"; fi
