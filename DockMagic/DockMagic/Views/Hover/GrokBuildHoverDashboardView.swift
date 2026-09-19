import SwiftUI

@MainActor
struct GrokBuildHoverDashboardView: View {
    let store: GrokBuildUsageStore
    var appearance: GrokBuildAppearance = .standard
    var onOpenSettings: () -> Void = {}
    @State private var hoveredDay: Date?
    @State private var showsBadges = false
    @State private var celebration: GrokBuildStreakCelebration?
    @Environment(\.designTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    private var continuity: GrokBuildContinuitySnapshot? { store.continuity() }
    private var plotColor: Color {
        ProjectTheme.readableRendererColor(appearance.tokenColor, on: theme.opaqueSurfaceRaised,
            colorScheme: colorScheme, minimumContrast: 3).color
    }
    private var insightColor: Color {
        ProjectTheme.readableRendererColor(appearance.tokenColor, on: theme.opaqueSurfaceInset,
            colorScheme: colorScheme, minimumContrast: 3).color
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsBadges {
                StreakDetailView(summary: continuity?.summary, brand: .grokBuild,
                    currentDayIsUnknown: continuity?.currentDays == nil, handlesEscape: true) { showsBadges = false }
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: DSSpacing.small) {
                        header
                        if GrokBuildDashboardManifest.supports(.quotaUnavailable) {
                            Text(GrokBuildDashboardManifest.quotaNote)
                                .font(DSTypography.caption).foregroundStyle(theme.textSecondary)
                                .accessibilityIdentifier("grokBuild.quotaUnavailable")
                        }
                        if let history = store.local.value, store.isEnabled {
                            if GrokBuildDashboardManifest.supports(.dailyTokens) { dailyTokens(history) }
                            if GrokBuildDashboardManifest.supports(.continuity) {
                                StreakContinuityStrip(summary: continuity?.summary, brand: .grokBuild, accent: theme.action,
                                    currentDayIsUnknown: continuity?.currentDays == nil) { showsBadges = true }
                                    .accessibilityAddTraits(.isButton)
                            }
                            if let celebration {
                                HStack {
                                    StreakBadgeView(milestone: celebration.summary.earnedBadge ?? .firstPrompt, size: 32, isUnlocked: true)
                                    Text("Today's observed streak: \(celebration.summary.currentDays) day(s)")
                                        .font(DSTypography.caption)
                                    Spacer()
                                    Button("View badges") { self.celebration = nil; showsBadges = true }
                                }.accessibilityIdentifier("grokBuild.celebration")
                            }
                            if GrokBuildDashboardManifest.supports(.shipMomentum) {
                                CodexShipMomentumCard(momentum: GrokBuildPresentation.momentum(history), isPartial: true)
                                Text("Observed token activity, not productivity. Resets each local day.")
                                    .font(DSTypography.caption).foregroundStyle(theme.textSecondary)
                            }
                            HStack(spacing: DSSpacing.small) {
                                if GrokBuildDashboardManifest.supports(.dailyIntensity) {
                                    AIUsageDailyIntensityCard(buckets: GrokBuildPresentation.buckets(history), accent: insightColor,
                                        unavailableBucketIDs: GrokBuildPresentation.unknown(history), isPartial: true,
                                        marksUnknownDays: true)
                                }
                                if GrokBuildDashboardManifest.supports(.topModels) {
                                    CodexTopModelsCard(models: GrokBuildPresentation.models(history), isPartial: true,
                                        accent: insightColor, providerName: "Grok Build")
                                }
                            }.frame(minHeight: 110)
                            Text("\(GrokBuildPresentation.modelCoverage(history)) Same 30-day window; unobserved days remain unknown.")
                                .font(DSTypography.caption).foregroundStyle(theme.textSecondary)
                            Text(GrokBuildPresentation.coverage(history)).font(DSTypography.caption)
                            Text(GrokBuildDashboardManifest.coverageNote).font(DSTypography.caption)
                                .foregroundStyle(theme.textSecondary)
                        } else {
                            Text(store.isEnabled ? "No eligible local history yet. Check executable and Grok home in Settings." : "Enable the experimental integration in Settings to read local history.")
                                .font(DSTypography.body).foregroundStyle(theme.textSecondary).padding(.vertical, DSSpacing.large)
                            Button("Open Settings", action: onOpenSettings).buttonStyle(DSButtonStyle())
                        }
                    }.padding(.bottom, DSSpacing.small)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("grokBuild.overview")
            }
        }
        .foregroundStyle(theme.textPrimary)
        // Keep a concrete container so its ID does not replace the nested
        // overview ScrollView or its controls' accessibility identities.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Grok Build local history dashboard")
        .accessibilityIdentifier("grokBuild.dashboard")
        .task(id: store.local.collectedAt) {
            celebration = await store.claimCelebration()
            guard celebration != nil else { return }
            do { try await Task.sleep(for: .milliseconds(2800)) } catch { return }
            celebration = nil
        }
        .onChange(of: store.configuration) { _, _ in showsBadges = false; hoveredDay = nil; celebration = nil }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            HStack {
                GrokBuildIdentityMark()
                VStack(alignment: .leading) {
                    Text("Grok Build").font(DSTypography.panelTitle)
                    Text("Experimental · local \(store.local.status.rawValue)").font(DSTypography.caption)
                }
                Spacer()
                if store.isRefreshingLocal { ProgressView().controlSize(.mini) }
                Button { Task { await store.refresh(forceQuota: true, forceLocal: true) } } label: { DSIcon(systemName: "arrow.clockwise") }
                    .disabled(!store.isEnabled || store.isRefreshingLocal)
                    .accessibilityLabel("Refresh Grok local usage").accessibilityIdentifier("grokBuild.refresh")
                Button(action: onOpenSettings) { DSIcon(systemName: "gearshape") }
                    .accessibilityLabel("Grok Build Settings").accessibilityIdentifier("grokBuild.settings")
            }.buttonStyle(DSContentButtonStyle())
            Link("Grok Build service status ↗", destination: URL(string: "https://status.x.ai/grok-build")!)
                .font(DSTypography.caption)
                .accessibilityIdentifier("grokBuild.serviceStatus")
            if let date = store.local.collectedAt {
                Text("Collected \(date.formatted(date: .abbreviated, time: .shortened))")
                    .font(DSTypography.caption).foregroundStyle(theme.textSecondary)
            }
            if let error = store.local.error { Text(error.localizedDescription).font(DSTypography.caption) }
        }
    }

    private func dailyTokens(_ history: GrokBuildHistorySnapshot) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            Text("Tokens observed locally").font(DSTypography.sectionTitle)
            Text(GrokBuildPresentation.compact(GrokBuildPresentation.today(history)))
                .font(DSTypography.metric).monospacedDigit().accessibilityIdentifier("grokBuild.today")
            Text("Today · partial local observation").font(DSTypography.caption).foregroundStyle(theme.textSecondary)
            if let first = history.days.first, let last = history.days.last {
                Text("\(first.startDate.formatted(date: .abbreviated, time: .omitted)) – \(last.startDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(DSTypography.caption).foregroundStyle(theme.textSecondary)
            }
            AIUsageTokenHistoryChart(buckets: GrokBuildPresentation.buckets(history), hoveredBucketID: $hoveredDay, plotHeight: 82,
                unavailableBucketIDs: GrokBuildPresentation.unknown(history), allowsZeroSelection: true,
                partialBucketIDs: Set(history.days.filter { $0.tokens != nil }.map(\.startDate)),
                dataColor: plotColor,
                onSelectBucket: { hoveredDay = $0 })
            if let hoveredDay {
                Text("\(hoveredDay.formatted(date: .complete, time: .omitted)): \(history.days.first { $0.startDate == hoveredDay }?.tokens.map { $0.formatted() + " observed tokens" } ?? "Unknown")")
                    .font(DSTypography.caption).accessibilityIdentifier("grokBuild.focusedDay")
            }
            Text("Dates reflect source recording timestamps, not exact model-call times.")
                .font(DSTypography.caption).foregroundStyle(theme.textSecondary)
        }
    }
}
