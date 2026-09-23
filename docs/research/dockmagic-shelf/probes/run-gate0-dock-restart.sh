#!/usr/bin/env bash
set -euo pipefail

probe_dir="/private/tmp/dockmagic-shelf-probe"
edge="${1:-bottom}"
cycles="${2:-1}"
if [[ "$edge" != "bottom" && "$edge" != "left" && "$edge" != "right" ]] ||
   ! [[ "$cycles" =~ ^[0-9]+$ ]] || (( cycles < 1 || cycles > 10 )); then
    echo "Usage: $0 [bottom|left|right] [1..10]" >&2
    exit 2
fi
[[ "$(defaults read com.apple.dock orientation)" == "$edge" ]] || {
    echo "Apple Dock must already be on the $edge edge." >&2
    exit 2
}
if pgrep -f "$probe_dir/ReplacementDockProbe.app/Contents/MacOS/ReplacementDockProbe" >/dev/null; then
    echo "Close the existing probe first." >&2
    exit 2
fi

original_autohide="$(osascript -e 'tell application "System Events" to get autohide of dock preferences')"
run_dir="$(mktemp -d "$probe_dir/restart-$edge-XXXXXX")"
watcher_pid=""
capture_pid=""
cleanup() {
    [[ -z "$watcher_pid" ]] || kill "$watcher_pid" 2>/dev/null || true
    [[ -z "$capture_pid" ]] || kill "$capture_pid" 2>/dev/null || true
    killall ReplacementDockProbe 2>/dev/null || true
    osascript -e "tell application \"System Events\" to set autohide of dock preferences to $original_autohide" >/dev/null
}
trap cleanup EXIT INT TERM

printf '%s\n' "$edge" > "$probe_dir/placement.txt"
osascript -e 'tell application "System Events" to set autohide of dock preferences to true'
"$probe_dir/MovePointer" 900 500
open "$probe_dir/ReplacementDockProbe.app"
duration=$(( 12 + cycles * 4 ))
"$probe_dir/FastDockHandoff" "$duration" "$edge" > "$run_dir/watch.log" 2>&1 &
watcher_pid=$!

await_probe() {
    for _ in {1..60}; do
        if "$probe_dir/DockWindowDump" | rg -q 'owner=ReplacementDockProbe'; then return 0; fi
        sleep 0.1
    done
    return 1
}
await_probe || { echo "Probe never became visible." >&2; exit 3; }

"$probe_dir/DockFrameCapture" "$edge" "$((duration - 2))" > "$run_dir/capture.log" 2>&1 &
capture_pid=$!
for _ in {1..50}; do
    if rg -q '^ready ' "$run_dir/capture.log"; then break; fi
    sleep 0.1
done
rg -q '^ready ' "$run_dir/capture.log" || { echo "Capture unavailable." >&2; exit 4; }
sleep 0.5

for ((cycle = 1; cycle <= cycles; cycle++)); do
    await_probe || { echo "Probe missing before restart $cycle." >&2; exit 5; }
    printf 'cycle=%s beforeRestart=%s\n' "$cycle" "$(defaults read com.apple.dock autohide)" >> "$run_dir/cycles.log"
    killall Dock
    sleep 1.5
    printf 'cycle=%s afterRestart=%s\n' "$cycle" "$(defaults read com.apple.dock autohide)" >> "$run_dir/cycles.log"
done

wait "$capture_pid"
capture_pid=""
wait "$watcher_pid"
watcher_pid=""
echo "run_dir=$run_dir"
cat "$run_dir/watch.log" "$run_dir/capture.log" "$run_dir/cycles.log"
