#!/usr/bin/env python3
"""Diagnostic pixel scan for the three macOS 26.2 Gate 0 capture crops.

This is calibrated to the probe's fixed tile geometry and the two displays in
the QA report. It looks for the probe's dashed + tile and bright native Dock
icons in a disjoint region. A zero result is not proof that all pixels or all
display frames are overlap-free.
"""

import csv
import sys
from pathlib import Path

import numpy as np
from PIL import Image


REGIONS = {
    "bottom": ((820, 135, 930, 230), (0, 160, 350, 260), (1440, 260)),
    "left": ((20, 600, 112, 695), (0, 0, 120, 200), (320, 1040)),
    "right": ((200, 610, 300, 710), (245, 0, 320, 180), (320, 1040)),
}


def main() -> int:
    if len(sys.argv) != 3 or sys.argv[1] not in REGIONS:
        print("usage: scan_composited_frames.py <bottom|left|right> FRAME_DIRECTORY", file=sys.stderr)
        return 2
    edge, directory = sys.argv[1], Path(sys.argv[2])
    panel_box, native_box, expected_size = REGIONS[edge]
    frames = sorted(directory.glob("*.png"))
    if not frames:
        print("no PNG frames", file=sys.stderr)
        return 2
    with Image.open(frames[0]) as image:
        if image.size != expected_size:
            print(f"unexpected frame size {image.size}; expected {expected_size}", file=sys.stderr)
            return 2
        reference = np.asarray(image.convert("RGB").crop(panel_box)).astype(np.int16)
        if (reference > 220).all(axis=2).sum() < 100:
            print("first frame does not contain the expected + tile; cannot calibrate", file=sys.stderr)
            return 2

    indexed_times = {}
    index_path = directory / "frame-index.csv"
    if index_path.exists():
        with index_path.open(newline="") as handle:
            indexed_times = {
                int(row["frame"]): row["displayUptime"]
                for row in csv.DictReader(handle)
            }
    counts = {"both": 0, "panel": 0, "native": 0, "neither": 0}
    both = []
    for frame in frames:
        with Image.open(frame) as image:
            image = image.convert("RGB")
            panel = np.asarray(image.crop(panel_box)).astype(np.int16)
            native = np.asarray(image.crop(native_box))
        has_panel = np.abs(panel - reference).mean() < 5
        has_native = (native.mean(axis=2) > 150).sum() > 100
        state = "both" if has_panel and has_native else (
            "panel" if has_panel else "native" if has_native else "neither"
        )
        counts[state] += 1
        if state == "both":
            number = int(frame.name.split("-", 1)[0])
            both.append((frame.name, indexed_times.get(number, "unknown")))
    print(f"edge={edge} directory={directory} frames={len(frames)} counts={counts}")
    for name, display_time in both:
        print(f"both frame={name} displayUptime={display_time}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
