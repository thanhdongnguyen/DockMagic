#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="DockMagic"
BUNDLE_ID="com.hypevibe.DockMagic"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/DockMagic/DockMagic.xcodeproj"
DERIVED_DATA_PATH="${DOCKMAGIC_DERIVED_DATA_PATH:-$ROOT_DIR/.derivedData}"
SOURCE_PACKAGES_PATH="${DOCKMAGIC_SOURCE_PACKAGES_PATH:-$DERIVED_DATA_PATH/SourcePackages}"
APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

running_app_pids() {
  # A shared process name is not sufficient: Xcode and parallel verification
  # builds can run other DockMagic bundles at the same time. Only manage the
  # executable produced by this script's DerivedData path.
  while IFS= read -r app_pid; do
    local executable
    executable="$(ps -p "$app_pid" -o comm= 2>/dev/null || true)"
    if [[ "$executable" == "$APP_BINARY" ]]; then
      printf '%s\n' "$app_pid"
    fi
  done < <(pgrep -x "$APP_NAME" || true)
}

stop_running_app() {
  while read -r app_pid; do
    kill "$app_pid" >/dev/null 2>&1 || true
  done < <(running_app_pids)
}

build_app() {
  rm -rf "$APP_BUNDLE"
  local build_args=(-project "$PROJECT_PATH" -scheme "$APP_NAME"
    -configuration Debug -destination "platform=macOS"
    -derivedDataPath "$DERIVED_DATA_PATH"
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH")
  if [[ -n "${DOCKMAGIC_XCCONFIG_PATH:-}" ]]; then
    build_args+=(-xcconfig "$DOCKMAGIC_XCCONFIG_PATH")
  fi
  xcodebuild \
    "${build_args[@]}" build
}

open_app() {
  local launch_args=(-n)
  local key
  # Opt-in QA composition only; never forward arbitrary environment/secrets.
  # An absent Grok fixture key must remain absent for real-local verification.
  for key in DockMagicUITesting DockMagicUITestDefaultsSuite DockMagicUITestGrok DOCKMAGIC_EXPERIMENTAL_GROK DockMagicMaiaGallery DockMagicMaiaAppearance DockMagicUITestBinanceFixtures DockMagicUITestCalendar DockMagicUITestNowPlaying DockMagicUITestAugment; do
    if [[ -n "${!key:-}" ]]; then launch_args+=(--env "$key=${!key}"); fi
  done
  /usr/bin/open "${launch_args[@]}" "$APP_BUNDLE"
}

stop_running_app
build_app

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    open_app
    sleep 1
    APP_PID="$(running_app_pids | tail -n 1)"
    exec lldb -p "$APP_PID"
    ;;
  --logs|logs)
    open_app
    exec /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    exec /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    for _ in {1..20}; do
      if [[ -n "$(running_app_pids)" ]]; then
        exit 0
      fi
      sleep 0.25
    done
    echo "$APP_NAME did not stay running after launch." >&2
    exit 1
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
