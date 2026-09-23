#!/usr/bin/env python3
"""Pair each preflight edge ACK with a native Dock show in the watcher CSV."""
import csv
import re
import sys
from pathlib import Path

if len(sys.argv) != 4:
    raise SystemExit("usage: validate_edge_burst.py <preflight.log> <watch.log> <cycles>")
preflight_path, watch_log_path, expected_text = map(Path, sys.argv[1:])
expected = int(str(expected_text))
preflight = preflight_path.read_text()
edge_times = [float(value) for value in re.findall(r"^edge uptime=([0-9.]+) .*acknowledged=true", preflight, re.M)]
watch_log = watch_log_path.read_text()
match = re.search(r"file=(\S+\.csv)", watch_log)
if not match:
    raise SystemExit("watcher CSV path missing")
with Path(match.group(1)).open(newline="") as source:
    events = list(csv.DictReader(source))
show_times = [float(row["time"]) for row in events if row["event"] == "show"]
hide_times = [float(row["time"]) for row in events if row["event"] == "hide"]
matched = []
remaining = show_times.copy()
for edge_time in edge_times:
    candidates = [time for time in remaining if edge_time <= time <= edge_time + 0.6]
    if candidates:
        show_time = min(candidates)
        matched.append((edge_time, show_time))
        remaining.remove(show_time)
if len(edge_times) != expected or len(matched) != expected:
    raise SystemExit(
        f"incomplete: edge ACKs={len(edge_times)} paired shows={len(matched)} expected={expected}"
    )
if "overlapGeometrySamples=0" not in watch_log or "overlapCandidateSamples=0" not in watch_log:
    raise SystemExit("watcher recorded an overlap candidate or geometric overlap")
print(
    f"validated cycles={expected} pairedShows={len(matched)} "
    f"totalShows={len(show_times)} totalHides={len(hide_times)} "
    f"maxShowDelayMs={max((show - edge) * 1000 for edge, show in matched):.1f}"
)
