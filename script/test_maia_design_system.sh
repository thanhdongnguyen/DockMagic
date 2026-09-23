#!/usr/bin/env bash
# Reproduce Maia component/resource/production-render QA with isolated fixtures.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
DERIVED_DATA_PATH="${DOCKMAGIC_DERIVED_DATA_PATH:-$ROOT_DIR/.derivedData}"
SOURCE_PACKAGES_PATH="${DOCKMAGIC_SOURCE_PACKAGES_PATH:-$DERIVED_DATA_PATH/SourcePackages}"
python3 script/verify_maia_resources.py
TESTS=()
case "${1:-unit}" in
  unit)
    for test_class in MaiaDesignSystemTests BinanceRenderTests CalendarFeatureTests NowPlayingTests DockHoverDelayTests SearchConsoleFeatureTests; do
      TESTS+=("-only-testing:DockMagicTests/$test_class")
    done
    for test_method in \
      testClockStylesRenderAcrossAppearanceAndAccessibilityVariants \
      testMaiaNestedOverlayLeasesKeepEveryHoverPanelAliveAndRelease \
      testMaiaAppearanceModesAndFoundationContracts \
      testMaiaAppearancePreferencePersistsAndInvalidValuesFallBackSafely \
      testMaiaPublicPaletteAssetsMatchDocumentedValues \
      testMaiaSemanticColorPairsMeetAccessibleContrastInLightAndDark \
      testDesignSystemRendersAllSettingsAcrossAppearances \
      testDesignSystemRendersAllDockStatesInSystemAppearance \
      testDesignSystemRendersAllDockStatesInLightAppearance \
      testDesignSystemRendersAllDockStatesInDarkAppearance \
      testMaiaAppearanceAndAccessibilityVariantsRenderDistinctSettings \
      testClaudeConnectionSettingsRenderAcrossAppearanceMatrix \
      testCodexHoverDashboardFollowsColorDesignSystemSourceContract \
      testClaudeCodeHoverDashboardFollowsColorAndPrivacyContracts \
      testCodexCaptureButtonOpensMenuInNonactivatingPanel \
      testClaudeCodeCaptureButtonOpensMenuInNonactivatingPanel \
      testUsageActivityCardsRenderForEveryExportAction \
      testAntigravityQuotaOnlyDashboardSharesActivityLayout \
      testActivityCardAreaChartPreservesMissingDaysAndRealZero \
      testDashboardCaptureRendersSettledMomentumWithoutEntryAnimation \
      testDashboardCapturesContainOnlyCardAcrossAppearancesAndDockEdges; do
      TESTS+=("-only-testing:DockMagicTests/DockMagicTests/$test_method")
    done
    ;;
  --ui) TESTS+=("-only-testing:DockMagicUITests/MaiaUITests") ;;
  --all-unit) TESTS+=("-only-testing:DockMagicTests") ;;
  *) echo "Usage: $0 [unit|--ui|--all-unit]" >&2; exit 2 ;;
esac
exec xcodebuild -quiet -project DockMagic/DockMagic.xcodeproj -scheme DockMagic \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH" \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  "${TESTS[@]}" test
