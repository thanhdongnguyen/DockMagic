#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
work=$(mktemp -d /private/tmp/dockmagic-augment-tests.XXXXXX)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/Sources" "$work/Tests"
cp script/augment-foundation/Package.swift "$work/Package.swift"
for source in Models/AugmentUsage.swift Services/AugmentAnalyticsClient.swift Services/AugmentCredentialVault.swift Services/AugmentHistoryCache.swift Services/NetworkAvailabilityMonitor.swift Stores/AugmentUsageStore.swift; do
    ln -s "$root/DockMagic/DockMagic/$source" "$work/Sources/"
done
for test in AugmentAnalyticsTests.swift AugmentStoreTests.swift; do
    ln -s "$root/DockMagic/DockMagicTests/$test" "$work/Tests/"
done
CLANG_MODULE_CACHE_PATH="$work/modules" SWIFTPM_MODULECACHE_OVERRIDE="$work/modules" swift test --disable-sandbox --package-path "$work" "$@"
