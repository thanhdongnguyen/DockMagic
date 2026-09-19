import SwiftUI

@MainActor
struct OpenCodeHoverDashboardView: View {
    let store: OpenCodeUsageStore
    var appearanceMode: DSAppearanceMode = .dark
    var appearance: OpenCodeDockAppearance = .standard
    var onOpenSettings: () -> Void = {}
    var onDismiss: () -> Void = {}
    @Environment(\.designTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredDay: Date?
    @State private var selectedDay: Date?
    @State private var detail: OpenCodeDailyDetail?
    @State private var detailError: String?
    @State private var detailLoading = false
    @State private var detailRetry = 0
    @State private var showsBadges = false
    @State private var showsCost = false
    @State private var captureError: String?
    @State private var shareURL: URL?
    @State private var artifact: CodexDashboardCaptureArtifact?
    @State private var artifactSnapshot: OpenCodeUsageState?

    private var snapshot: OpenCodeUsageSnapshot? { store.state.snapshot }
    private var today: OpenCodeDailyDetail? { snapshot?.day(.now) }
    private var detailRequestID: String {
        "\(selectedDay?.timeIntervalSince1970 ?? -1)|\(snapshot?.sourceID ?? "")|\(snapshot?.readAt.timeIntervalSince1970 ?? -1)|\(detailRetry)"
    }
    private var summary: TokenUsageStreakSummary? { OpenCodePresentation.streak(snapshot) }
    private var resolvedChartColor: Color {
        ProjectTheme.readableRendererColor(
            appearance.chartColor,
            on: theme.opaqueSurface,
            colorScheme: colorScheme,
            minimumContrast: 3
        ).color
    }
    private var resolvedTokenColor: Color {
        ProjectTheme.readableRendererColor(
            appearance.tokenColor,
            on: theme.opaqueSurface,
            colorScheme: colorScheme,
            minimumContrast: 4.5
        ).color
    }

    var body: some View {
        Group {
            if showsBadges {
                StreakDetailView(summary: summary, brand: .openCode) { showsBadges = false }
            } else if let selectedDay {
                dailyDetail(selectedDay)
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 8) {
                        header
                        if let snapshot {
                            if OpenCodeDashboardManifest.supports(.dailyUsage) { dailyUsage(snapshot) }
                            if OpenCodeDashboardManifest.supports(.streak) {
                                StreakContinuityStrip(summary: summary, brand: .openCode, accent: theme.action) { showsBadges = true }
                            }
                            if OpenCodeDashboardManifest.supports(.shipMomentum) {
                                CodexShipMomentumCard(momentum: OpenCodePresentation.momentum(snapshot), isPartial: today?.isPartial ?? true)
                            }
                            HStack(spacing: 8) {
                                AIUsageDailyIntensityCard(buckets: OpenCodePresentation.buckets(snapshot), unavailableBucketIDs: OpenCodePresentation.unavailable(snapshot), isPartial: snapshot.isPartial)
                                CodexTopModelsCard(models: OpenCodePresentation.topModels(snapshot), isPartial: snapshot.isPartial, providerName: "OpenCode")
                            }.frame(height: 110)
                            Text(OpenCodeUsageSnapshot.coverageNote)
                                .dsFont(size: 9).foregroundStyle(theme.textTertiary)
                        } else {
                            VStack(spacing: 12) {
                                if store.state.isRefreshing { ProgressView() }
                                Text(store.state.message ?? "Run OpenCode to create local history, then choose its database in Settings.")
                                    .dsFont(size: 12).foregroundStyle(theme.textSecondary).multilineTextAlignment(.center)
                                Button("Open Settings", action: onOpenSettings).buttonStyle(DSButtonStyle())
                                Button("Refresh", action: store.refresh).buttonStyle(DSButtonStyle())
                            }.padding(.vertical, 40)
                        }
                    }.padding(.bottom, 4)
                }
            }
        }
        .background(DashboardSharePresenter(itemURL: $shareURL).frame(width: 1, height: 1))
        .onAppear { store.refresh() }
        .onExitCommand {
            if selectedDay != nil { selectedDay = nil }
            else if showsBadges { showsBadges = false }
            else { onDismiss() }
        }
        .onChange(of: snapshot?.sourceID) { _, _ in selectedDay = nil }
        .onChange(of: snapshot?.timezoneID) { _, _ in selectedDay = nil }
        .task(id: detailRequestID) {
            guard let day = selectedDay, let snapshot else { return }
            detailLoading = true; detailError = nil; detail = nil
            do {
                let value = try await store.detail(day: day, snapshot: snapshot)
                guard !Task.isCancelled, selectedDay == day else { return }
                detail = value
            } catch {
                guard !Task.isCancelled, selectedDay == day else { return }
                detailError = error.localizedDescription
            }
            detailLoading = false
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("OpenCode local history dashboard")
        .accessibilityIdentifier("openCode.dashboard")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                PreservedVectorAssetImage(assetName: "OpenCodeLogo").scaledToFit().frame(width: 27, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("OpenCode").dsFont(size: 16, weight: .bold).foregroundStyle(theme.textPrimary)
                    Text(store.state.label).dsFont(size: 9).foregroundStyle(theme.textSecondary)
                }
                Spacer()
                if store.state.isRefreshing { ProgressView().controlSize(.mini) }
                Button(action: store.refresh) { DSIcon(systemName: "arrow.clockwise") }
                    .help("Refresh local history").accessibilityLabel("Refresh local history")
                Button(action: onOpenSettings) { DSIcon(systemName: "gearshape") }
                    .help("OpenCode Settings").accessibilityLabel("OpenCode Settings")
                DSMenu {
                    DSMenuButton("Save image…") { export(.save) }
                    DSMenuButton("Copy image") { export(.copy) }
                    DSMenuButton("Share image…") { export(.share) }
                } label: { DSIcon(systemName: "square.and.arrow.up") }
                    .fixedSize()
                    .disabled(!OpenCodePresentation.canExport(store.state))
                    .accessibilityLabel("Export OpenCode activity card")
            }.buttonStyle(DSContentButtonStyle())
            if let snapshot {
                Text("Updated \(snapshot.readAt.formatted(date: .abbreviated, time: .shortened)) · local history")
                    .dsFont(size: 8.5).foregroundStyle(theme.textTertiary)
            }
            if let message = store.state.message { Text(message).dsFont(size: 9).foregroundStyle(theme.textSecondary) }
            if let captureError { Text(captureError).dsFont(size: 9).foregroundStyle(theme.warningForeground) }
        }
    }

    private func dailyUsage(_ snapshot: OpenCodeUsageSnapshot) -> some View {
        let dates = snapshot.trailingDays(30)
        let canShowCost = dates.contains { snapshot.day($0)?.cost.value != nil }
        let cost = showsCost && canShowCost
        let buckets = dates.map { date -> CodexTokenUsageDailyBucket in
            let value: Int64
            if cost { value = Int64(min(Double(Int64.max / 2), (snapshot.day(date)?.cost.value ?? 0) * 1_000_000)) }
            else { value = snapshot.day(date)?.tokens.total ?? 0 }
            return CodexTokenUsageDailyBucket(startDate: date, tokens: value)
        }
        let unavailable = Set(dates.filter { cost ? snapshot.day($0)?.cost.value == nil : snapshot.day($0)?.tokens.total == nil })
        let partial = Set(dates.filter { cost ? snapshot.day($0)?.cost.isPartial == true : snapshot.day($0)?.isPartial == true })
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily usage").dsFont(size: 11, weight: .bold)
                    Text(cost ? OpenCodePresentation.money(today?.cost.value) : OpenCodePresentation.compact(today?.tokens.total))
                        .dsFont(size: cost ? 25 : 34, weight: .bold).monospacedDigit()
                        .foregroundStyle(cost ? theme.textPrimary : resolvedTokenColor)
                        .accessibilityIdentifier("openCode.today")
                    Text(cost ? "Estimated USD today\(today?.cost.isPartial == true ? " · partial" : "")" : "Recorded tokens today\(today?.isPartial == true ? " · partial" : "")")
                        .dsFont(size: 9).foregroundStyle(theme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(OpenCodePresentation.compact(snapshot.lifetimeTokens)) local total\(snapshot.isPartial ? "*" : "")")
                        .dsFont(size: 9).foregroundStyle(theme.textSecondary)
                    if canShowCost {
                        DSSegmentedControl(title: "Metric", selection: $showsCost, options: [
                            .init(value: false, title: "Tokens"), .init(value: true, title: "Cost")
                        ], size: .small).frame(width: 150)
                            .accessibilityIdentifier("openCode.metric")
                    }
                }
            }
            AIUsageTokenHistoryChart(buckets: buckets, hoveredBucketID: $hoveredDay, plotHeight: 82,
                unavailableBucketIDs: unavailable, allowsZeroSelection: true, partialBucketIDs: partial,
                metricLabel: cost ? "estimated USD" : "tokens",
                valueFormatter: cost ? { OpenCodePresentation.money(Double($0) / 1_000_000) } : nil,
                chartStyle: .area,
                dataColor: resolvedChartColor,
                strokeWidth: CGFloat(appearance.lineWidth),
                onSelectBucket: { selectedDay = $0 })
            if let hoveredDay {
                let day = snapshot.day(hoveredDay)
                Text("\(hoveredDay.formatted(date: .abbreviated, time: .omitted)) · \(cost ? OpenCodePresentation.money(day?.cost.value) : (day?.tokens.total.map { $0.formatted() + " tokens" } ?? "Not observed"))\(partial.contains(hoveredDay) ? " · partial" : "")")
                    .dsFont(size: 9).foregroundStyle(theme.textSecondary)
            }
            if cost { Text(OpenCodeCost.provenance).dsFont(size: 8.5).foregroundStyle(theme.textTertiary) }
        }.foregroundStyle(theme.textPrimary)
    }

    private func dailyDetail(_ day: Date) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { selectedDay = nil } label: { DSLabel("Back", systemImage: "chevron.left") }
                        .buttonStyle(DSContentButtonStyle()).accessibilityIdentifier("openCode.detail.back")
                    Spacer()
                    Text(day.formatted(date: .abbreviated, time: .omitted)).dsFont(size: 14, weight: .bold)
                }
                if detailLoading { ProgressView("Reading selected day…") }
                else if let detailError {
                    Text(detailError).foregroundStyle(theme.textSecondary)
                    Button("Retry") { detailRetry += 1 }
                } else if let detail {
                    Text("\(OpenCodePresentation.compact(detail.tokens.total)) recorded tokens\(detail.isPartial ? "*" : "")")
                        .dsFont(size: 24, weight: .bold)
                        .foregroundStyle(resolvedTokenColor)
                    Text("\(detail.sessionCount) sessions · \(detail.messageCount) messages with usage\(detail.isPartial ? " · partial coverage" : "")")
                        .dsFont(size: 10).foregroundStyle(theme.textSecondary)
                    let hours = OpenCodePresentation.hours(detail, calendar: snapshot?.calendar ?? .current)
                    CodexHourlyTokenUsageChart(buckets: hours.map {
                        CodexHourlyTokenUsageBucket(startDate: $0.startDate, usage: OpenCodePresentation.breakdown($0.tokens))
                    }, unavailableBucketIDs: Set(hours.filter { $0.tokens.total == nil }.map(\.startDate)),
                        usesObservedHourAxis: true, dataColor: resolvedChartColor).frame(height: 142)
                    TokenBreakdownPresentationView(metrics: [
                        .init(title: "Input", value: detail.tokens.input), .init(title: "Output", value: detail.tokens.output),
                        .init(title: "Reasoning", value: detail.tokens.reasoning), .init(title: "Cache read", value: detail.tokens.cacheRead),
                        .init(title: "Cache write", value: detail.tokens.cacheWrite)
                    ])
                    if let cost = detail.cost.value {
                        Text("\(OpenCodePresentation.money(cost)) estimated USD\(detail.cost.isPartial ? " · partial" : "")")
                            .dsFont(size: 11).help(OpenCodeCost.provenance)
                    }
                    Text("Providers and models").dsFont(size: 11, weight: .bold)
                    ForEach(detail.models) { model in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.model).lineLimit(2).help(model.model)
                                Text(model.provider).dsFont(size: 9).foregroundStyle(theme.textSecondary)
                            }
                            Spacer()
                            Text("\(OpenCodePresentation.compact(model.tokens.total))\(model.isPartial ? "*" : "")").monospacedDigit()
                        }.dsFont(size: 11).padding(.vertical, 4)
                    }
                    if detail.isPartial { Text("* Only recorded metadata is included; some usage is unavailable.").dsFont(size: 9).foregroundStyle(theme.textSecondary) }
                }
            }.foregroundStyle(theme.textPrimary)
        }.accessibilityIdentifier("openCode.dailyDetail")
    }

    private enum ExportAction { case save, copy, share }
    private func export(_ action: ExportAction) {
        do {
            // Keep exactly one PNG for all three actions until the source snapshot changes.
            if artifact == nil || artifactSnapshot != store.state {
                artifact = try CodexDashboardCaptureService.renderActivityCard(state: store.state, appearanceMode: appearanceMode)
                artifactSnapshot = store.state
            }
            guard let artifact else { return }
            captureError = nil
            switch action {
            case .save: CodexDashboardCaptureService.presentSavePanel(for: artifact) { error in captureError = error?.localizedDescription }
            case .copy: try CodexDashboardCaptureService.copy(artifact)
            case .share: shareURL = try CodexDashboardCaptureService.temporaryShareURL(for: artifact)
            }
        } catch { captureError = error.localizedDescription }
    }
}

/// Bucket-driven token presentation: providers supply only supported buckets.
struct TokenBreakdownPresentationView: View {
    struct Metric: Identifiable {
        let title: String
        let value: Int64?
        var id: String { title }
    }
    let metrics: [Metric]
    @Environment(\.designTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Token breakdown").dsFont(size: 11, weight: .bold)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ForEach(metrics) { metric in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(metric.title).dsFont(size: 9).foregroundStyle(theme.textSecondary)
                        Text(metric.value.map { $0.formatted() } ?? "—").dsFont(size: 12, weight: .semibold).monospacedDigit()
                    }.accessibilityElement(children: .ignore)
                        .accessibilityLabel(metric.title)
                        .accessibilityValue(metric.value.map { $0.formatted() } ?? "Unavailable")
                        .accessibilityIdentifier("tokenBreakdown.\(metric.title)")
                }
            }
        }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.opaqueSurfaceInset)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(theme.outline, lineWidth: 0.5) }
    }
}
