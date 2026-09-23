#!/bin/zsh

set -euo pipefail

edge="${1:-bottom}"
cycles="${2:-100}"

if [[ "$edge" != "bottom" && "$edge" != "left" && "$edge" != "right" ]]; then
  echo "edge must be bottom, left, or right" >&2
  exit 2
fi

if ! [[ "$cycles" =~ '^[0-9]+$' ]] || (( cycles < 1 || cycles > 100 )); then
  echo "cycles must be between 1 and 100" >&2
  exit 2
fi

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
original_autohide="$(defaults read com.apple.dock autohide 2>/dev/null || echo 0)"
original_orientation="$(defaults read com.apple.dock orientation 2>/dev/null || echo bottom)"
original_delay_present=0
original_time_modifier_present=0
if original_delay="$(defaults read com.apple.dock autohide-delay 2>/dev/null)"; then
  original_delay_present=1
fi
if original_time_modifier="$(defaults read com.apple.dock autohide-time-modifier 2>/dev/null)"; then
  original_time_modifier_present=1
fi
harness_file="/private/tmp/dockmagic-custom-dock-gate0.env"
if [[ "$original_autohide" == "1" || "$original_autohide" == "true" ]]; then
  original_autohide_bool="true"
else
  original_autohide_bool="false"
fi

restore_dock() {
  set +e
  defaults write com.apple.dock autohide -bool "$original_autohide_bool"
  defaults write com.apple.dock orientation -string "$original_orientation"
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
  rm -f "$harness_file"
}

trap restore_dock EXIT INT TERM

defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock orientation -string "$edge"
# Keep the stress matrix practical while still exercising the production
# handoff path. The trap restores both values, including whether each key was
# absent before the run. A separate short baseline uses Apple's default timing.
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.05
killall Dock >/dev/null 2>&1 || true
sleep 1
printf 'edge=%s\ncycles=%s\n' "$edge" "$cycles" > "$harness_file"

cd "$repo_root"
xcodebuild \
  -project DockMagic/DockMagic.xcodeproj \
  -scheme DockMagic \
  -configuration Debug \
  -derivedDataPath /private/tmp/dockmagic-shelf-full-qa \
  -clonedSourcePackagesDirPath /private/tmp/DockMagicWeatherColorsBuild/SourcePackages \
  -disableAutomaticPackageResolution \
  test \
  -only-testing:DockMagicUITests/DockMagicUITests/testCustomDockYieldsToNativeDockAtPhysicalEdge \
  -quiet
