import SwiftUI

@MainActor
struct AugmentHoverDashboardView: View {
    let store: AugmentUsageStore
    var chartColor: DockColor? = nil
    var onOpenSettings: () -> Void = {}
    @Environment(\.designTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var metric: AugmentMetric = .output
    @State private var hoveredDate: Date?
    @State private var selectedDay: Date?
    @State private var showsAllModels = false
    @State private var showsContinuityDetail = false
    @State private var detail: AugmentResourceSnapshot?
    @State private var detailError: String?
    @State private var detailLoading = false
    @FocusState private var navigationFocused: Bool
    private var snapshot: AugmentUsageSnapshot? { store.state.snapshot }
    private var resolvedChartColor: Color {
        ProjectTheme.rendererColor(
            chartColor,
            automatic: theme.action,
            on: theme.opaqueSurface,
            colorScheme: colorScheme,
            minimumContrast: 3
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.standard) {
                if showsContinuityDetail, let snapshot {
                    continuityDetail(snapshot)
                } else if let selectedDay {
                    detailHeader("Daily detail")
                    Text(AugmentUTC.string(selectedDay) + " UTC").font(DSTypography.bodyEmphasis)
                    if let day = snapshot?.day(selectedDay) { componentRows(day.metrics) }
                    DSDivider()
                    Text("Models · \(metric.title)").font(DSTypography.bodyEmphasis)
                    if detailLoading { ProgressView("Loading models…") }
                    if let detailError {
                        Text(detailError).font(DSTypography.metadata)
                        Button("Retry") { loadDetail(selectedDay) }.buttonStyle(DSButtonStyle())
                    }
                    if let detail { modelRows(detail.models(by: metric)) }
                } else if showsAllModels {
                    detailHeader("All models · \(metric.title)")
                    if let snapshot { Text(snapshot.range.label).font(DSTypography.metadata) }
                    modelsContent(all: true)
                } else {
                    ForEach(AugmentDashboardManifest.selectedModules, id: \.self) { module in
                        switch module {
                        case .identity: header
                        case .statusLink:
                            Link("Augment service status", destination: URL(string: "https://status.augmentcode.com/")!)
                                .font(DSTypography.metadata).buttonStyle(DSContentButtonStyle())
                                .foregroundStyle(theme.action)
                        case .dailyUsage:
                            overview
                        case .continuity:
                            if let snapshot { continuityStrip(snapshot) }
                        case .dailyIntensity:
                            if let snapshot { dailyIntensity(snapshot) }
                        case .models:
                            if snapshot != nil { modelsSection }
                        case .dailyDetail: EmptyView() // Reached by the selected-day route.
                        }
                    }
                }
            }.padding(.bottom, DSSpacing.small)
        }
        .buttonStyle(DSButtonStyle())
        .focusable()
        .focused($navigationFocused)
        .onAppear { store.setDashboardVisible(true) }
        .onDisappear { store.setDashboardVisible(false) }
        .onExitCommand { selectedDay = nil; showsAllModels = false; showsContinuityDetail = false }
        .onChange(of: selectedDay) { _, day in if day != nil { navigationFocused = true } }
        .onChange(of: showsAllModels) { _, visible in if visible { navigationFocused = true } }
        .onChange(of: showsContinuityDetail) { _, visible in if visible { navigationFocused = true } }
        .onChange(of: snapshot?.range) { _, _ in hoveredDate = nil }
        .onChange(of: snapshot == nil) { _, empty in
            if empty {
                selectedDay = nil
                detail = nil
                showsAllModels = false
                showsContinuityDetail = false
            }
        }
        .accessibilityIdentifier("augment.dashboard")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            HStack {
                PreservedVectorAssetImage(assetName: "AugmentLogo").scaledToFit().frame(width: 26, height: 26)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Augment").font(DSTypography.panelTitle)
                    Text("Organization · \(store.state.label)").font(DSTypography.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                if store.state.isRefreshing { ProgressView().controlSize(.small) }
                Button(action: store.refreshManually) { DSIcon(systemName: "arrow.clockwise") }
                    .disabled(store.state.isRefreshing || !store.isConfigured)
                    .accessibilityLabel("Refresh Augment analytics").help("Refresh Augment analytics")
                    .accessibilityIdentifier("augment.refresh")
                Button(action: onOpenSettings) { DSIcon(systemName: "gearshape") }
                    .accessibilityLabel("Open Augment Settings").help("Open Augment Settings")
                    .accessibilityIdentifier("augment.settings")
            }
            if let snapshot {
                Text("Checked \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(DSTypography.caption).foregroundStyle(theme.textSecondary)
            }
            if let message = store.state.message { Text(message).font(DSTypography.metadata).foregroundStyle(theme.textSecondary) }
        }
    }

    @ViewBuilder private var overview: some View {
        if let snapshot {
            if let latest = snapshot.latest {
                Text("Latest reported day · \(AugmentUTC.string(latest.date)) UTC")
                    .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                HStack(spacing: DSSpacing.small) {
                    ForEach([AugmentMetric.input, .output, .billedUSD]) { metric in
                        DSMetricCard(title: metric.title, state: metricState(latest.metrics, metric: metric), variant: .compact)

                    }
                }
            } else {
                Text("No reported data in this period.").font(DSTypography.body)
            }
            DSDivider()
            history(snapshot)
        } else {
            VStack(alignment: .leading, spacing: DSSpacing.standard) {
                if store.state.isRefreshing { ProgressView("Loading organization usage…") }
                Text(store.isConfigured ? "Usage is currently unavailable." : "Connect an Enterprise Analytics token in Settings.")
                    .font(DSTypography.body)
                Button("Open Settings", action: onOpenSettings)
            }.padding(.vertical, DSSpacing.standard)
        }
    }

    private func metricState(_ metrics: AugmentMetrics, metric: AugmentMetric) -> DSDataState<DSMetricValue> {
        guard let raw = metrics.value(metric), raw.isFinite else { return .unavailable("Not reported") }
        let value = DSMetricValue(formatted: AugmentFormatting.value(raw, metric: metric, compact: true))
        if store.state.observation == .stale { return .stale(value, detail: "Last reported day") }
        if store.state.observation == .failed { return .failed(store.state.message ?? "Refresh failed", lastValue: value) }
        if metrics.isPartial { return .partial(value, detail: "Reported fields") }
        return .available(value)
    }

    private func history(_ snapshot: AugmentUsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            HStack {
                Text("Daily history").font(DSTypography.bodyEmphasis)
                Spacer()
                DSSegmentedControl(title: "History range", selection: Binding(get: { store.historyDays }, set: store.setHistoryDays),
                    options: [7, 30, 90].map { .init(value: $0, title: "\($0)d") }, size: .small)
                    .frame(width: 158)
                    .accessibilityIdentifier("augment.history.range")
            }
            Text(snapshot.range.label).font(DSTypography.caption).foregroundStyle(theme.textSecondary)
            HStack {
                DSSelect(title: "History metric", selection: $metric,
                         options: AugmentMetric.allCases.map { .init(value: $0, title: $0.title) }).labelsHidden().frame(width: 150)
                    .accessibilityIdentifier("augment.history.metric")
                Spacer()
                let date = hoveredDate ?? snapshot.latest?.date
                let day = date.flatMap { snapshot.day($0) }
                VStack(alignment: .trailing) {
                    Text(AugmentFormatting.value(day?.metrics.value(metric), metric: metric))
                        .font(DSTypography.bodyEmphasis).monospacedDigit()
                    Text(date.map { AugmentUTC.string($0) + " UTC" } ?? "Not reported")
                        .font(DSTypography.caption).foregroundStyle(theme.textSecondary)
                }
            }
            AIUsageHistoryChart(points: snapshot.range.dates.map {
                AIUsageHistoryPoint(date: $0, value: snapshot.day($0)?.metrics.value(metric), partial: snapshot.day($0)?.metrics.isPartial == true)
            }, hoveredDate: $hoveredDate, plotHeight: 110, timezone: TimeZone(secondsFromGMT: 0)!,
                metricLabel: metric.unit, allowsZeroSelection: true,
                selectableDates: Set(snapshot.days.map(\.date)),
                dataColor: resolvedChartColor,
                accessibilityValueFormatter: { AugmentFormatting.value($0, metric: metric) },
                formatValue: { AugmentFormatting.value($0, metric: metric, compact: true) },
                onSelect: { day in selectedDay = day; loadDetail(day) })
                .accessibilityIdentifier("augment.history.chart")
            if snapshot.isPartial {
                Text("Missing dates or fields remain unavailable. Totals cover reported data only.")
                    .font(DSTypography.caption).foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func continuityStrip(_ snapshot: AugmentUsageSnapshot) -> some View {
        StreakContinuityStrip(
            summary: AugmentPresentation.organizationContinuity(snapshot),
            brand: .augment,
            accent: resolvedChartColor,
            currentDayIsUnknown: AugmentPresentation.organizationEndpointIsUnknown(snapshot),
            presentation: .organizationActivity
        ) {
            showsContinuityDetail = true
        }
    }

    private func dailyIntensity(_ snapshot: AugmentUsageSnapshot) -> some View {
        AIUsageDailyIntensityCard(
            buckets: AugmentPresentation.intensityBuckets(snapshot),
            accent: resolvedChartColor,
            unavailableBucketIDs: AugmentPresentation.unavailableIntensityBucketIDs(snapshot),
            isPartial: snapshot.isPartial,
            marksUnknownDays: true,
            title: "Daily intensity · Output",
            metricLabel: "output tokens",
            timeZone: AugmentUTC.calendar.timeZone,
            scopeDescription: "Organization output reported by Augment in UTC; missing dates remain unavailable."
        )
        .frame(height: 110)
        .accessibilityIdentifier("augment.dailyIntensity")
    }

    private func continuityDetail(_ snapshot: AugmentUsageSnapshot) -> some View {
        let summary = AugmentPresentation.organizationContinuity(snapshot)
        return VStack(alignment: .leading, spacing: DSSpacing.standard) {
            detailHeader("Organization continuity")
            Text("Derived from reported organization analytics through \(AugmentUTC.string(snapshot.range.end)) UTC. This is not a personal streak or realtime activity.")
                .font(DSTypography.metadata)
                .foregroundStyle(theme.textSecondary)
            HStack(spacing: DSSpacing.small) {
                DSMetricCard(
                    title: "Current run",
                    state: AugmentPresentation.organizationEndpointIsUnknown(snapshot)
                        ? .unavailable("Latest day not reported")
                        : .available(DSMetricValue(formatted: "\(summary.currentDays)d")),
                    variant: .compact
                )
                DSMetricCard(
                    title: "Best run",
                    state: .available(DSMetricValue(formatted: "\(summary.bestDays)d")),
                    variant: .compact
                )
            }
            dailyIntensity(snapshot)
            Text("An active day has at least one positive token or cost metric. Explicit zero ends a run; an unreported date stays unknown.")
                .font(DSTypography.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .accessibilityIdentifier("augment.continuity.detail")
    }

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.small) {
            DSDivider()
            HStack {
                Text("Top models · \(metric.title)").font(DSTypography.bodyEmphasis)
                Spacer()
                Button("View all") { showsAllModels = true }.accessibilityIdentifier("augment.models.all")
            }
            modelsContent(all: false)
        }
    }
    @ViewBuilder private func modelsContent(all: Bool) -> some View {
        if store.modelsLoading { ProgressView("Loading models…").controlSize(.small) }
        if let error = store.modelsError {
            Text(error).font(DSTypography.metadata)
            Button("Retry models", action: store.loadModels)
        }
        if let models = store.models, models.range == snapshot?.range {
            modelRows(all ? models.models(by: metric) : Array(models.models(by: metric).prefix(3)))
            if store.modelsError != nil { Text("Last known model breakdown").font(DSTypography.caption) }
        }
    }
    @ViewBuilder private func modelRows(_ rows: [AugmentResourceUsage]) -> some View {
        if rows.isEmpty { Text("No model breakdown reported.").font(DSTypography.metadata).foregroundStyle(theme.textSecondary) }
        ForEach(rows) { row in
            HStack(alignment: .firstTextBaseline) {
                Text(row.name).lineLimit(2)
                Spacer()
                Text(AugmentFormatting.value(row.metrics.value(metric), metric: metric)).monospacedDigit()
            }.font(DSTypography.metadata).padding(.vertical, 3)
        }
    }
    private func componentRows(_ metrics: AugmentMetrics) -> some View {
        VStack(spacing: DSSpacing.small) {
            ForEach(AugmentMetric.allCases) { metric in
                LabeledContent(metric.title, value: AugmentFormatting.value(metrics.value(metric), metric: metric))
            }
            LabeledContent("Estimated USD", value: AugmentFormatting.value(metrics.estimatedUSD, metric: .billedUSD))
        }.font(DSTypography.body)
    }
    private func detailHeader(_ title: String) -> some View {
        HStack {
            Button {
                selectedDay = nil
                showsAllModels = false
                showsContinuityDetail = false
            } label: { DSLabel("Back", systemImage: "chevron.left") }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("augment.detail.back")
            Text(title).font(DSTypography.bodyEmphasis)
        }
    }
    private func loadDetail(_ day: Date) {
        detailLoading = true; detail = nil; detailError = nil
        Task {
            do {
                let value = try await store.resourceDetail(range: AugmentDateRange(start: day, end: day))
                guard selectedDay == day else { return }
                detail = value
            } catch {
                guard selectedDay == day else { return }
                detailError = AugmentUsageStore.message(error)
            }
            detailLoading = false
        }
    }
}
