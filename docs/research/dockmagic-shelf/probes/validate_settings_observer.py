#!/usr/bin/env python3
"""Validate one bounded Settings AX observer handoff run.

This checks event pairing and CGWindow geometry. It cannot prove that every
composited display frame was free of visible overlap.
"""

import csv
import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: validate_settings_observer.py RUN_DIR EXPECTED_CYCLES", file=sys.stderr)
        return 2
    run_dir = Path(sys.argv[1])
    expected = int(sys.argv[2])
    watch = (run_dir / "watch.log").read_text()
    match = re.search(r"file=(\S+\.csv)", watch)
    if not match:
        print("watcher CSV missing", file=sys.stderr)
        return 2
    rows = list(csv.DictReader(Path(match.group(1)).open()))
    shows = [float(row["time"]) for row in rows if row["event"] == "show"]
    candidates = sum(row["event"] == "overlap-candidate" for row in rows)
    geometry = sum(row["event"] == "overlap-geometry" for row in rows)
    observer_lines = (run_dir / "settings-observer.log").read_text().splitlines()
    events = []
    for line in observer_lines:
        match = re.search(r"^event uptime=([\d.]+).*preempt=status=(-?\d+),ack=(true|false)", line)
        if match:
            events.append((float(match.group(1)), int(match.group(2)), match.group(3) == "true"))
    cycles = (run_dir / "cycles.log").read_text().splitlines()
    validated = sum(re.fullmatch(r"cycle=\d+ autohide=0", line) is not None for line in cycles)
    restored = sum(re.fullmatch(r"cycle=\d+ restoredAutohide=1", line) is not None for line in cycles)
    leads = []
    unpaired = []
    for index, show in enumerate(shows, start=1):
        preceding = [event for event in events if show - 0.5 <= event[0] <= show]
        if not preceding:
            unpaired.append(index)
            continue
        first = preceding[0]
        if first[1] != 0 or not first[2]:
            unpaired.append(index)
            continue
        leads.append((show - first[0]) * 1000)
    print(
        f"expected={expected} cycles={validated} restored={restored} shows={len(shows)} "
        f"ackPaired={len(leads)} unpaired={unpaired} "
        f"leadMinMs={min(leads) if leads else -1:.2f} "
        f"leadMaxMs={max(leads) if leads else -1:.2f} "
        f"overlapCandidate={candidates} overlapGeometry={geometry}"
    )
    return 0 if validated == restored == len(shows) == len(leads) == expected and geometry == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
