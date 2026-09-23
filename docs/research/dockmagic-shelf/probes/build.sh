#!/usr/bin/env bash
set -euo pipefail

probe_source_dir="$(cd "$(dirname "$0")" && pwd)"
probe_output_dir="${1:-/private/tmp/dockmagic-shelf-probe}"
probe_app_dir="$probe_output_dir/ReplacementDockProbe.app/Contents"

mkdir -p "$probe_app_dir/MacOS" "$probe_output_dir/module-cache"
cp "$probe_source_dir/Info.plist" "$probe_app_dir/Info.plist"
if [[ ! -e "$probe_output_dir/placement.txt" ]]; then
    printf 'bottom\n' > "$probe_output_dir/placement.txt"
fi

for probe_name in ReplacementDockProbe FastDockHandoff FrontmostFullScreen SetWindowPosition DockWindowDump DockAXObserverProbe PointerTrace MovePointer PointerPosition PointerClick ProbeAXAction DockFrameCapture SettingsDockAX SettingsValueObserver DockInputPreflight; do
    output_path="$probe_output_dir/$probe_name"
    if [[ "$probe_name" == "ReplacementDockProbe" ]]; then
        output_path="$probe_app_dir/MacOS/$probe_name"
    fi
    if [[ "$probe_name" == "DockFrameCapture" ]]; then
        swiftc -parse-as-library -module-cache-path "$probe_output_dir/module-cache" \
            "$probe_source_dir/$probe_name.swift" -o "$output_path"
    else
        swiftc -module-cache-path "$probe_output_dir/module-cache" \
            "$probe_source_dir/$probe_name.swift" -o "$output_path"
    fi
done
