#!/usr/bin/env bash
set -euo pipefail

GROK_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GROK_TEST_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/dockmagic-grok-tests.XXXXXXXX")"
mkdir -p "$GROK_TEST_STAGE/Sources" "$GROK_TEST_STAGE/Tests"
cp "$GROK_REPO_ROOT/script/grok-foundation/Package.swift" "$GROK_TEST_STAGE/Package.swift"
for source in "$GROK_REPO_ROOT"/DockMagic/DockMagic/Models/GrokBuild*.swift; do
  ln -s "$source" "$GROK_TEST_STAGE/Sources/"
done
for source in "$GROK_REPO_ROOT"/DockMagic/DockMagic/Services/GrokBuild*.swift; do
  ln -s "$source" "$GROK_TEST_STAGE/Sources/"
done
for source in "$GROK_REPO_ROOT"/DockMagic/DockMagic/Stores/GrokBuild*.swift; do
  ln -s "$source" "$GROK_TEST_STAGE/Sources/"
done
ln -s "$GROK_REPO_ROOT/DockMagic/DockMagic/Services/ProcessPipe.swift" "$GROK_TEST_STAGE/Sources/"
ln -s "$GROK_REPO_ROOT/DockMagic/DockMagic/Models/CodexRateLimitSnapshot.swift" "$GROK_TEST_STAGE/Sources/"
ln -s "$GROK_REPO_ROOT/DockMagic/DockMagic/Models/TokenUsageStreakRecord.swift" "$GROK_TEST_STAGE/Sources/"
for source in "$GROK_REPO_ROOT"/DockMagic/DockMagicTests/GrokBuild*Tests.swift; do
  ln -s "$source" "$GROK_TEST_STAGE/Tests/"
done
# Keep the small, uniquely named workspace for diagnosis. No app data, package
# pins or existing DerivedData are changed by this harness.
echo "Grok test workspace: $GROK_TEST_STAGE"
swift test --package-path "$GROK_TEST_STAGE" "$@"
