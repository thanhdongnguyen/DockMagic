#!/bin/bash
# Isolated asset-catalog compilation and native SwiftUI renders for SVG review.
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_BUILD="$(mktemp -d /private/tmp/dockmagic-svg-pilot.XXXXXX)"
TASK_BUNDLE="$TASK_BUILD/BadgePilot.bundle"
TASK_OUTPUT="$TASK_ROOT/docs/streak-concepts/svg-pilot"
mkdir -p "$TASK_BUNDLE/Contents/Resources" "$TASK_BUILD/module-cache"
node "$TASK_ROOT/script/generate_streak_svg_pilot.mjs" "$TASK_BUILD/Pilot.xcassets"
/usr/bin/plutil -create xml1 "$TASK_BUNDLE/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleIdentifier -string com.dockmagic.badge-vector-pilot "$TASK_BUNDLE/Contents/Info.plist"
/usr/bin/plutil -insert CFBundlePackageType -string BNDL "$TASK_BUNDLE/Contents/Info.plist"
xcrun actool "$TASK_BUILD/Pilot.xcassets" --compile "$TASK_BUNDLE/Contents/Resources" --platform macosx --minimum-deployment-target 14.0 --target-device mac --output-format human-readable-text --warnings --errors
xcrun assetutil --info "$TASK_BUNDLE/Contents/Resources/Assets.car" > "$TASK_OUTPUT/asset-catalog-info.json"
xcrun swiftc -parse-as-library -module-cache-path "$TASK_BUILD/module-cache" "$TASK_ROOT/script/render_streak_svg_pilot.swift" -o "$TASK_BUILD/render-pilot"
"$TASK_BUILD/render-pilot" "$TASK_BUNDLE" "$TASK_OUTPUT"
printf 'Native verification complete. Temporary build: %s\n' "$TASK_BUILD"
