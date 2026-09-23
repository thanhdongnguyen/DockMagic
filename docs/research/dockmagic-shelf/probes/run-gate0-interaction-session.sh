#!/usr/bin/env bash
set -euo pipefail

probe_dir="/private/tmp/dockmagic-shelf-probe"
edge="${1:-bottom}"
duration="${2:-60}"
preflight_mode="${3:-none}"
[[ "$edge" == bottom || "$edge" == left || "$edge" == right ]] || exit 2
[[ "$duration" =~ ^[0-9]+$ ]] && (( duration >= 10 && duration <= 120 )) || exit 2
[[ "$preflight_mode" == none || "$preflight_mode" == edge ]] || exit 2
[[ "$(defaults read com.apple.dock orientation)" == "$edge" ]] || exit 2
original_autohide="$(osascript -e 'tell application "System Events" to get autohide of dock preferences')"
run_dir="$(mktemp -d "$probe_dir/interaction-$edge-XXXXXX")"
watcher_pid=""
preflight_pid=""
cleanup() {
    [[ -z "$watcher_pid" ]] || kill "$watcher_pid" 2>/dev/null || true
    [[ -z "$preflight_pid" ]] || kill "$preflight_pid" 2>/dev/null || true
    killall ReplacementDockProbe 2>/dev/null || true
    osascript -e "tell application \"System Events\" to set autohide of dock preferences to $original_autohide" >/dev/null
}
trap cleanup EXIT INT TERM

printf '%s\n' "$edge" > "$probe_dir/placement.txt"
osascript -e 'tell application "System Events" to set autohide of dock preferences to true'
"$probe_dir/MovePointer" 900 500
open "$probe_dir/ReplacementDockProbe.app"
"$probe_dir/FastDockHandoff" "$duration" "$edge" > "$run_dir/watch.log" 2>&1 &
watcher_pid=$!
for _ in {1..200}; do
    if "$probe_dir/DockWindowDump" | rg -q 'owner=ReplacementDockProbe'; then break; fi
    sleep 0.1
done
"$probe_dir/DockWindowDump" | rg 'owner=ReplacementDockProbe' >/dev/null || exit 3
if [[ "$preflight_mode" == edge ]]; then
    "$probe_dir/DockInputPreflight" "$duration" edge "$edge" > "$run_dir/preflight.log" 2>&1 &
    preflight_pid=$!
    for _ in {1..50}; do
        if rg -q '^ready ' "$run_dir/preflight.log"; then break; fi
        sleep 0.1
    done
    rg -q '^ready ' "$run_dir/preflight.log" || exit 4
fi
echo "ready run_dir=$run_dir edge=$edge duration=$duration preflight=$preflight_mode"
wait "$watcher_pid"
watcher_pid=""
if [[ -n "$preflight_pid" ]]; then
    wait "$preflight_pid"
    preflight_pid=""
    cat "$run_dir/preflight.log"
fi
cat "$run_dir/watch.log"
