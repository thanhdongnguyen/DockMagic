#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
work=$(mktemp -d /private/tmp/dockmagic-opencode-tests.XXXXXX)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/Sources" "$work/Tests"
cp script/opencode-foundation/Package.swift "$work/Package.swift"
for source in Models/OpenCodeUsage.swift Services/OpenCodeHistoryReader.swift Services/OpenCodeHistoryCache.swift Stores/OpenCodeUsageStore.swift; do
    ln -s "$root/DockMagic/DockMagic/$source" "$work/Sources/"
done
for test in OpenCodeHistoryTests.swift OpenCodeStoreTests.swift; do
    ln -s "$root/DockMagic/DockMagicTests/$test" "$work/Tests/"
done
CLANG_MODULE_CACHE_PATH="$work/modules" SWIFTPM_MODULECACHE_OVERRIDE="$work/modules" swift test --disable-sandbox --package-path "$work" "$@"
