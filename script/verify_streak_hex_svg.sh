#!/bin/bash
# No product asset replacement and no app launch. All build products are temporary.
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_BUILD="$(mktemp -d /private/tmp/dockmagic-hex-svg.XXXXXX)"
TASK_BUNDLE="$TASK_BUILD/HexSVG.bundle"
TASK_OUTPUT="$TASK_ROOT/docs/streak-concepts/hex-svg-v1"
mkdir -p "$TASK_BUNDLE/Contents/Resources" "$TASK_BUILD/module-cache"
node "$TASK_ROOT/script/generate_streak_hex_svg.mjs" "$TASK_BUILD/Hex.xcassets"
/usr/bin/plutil -create xml1 "$TASK_BUNDLE/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleIdentifier -string com.dockmagic.hex-svg-review "$TASK_BUNDLE/Contents/Info.plist"
/usr/bin/plutil -insert CFBundlePackageType -string BNDL "$TASK_BUNDLE/Contents/Info.plist"
xcrun actool "$TASK_BUILD/Hex.xcassets" --compile "$TASK_BUNDLE/Contents/Resources" --platform macosx --minimum-deployment-target 14.0 --target-device mac --output-format human-readable-text --warnings --errors
xcrun assetutil --info "$TASK_BUNDLE/Contents/Resources/Assets.car" > "$TASK_OUTPUT/asset-catalog-info.json"
xcrun swiftc -parse-as-library -module-cache-path "$TASK_BUILD/module-cache" "$TASK_ROOT/script/render_streak_hex_svg.swift" -o "$TASK_BUILD/render-hex"
"$TASK_BUILD/render-hex" "$TASK_BUNDLE" "$TASK_OUTPUT"
node "$TASK_ROOT/script/check_streak_hex_svg.mjs"
printf 'Native verification complete. Temporary build: %s\n' "$TASK_BUILD"
