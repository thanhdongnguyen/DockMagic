#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <version> <updates-directory> <generate-appcast-path>" >&2
    exit 64
fi

version="$1"
updates_directory="$2"
generate_appcast="$3"
release_name="DockMagic-${version}.dmg"
release_path="${updates_directory}/${release_name}"
appcast_path="${updates_directory}/appcast.xml"
download_prefix="https://github.com/thanhdongnguyen/DockMagic/releases/download/v${version}/"
release_url="https://github.com/thanhdongnguyen/DockMagic/releases/tag/v${version}"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "Invalid semantic version: ${version}" >&2
    exit 65
fi

if [[ ! -d "$updates_directory" ]]; then
    echo "Updates directory does not exist: ${updates_directory}" >&2
    exit 66
fi

if [[ ! -f "$release_path" ]]; then
    echo "Expected release archive is missing: ${release_path}" >&2
    exit 66
fi

if [[ ! -x "$generate_appcast" ]]; then
    echo "Sparkle generate_appcast tool is not executable: ${generate_appcast}" >&2
    exit 69
fi

"$generate_appcast" \
    --account DockMagic \
    --download-url-prefix "$download_prefix" \
    --full-release-notes-url "$release_url" \
    --link "https://github.com/thanhdongnguyen/DockMagic" \
    "$updates_directory"

if [[ ! -f "$appcast_path" ]]; then
    echo "Sparkle did not generate ${appcast_path}" >&2
    exit 70
fi

if ! rg --fixed-strings "${download_prefix}${release_name}" "$appcast_path" >/dev/null; then
    echo "Generated appcast does not reference the immutable release asset URL." >&2
    exit 70
fi

if ! rg --fixed-strings \
    "<sparkle:shortVersionString>${version}</sparkle:shortVersionString>" \
    "$appcast_path" >/dev/null; then
    echo "Generated appcast version does not match ${version}." >&2
    exit 70
fi

if ! rg --fixed-strings "sparkle:edSignature" "$appcast_path" >/dev/null; then
    echo "Generated appcast is missing the EdDSA archive signature." >&2
    exit 70
fi

echo "Generated signed update feed: ${appcast_path}"
