#!/usr/bin/env bash
set -euo pipefail

edge="${1:-bottom}"
cycles="${2:-1}"
span="${3:-inside}"
case "$edge" in bottom|left|right) ;; *) echo "edge must be bottom, left, or right" >&2; exit 2 ;; esac
case "$span" in inside|outside) ;; *) echo "span must be inside or outside" >&2; exit 2 ;; esac
if [[ ! "$cycles" =~ ^[0-9]+$ ]] || (( cycles < 1 || cycles > 100 )); then
    echo "cycles must be an integer from 1 to 100" >&2
    exit 2
fi

if [[ "$(defaults read com.apple.dock autohide 2>/dev/null)" != "1" ]]; then
    echo "Apple Dock auto-hide must be enabled before this test" >&2
    exit 2
fi
if [[ "$(defaults read com.apple.dock orientation 2>/dev/null)" != "$edge" ]]; then
    echo "Apple Dock orientation must be $edge before this test" >&2
    exit 2
fi

probe_root="/private/tmp/dockmagic-shelf-probe"
products="$probe_root/DerivedData/Build/Products"
base_runs=("$products"/DockMagic_DockMagic_macosx*.xctestrun)
if [[ ! -f "${base_runs[0]}" ]]; then
    echo "Build the DockMagic UI test first with xcodebuild build-for-testing" >&2
    exit 2
fi
test_run="$products/DockMagic-Gate0-${edge}-${cycles}-${span}.xctestrun"
python3 - "${base_runs[0]}" "$test_run" "$edge" "$cycles" "$span" <<'PY'
import plistlib
import sys

source, destination, edge, cycles, span = sys.argv[1:]
with open(source, "rb") as stream:
    data = plistlib.load(stream)
for configuration in data["TestConfigurations"]:
    for target in configuration["TestTargets"]:
        if target.get("ProductModuleName") != "DockMagicUITests":
            continue
        for key in ("EnvironmentVariables", "TestingEnvironmentVariables"):
            target.setdefault(key, {}).update({
                "DockMagicCustomDockGate0UITest": "1",
                "DockMagicGate0Edge": edge,
                "DockMagicGate0Cycles": cycles,
                "DockMagicGate0Span": span,
            })
with open(destination, "wb") as stream:
    plistlib.dump(data, stream)
PY

result="$probe_root/Gate0-${edge}-${cycles}-${span}-$(date +%Y%m%d-%H%M%S).xcresult"
echo "Running $cycles physical Dock handoff cycle(s) at $edge/$span; result: $result"
xcodebuild test-without-building \
    -xctestrun "$test_run" \
    -destination 'platform=macOS' \
    -only-testing:DockMagicUITests/DockMagicUITests/testCustomDockProbeYieldsToNativeDockAtPhysicalEdge \
    -resultBundlePath "$result" \
    -quiet
