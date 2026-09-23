#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
marker="/private/tmp/dockmagic-custom-dock-geometry.env"
original_autohide="$(defaults read com.apple.dock autohide 2>/dev/null || echo 0)"
original_orientation="$(defaults read com.apple.dock orientation 2>/dev/null || echo bottom)"
original_tilesize="$(defaults read com.apple.dock tilesize 2>/dev/null || echo 44)"
original_magnification="$(defaults read com.apple.dock magnification 2>/dev/null || echo 0)"
original_delay_present=0
original_time_modifier_present=0
if original_delay="$(defaults read com.apple.dock autohide-delay 2>/dev/null)"; then
  original_delay_present=1
fi
if original_time_modifier="$(defaults read com.apple.dock autohide-time-modifier 2>/dev/null)"; then
  original_time_modifier_present=1
fi
if [[ "$original_autohide" == "1" || "$original_autohide" == "true" ]]; then
  original_autohide_bool="true"
else
  original_autohide_bool="false"
fi
if [[ "$original_magnification" == "1" || "$original_magnification" == "true" ]]; then
  original_magnification_bool="true"
else
  original_magnification_bool="false"
fi

restore_dock() {
  set +e
  defaults write com.apple.dock autohide -bool "$original_autohide_bool"
  defaults write com.apple.dock orientation -string "$original_orientation"
  defaults write com.apple.dock tilesize -float "$original_tilesize"
  defaults write com.apple.dock magnification -bool "$original_magnification_bool"
  if (( original_delay_present )); then
    defaults write com.apple.dock autohide-delay -float "$original_delay"
  else
    defaults delete com.apple.dock autohide-delay >/dev/null 2>&1 || true
  fi
  if (( original_time_modifier_present )); then
    defaults write com.apple.dock autohide-time-modifier -float "$original_time_modifier"
  else
    defaults delete com.apple.dock autohide-time-modifier >/dev/null 2>&1 || true
  fi
  killall Dock >/dev/null 2>&1 || true
  rm -f "$marker"
}

trap restore_dock EXIT INT TERM
cd "$repo_root"
run_id="$(date '+%Y%m%d-%H%M%S')"
result_root="/private/tmp/dockmagic-custom-dock-geometry-${run_id}"
mkdir -p "$result_root"
failures=0
for edge in bottom left right; do
  for size in 30 44 60; do
    defaults write com.apple.dock autohide -bool false
    defaults write com.apple.dock orientation -string "$edge"
    defaults write com.apple.dock tilesize -float "$size"
    defaults write com.apple.dock magnification -bool false
    killall Dock >/dev/null 2>&1 || true
    sleep 1
    printf 'edge=%s\nsize=%s\n' "$edge" "$size" > "$marker"
    if ! xcodebuild \
      -project DockMagic/DockMagic.xcodeproj \
      -scheme DockMagic \
      -configuration Debug \
      -derivedDataPath /private/tmp/dockmagic-shelf-full-qa \
      -clonedSourcePackagesDirPath /private/tmp/DockMagicWeatherColorsBuild/SourcePackages \
      -disableAutomaticPackageResolution \
      -resultBundlePath "$result_root/${edge}-${size}.xcresult" \
      test \
      -only-testing:DockMagicUITests/DockMagicUITests/testNativeAndCustomDockGeometryVisualMatrix \
      -quiet; then
      (( failures += 1 ))
    fi
  done
done
echo "Geometry result bundles: $result_root"
(( failures == 0 ))
