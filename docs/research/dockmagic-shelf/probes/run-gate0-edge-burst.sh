#!/usr/bin/env bash
set -euo pipefail

probe_dir="/private/tmp/dockmagic-shelf-probe"
edge="${1:-bottom}"
cycles="${2:-15}"
[[ "$edge" == bottom || "$edge" == left || "$edge" == right ]] || exit 2
[[ "$cycles" =~ ^[0-9]+$ ]] && (( cycles >= 1 && cycles <= 24 )) || exit 2

original_orientation="$(defaults read com.apple.dock orientation)"
original_autohide="$(osascript -e 'tell application "System Events" to get autohide of dock preferences')"
run_dir="$(mktemp -d "$probe_dir/edge-burst-$edge-XXXXXX")"
watcher_pid=""
preflight_pid=""
capture_pid=""
cleanup() {
    [[ -z "$watcher_pid" ]] || kill "$watcher_pid" 2>/dev/null || true
    [[ -z "$preflight_pid" ]] || kill "$preflight_pid" 2>/dev/null || true
    [[ -z "$capture_pid" ]] || kill "$capture_pid" 2>/dev/null || true
    killall ReplacementDockProbe 2>/dev/null || true
    osascript -e "tell application \"System Events\" to set autohide of dock preferences to $original_autohide" >/dev/null
    if [[ "$original_orientation" != "$edge" ]]; then
        defaults write com.apple.dock orientation -string "$original_orientation"
        killall Dock 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

if [[ "$original_orientation" != "$edge" ]]; then
    defaults write com.apple.dock orientation -string "$edge"
    killall Dock
    sleep 1
fi
printf '%s\n' "$edge" > "$probe_dir/placement.txt"
osascript -e 'tell application "System Events" to set autohide of dock preferences to true'
"$probe_dir/MovePointer" 900 500
open "$probe_dir/ReplacementDockProbe.app"

watch_duration=$((cycles * 3 + 25))
test_duration=$((cycles * 3 + 5))
if (( test_duration > 75 )); then test_duration=75; fi
"$probe_dir/FastDockHandoff" "$watch_duration" "$edge" > "$run_dir/watch.log" 2>&1 &
watcher_pid=$!
for _ in {1..200}; do
    if "$probe_dir/DockWindowDump" | rg -q 'owner=ReplacementDockProbe'; then break; fi
    sleep 0.1
done
"$probe_dir/DockWindowDump" | rg 'owner=ReplacementDockProbe' >/dev/null || exit 3
"$probe_dir/DockInputPreflight" "$test_duration" edge "$edge" > "$run_dir/preflight.log" 2>&1 &
preflight_pid=$!
for _ in {1..50}; do
    if rg -q '^ready ' "$run_dir/preflight.log"; then break; fi
    sleep 0.1
done
rg -q '^ready ' "$run_dir/preflight.log" || exit 4
"$probe_dir/DockFrameCapture" "$edge" "$test_duration" > "$run_dir/capture.log" 2>&1 &
capture_pid=$!
for _ in {1..50}; do
    if rg -q '^ready ' "$run_dir/capture.log"; then break; fi
    sleep 0.1
done
rg -q '^ready ' "$run_dir/capture.log" || exit 5
sleep 0.5

case "$edge" in
    bottom) near_x=986; near_y=1060; edge_x=986; edge_y=1079 ;;
    left) near_x=-1490; near_y=610; edge_x=-1511; edge_y=610 ;;
    right) near_x=1900; near_y=585; edge_x=1919; edge_y=585 ;;
esac
for ((cycle = 1; cycle <= cycles; cycle++)); do
    ready=false
    for _ in {1..60}; do
        "$probe_dir/MovePointer" 900 500
        sleep 0.08
        pointer="$("$probe_dir/PointerPosition")"
        windows="$("$probe_dir/DockWindowDump")"
        if [[ "$pointer" == '900 500' ]] &&
           printf '%s\n' "$windows" | rg -q '^owner=ReplacementDockProbe ' &&
           ! printf '%s\n' "$windows" | rg -q '^owner=Dock '; then
            ready=true
            break
        fi
    done
    [[ "$ready" == true ]] || { echo "Dock did not return to hidden state at cycle $cycle" >&2; exit 8; }
    "$probe_dir/MovePointer" "$near_x" "$near_y"
    sleep 0.06
    "$probe_dir/MovePointer" "$edge_x" "$edge_y"
    sleep 0.9
    pointer="$("$probe_dir/PointerPosition")"
    windows="$("$probe_dir/DockWindowDump")"
    [[ "$pointer" == "$edge_x $edge_y" ]] || {
        echo "Pointer missed edge at cycle $cycle: $pointer" >&2
        exit 9
    }
    printf '%s\n' "$windows" | rg -q '^owner=Dock ' || {
        echo "Apple Dock did not appear at cycle $cycle" >&2
        exit 10
    }
    "$probe_dir/MovePointer" 900 500
    sleep 1.3
    printf 'cycle=%s pointer=%s dock=visible\n' "$cycle" "$pointer" >> "$run_dir/cycles.log"
done

wait "$watcher_pid"
watcher_pid=""
wait "$preflight_pid"
preflight_pid=""
wait "$capture_pid"
capture_pid=""

intercepts="$(rg -c '^edge uptime=' "$run_dir/preflight.log" || true)"
[[ "$intercepts" == "$cycles" ]] || {
    echo "Expected $cycles edge intercepts, observed $intercepts" >&2
    exit 6
}
shows="$(rg -c ",show," "$probe_dir/fast-handoff.csv" || true)"
[[ "$shows" -ge "$cycles" ]] || {
    echo "Expected $cycles native Dock shows, observed $shows" >&2
    exit 7
}
echo "run_dir=$run_dir edge=$edge cycles=$cycles intercepts=$intercepts shows=$shows"
tail -n 1 "$run_dir/preflight.log"
python3 "$(dirname "$0")/validate_edge_burst.py" "$run_dir/preflight.log" "$run_dir/watch.log" "$cycles"
cat "$run_dir/watch.log"
cat "$run_dir/capture.log"
