import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CodexDashboardCaptureConfiguration: Equatable, Sendable {
    let pointerEdge: DockHoverPointerEdge
    let panelSize: CGSize
    let appearanceMode: DSAppearanceMode

    var dashboardSize: CGSize {
        DockHoverCardLayout.size(panelSize: panelSize, pointerEdge: pointerEdge)
    }
}

struct CodexDashboardCaptureArtifact: Equatable, Sendable {
    let pngData: Data
    let fileName: String
    let pixelWidth: Int
    let pixelHeight: Int
}

enum CodexDashboardCaptureError: LocalizedError {
    case bitmapAllocationFailed
    case pngEncodingFailed
    case unexpectedPixelSize(width: Int, height: Int)
    case pasteboardWriteFailed
    case noShareableActivity
    case noShareableAvailability
    case noShareableQuota

    var errorDescription: String? {
        switch self {
        case .bitmapAllocationFailed:
            "DockMagic could not allocate the dashboard image."
        case .pngEncodingFailed:
            "DockMagic could not encode the dashboard as PNG."
        case let .unexpectedPixelSize(width, height):
            "The dashboard rendered at an unexpected size: \(width) × \(height) px."
        case .pasteboardWriteFailed:
            "DockMagic could not copy the PNG to the clipboard."
        case .noShareableActivity:
            "Antigravity activity is not available to share yet."
        case .noShareableAvailability:
            "Antigravity has no quota snapshot for an activity availability card."
        case .noShareableQuota:
            "Antigravity quota is not available to share yet."
        }
    }
}

@MainActor
enum CodexDashboardCaptureService {
    static let rasterScale: CGFloat = 4
    static let activityCardSize = CGSize(width: 300, height: 300)
    static let activityCardChartDayCount = 14

    static func pixelDimensions(
        for configuration: CodexDashboardCaptureConfiguration
    ) -> (width: Int, height: Int) {
        let size = configuration.dashboardSize
        return (
            Int((size.width * rasterScale).rounded()),
            Int((size.height * rasterScale).rounded())
        )
    }

    static func pixelSizeLabel(
        for configuration: CodexDashboardCaptureConfiguration
    ) -> String {
        let dimensions = pixelDimensions(for: configuration)
        return "\(dimensions.width) × \(dimensions.height) px"
    }

    static var activityCardPixelDimensions: (width: Int, height: Int) {
        (
            Int((activityCardSize.width * rasterScale).rounded()),
            Int((activityCardSize.height * rasterScale).rounded())
        )
    }

    static var activityCardPixelSizeLabel: String {
        let dimensions = activityCardPixelDimensions
        return "\(dimensions.width) × \(dimensions.height) px"
    }

    static func render(
        state: CodexUsageState,
        serviceStatus: ServiceStatusState = .operational(provider: .codex),
        configuration: CodexDashboardCaptureConfiguration,
        now: Date = .now,
        initialStreakCelebration: TokenUsageStreakCelebration? = nil,
        streakCelebrationAutoDismissDelay: Duration = .milliseconds(2_800),
        accessibilityOverrides: DSAccessibilityOverrides = .init()
    ) throws -> CodexDashboardCaptureArtifact {
        try renderDashboard(
            content: CodexHoverDashboardView(
                state: state,
                serviceStatus: serviceStatus,
                now: now,
                initialStreakCelebration: initialStreakCelebration,
                streakCelebrationAutoDismissDelay: streakCelebrationAutoDismissDelay
            ),
            configuration: configuration,
            fileName: defaultFileName(at: now),
            accessibilityOverrides: accessibilityOverrides
        )
    }

    static func renderClaudeCode(
        state: ClaudeCodeUsageState,
        serviceStatus: ServiceStatusState = .operational(provider: .claudeCode),
        configuration: CodexDashboardCaptureConfiguration,
        now: Date = .now,
        initialMetric: String = "Tokens",
        accessibilityOverrides: DSAccessibilityOverrides = .init()
    ) throws -> CodexDashboardCaptureArtifact {
        try renderDashboard(
            content: ClaudeCodeHoverDashboardView(
                state: state,
                serviceStatus: serviceStatus,
                now: now,
                initialMetric: initialMetric
            ),
            configuration: configuration,
            fileName: defaultClaudeCodeFileName(at: now),
            accessibilityOverrides: accessibilityOverrides
        )
    }

    static func renderActivityCard(
        state: CodexUsageState,
        brand: StreakServiceBrand,
        appearanceMode: DSAppearanceMode,
        now: Date = .now,
        accessibilityOverrides: DSAccessibilityOverrides = .init()
    ) throws -> CodexDashboardCaptureArtifact {
        let snapshot = state.snapshot
        return try renderActivityCard(
            tokenUsage: snapshot?.tokenUsage,
            streakSummary: snapshot?.streakSummary,
            momentum: CodexHoverDashboardPresentation.shipMomentum(
                in: snapshot,
                now: now
            ),
            brand: brand,
            appearanceMode: appearanceMode,
            now: now,
            dataTimestamp: snapshot?.fetchedAt ?? now,
            isStale: state.isStale,
            isHistoryPartial: false,
            showsUnavailableChartCue: false,
            datePrefixOverride: nil,
            isAvailabilityCard: false,
            accessibilityOverrides: accessibilityOverrides
        )
    }

    static func renderActivityCard(
        state: AntigravityUsageState,
        appearanceMode: DSAppearanceMode,
        now: Date = .now,
        accessibilityOverrides: DSAccessibilityOverrides = .init()
    ) throws -> CodexDashboardCaptureArtifact {
        let snapshot = state.snapshot
        let observations = AntigravityHoverDashboardPresentation
            .dayObservations(from: snapshot?.tokenUsage, now: now)
        let momentum = AntigravityHoverDashboardPresentation.shipMomentum(
            from: observations,
            now: now
        )
        let samples = activityCardChartSamples(
            from: snapshot?.tokenUsage,
            now: now
        )
        guard (momentum?.todayTokens ?? 0) > 0 else {
            throw CodexDashboardCaptureError.noShareableActivity
        }
        let activityTimestamp = snapshot?.activityObservedAt
            ?? snapshot?.tokenUsage?.dailyUsageBuckets.map(\.startDate).max()
            ?? snapshot?.fetchedAt
            ?? now
        let activityAge = now.timeIntervalSince(activityTimestamp)
        return try renderActivityCard(
            tokenUsage: snapshot?.tokenUsage,
            streakSummary: snapshot?.streakSummary,
            momentum: momentum,
            brand: .antigravity,
            appearanceMode: appearanceMode,
            now: now,
            dataTimestamp: activityTimestamp,
            isStale: activityAge < -60 || activityAge > 15 * 60,
            isHistoryPartial: snapshot?.historyIsPartial ?? true,
            showsUnavailableChartCue: !activityCardChartHasRenderableTrend(samples),
            datePrefixOverride: nil,
            isAvailabilityCard: false,
            accessibilityOverrides: accessibilityOverrides
        )
    }

    static func renderAntigravityAvailabilityCard(
        state: AntigravityUsageState,
        appearanceMode: DSAppearanceMode,
        now: Date = .now,
        accessibilityOverrides: DSAccessibilityOverrides = .init()
    ) throws -> CodexDashboardCaptureArtifact {
        guard let quota = state.snapshot?.quota,
              !quota.buckets.isEmpty else {
            throw CodexDashboardCaptureError.noShareableAvailability
        }
        let quotaAge = now.timeIntervalSince(quota.fetchedAt)
        return try renderActivityCard(
            tokenUsage: nil,
            streakSummary: state.snapshot?.streakSummary,
            momentum: nil,
            brand: .antigravity,
            appearanceMode: appearanceMode,
            now: now,
            dataTimestamp: quota.fetchedAt,
            isStale: state.isStale || quotaAge < -60 || quotaAge > 5 * 60,
            isHistoryPartial: true,
            showsUnavailableChartCue: true,
            datePrefixOverride: "CHECKED",
            isAvailabilityCard: true,
            accessibilityOverrides: accessibilityOverrides
        )
    }

    static func renderAntigravityQuotaCard(
        state: AntigravityUsageState,
        appearanceMode: DSAppearanceMode,
        now: Date = .now,
        accessibilityOverrides: DSAccessibilityOverrides = .init()
    ) throws -> CodexDashboardCaptureArtifact {
        guard let quota = state.snapshot?.quota,
              !quota.buckets.isEmpty else {
            throw CodexDashboardCaptureError.noShareableQuota
        }
        let resolvedAccessibility = resolvedAccessibilityOverrides(
            accessibilityOverrides
        )
        let quotaAge = now.timeIntervalSince(quota.fetchedAt)
        let root = DockMagicThemeRoot(
            content: AntigravityQuotaShareCard(
                quota: quota,
                isStale: state.isStale
                    || quotaAge < -60
                    || quotaAge > 5 * 60
            ),
            appearanceMode: appearanceMode
        )
        .environment(\.dsAccessibilityOverrides, resolvedAccessibility)
        let pngData = try rasterize(
            content: root,
            size: activityCardSize,
            appearanceMode: appearanceMode
        )
        let dimensions = activityCardPixelDimensions
        return CodexDashboardCaptureArtifact(
            pngData: pngData,
            fileName: antigravityQuotaCardFileName(at: quota.fetchedAt),
            pixelWidth: dimensions.width,
            pixelHeight: dimensions.height
        )
    }

    private static func renderActivityCard(
        tokenUsage: CodexAccountTokenUsage?,
        streakSummary: TokenUsageStreakSummary?,
        momentum: CodexShipMomentum?,
        brand: StreakServiceBrand,
        appearanceMode: DSAppearanceMode,
        now: Date,
        dataTimestamp: Date,
        isStale: Bool,
        isHistoryPartial: Bool,
        showsUnavailableChartCue: Bool,
        datePrefixOverride: String?,
        isAvailabilityCard: Bool,
        accessibilityOverrides: DSAccessibilityOverrides
    ) throws -> CodexDashboardCaptureArtifact {
        let resolvedAccessibility = resolvedAccessibilityOverrides(
            accessibilityOverrides
        )
        let root = DockMagicThemeRoot(
            content: DockMagicUsageActivityCard(
                tokenUsage: tokenUsage,
                streakSummary: streakSummary,
                momentum: momentum,
                brand: brand,
                now: now,
                dataTimestamp: dataTimestamp,
                isStale: isStale,
                isHistoryPartial: isHistoryPartial,
                showsUnavailableChartCue: showsUnavailableChartCue,
                datePrefixOverride: datePrefixOverride,
                isAvailabilityCard: isAvailabilityCard
            ),
            appearanceMode: appearanceMode
        )
        .environment(\.dsAccessibilityOverrides, resolvedAccessibility)
        let pngData = try rasterize(
            content: root,
            size: activityCardSize,
            appearanceMode: appearanceMode
        )
        let dimensions = activityCardPixelDimensions
        return CodexDashboardCaptureArtifact(
            pngData: pngData,
            fileName: isAvailabilityCard
                ? antigravityAvailabilityCardFileName(at: now)
                : activityCardFileName(for: brand, at: now),
            pixelWidth: dimensions.width,
            pixelHeight: dimensions.height
        )
    }

    static func activityCardChartSamples(
        from tokenUsage: CodexAccountTokenUsage?,
        now: Date = .now,
        calendar inputCalendar: Calendar = .current
    ) -> [Int64?] {
        var calendar = inputCalendar
        calendar.timeZone = inputCalendar.timeZone
        let today = calendar.startOfDay(for: now)
        guard let firstDay = calendar.date(
            byAdding: .day,
            value: -(activityCardChartDayCount - 1),
            to: today
        ), let dayAfterToday = calendar.date(
            byAdding: .day,
            value: 1,
            to: today
        ) else { return [] }

        var totalsByDay: [Date: Int64] = [:]
        for bucket in tokenUsage?.dailyUsageBuckets ?? [] {
            let day = calendar.startOfDay(for: bucket.startDate)
            guard day >= firstDay, day < dayAfterToday else { continue }
            let current = totalsByDay[day] ?? 0
            let addition = max(0, bucket.tokens)
            let total = current.addingReportingOverflow(addition)
            totalsByDay[day] = total.overflow ? Int64.max : total.partialValue
        }

        return (0..<activityCardChartDayCount).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: firstDay).map {
                totalsByDay[$0]
            }
        }
    }

    static func activityCardChartHasRenderableTrend(
        _ samples: [Int64?]
    ) -> Bool {
        guard samples.contains(where: { ($0 ?? 0) > 0 }) else { return false }
        return zip(samples, samples.dropFirst()).contains { current, next in
            current != nil && next != nil
        }
    }

    private static func renderDashboard<Content: View>(
        content: Content,
        configuration: CodexDashboardCaptureConfiguration,
        fileName: String,
        accessibilityOverrides: DSAccessibilityOverrides
    ) throws -> CodexDashboardCaptureArtifact {
        // ImageRenderer has no window to inherit macOS accessibility settings
        // from. Resolve them explicitly while retaining deterministic overrides.
        let resolvedAccessibility = resolvedAccessibilityOverrides(
            accessibilityOverrides
        )
        let root = DockMagicThemeRoot(
            content: DockHoverDashboardCard(size: configuration.dashboardSize) {
                content
            },
            appearanceMode: configuration.appearanceMode
        )
        .environment(\.dsAccessibilityOverrides, resolvedAccessibility)
        let pngData = try rasterize(
            content: root,
            size: configuration.dashboardSize,
            appearanceMode: configuration.appearanceMode
        )
        let dimensions = pixelDimensions(for: configuration)
        return CodexDashboardCaptureArtifact(
            pngData: pngData,
            fileName: fileName,
            pixelWidth: dimensions.width,
            pixelHeight: dimensions.height
        )
    }

    private static func resolvedAccessibilityOverrides(
        _ overrides: DSAccessibilityOverrides
    ) -> DSAccessibilityOverrides {
        let workspace = NSWorkspace.shared
        return DSAccessibilityOverrides(
            reduceTransparency: overrides.reduceTransparency
                ?? workspace.accessibilityDisplayShouldReduceTransparency,
            increaseContrast: overrides.increaseContrast
                ?? workspace.accessibilityDisplayShouldIncreaseContrast,
            reduceMotion: overrides.reduceMotion
                ?? workspace.accessibilityDisplayShouldReduceMotion
        )
    }

    /// Render SwiftUI text, symbols, and paths directly at the target density.
    /// AppKit's cached display can contain screen-resolution text layers even
    /// when its destination bitmap is larger. The static chart viewport also
    /// avoids native scroll views and their asynchronous scroll positioning.
    static func rasterize<Content: View>(
        content: Content,
        size: CGSize,
        appearanceMode: DSAppearanceMode
    ) throws -> Data {
        let colorScheme = appearanceMode.preferredColorScheme
            ?? (NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
                == .darkAqua ? .dark : .light)
        let root = content
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, colorScheme)
            .environment(\.displayScale, rasterScale)
            .environment(\.isDashboardCapture, true)
        let renderer = ImageRenderer(content: root)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = rasterScale
        renderer.isOpaque = false
        renderer.colorMode = .nonLinear

        guard let image = renderer.cgImage else {
            throw CodexDashboardCaptureError.bitmapAllocationFailed
        }
        let pixelWidth = Int((size.width * rasterScale).rounded())
        let pixelHeight = Int((size.height * rasterScale).rounded())
        guard image.width == pixelWidth, image.height == pixelHeight else {
            throw CodexDashboardCaptureError.unexpectedPixelSize(
                width: image.width,
                height: image.height
            )
        }
        let representation = NSBitmapImageRep(cgImage: image)
        representation.size = size
        guard let pngData = representation.representation(
            using: .png,
            properties: [:]
        ) else {
            throw CodexDashboardCaptureError.pngEncodingFailed
        }
        return pngData
    }

    static func presentSavePanel(
        for artifact: CodexDashboardCaptureArtifact,
        completion: @escaping @MainActor (Error?) -> Void
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = artifact.fileName
        panel.title = if artifact.fileName.contains("-Antigravity-Quota-") {
            "Save Antigravity Quota Card"
        } else if artifact.fileName.contains("-Antigravity-Availability-") {
            "Save Antigravity Activity Layout"
        } else if artifact.fileName.contains("-Antigravity-") {
            "Save Antigravity Activity Card"
        } else if artifact.fileName.contains("-Claude-Code-") {
            "Save Claude Code Activity Card"
        } else {
            "Save Codex Activity Card"
        }
        panel.prompt = "Save"

        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(nil)
                return
            }
            do {
                try write(artifact, to: url)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    static func write(
        _ artifact: CodexDashboardCaptureArtifact,
        to url: URL
    ) throws {
        try artifact.pngData.write(to: url, options: .atomic)
    }

    static func copy(
        _ artifact: CodexDashboardCaptureArtifact,
        to pasteboard: NSPasteboard = .general
    ) throws {
        pasteboard.clearContents()
        guard pasteboard.setData(artifact.pngData, forType: .png) else {
            throw CodexDashboardCaptureError.pasteboardWriteFailed
        }
    }

    static func temporaryShareURL(
        for artifact: CodexDashboardCaptureArtifact,
        directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let url = directory.appendingPathComponent(
            artifact.fileName,
            isDirectory: false
        )
        try write(artifact, to: url)
        return url
    }

    static func defaultFileName(
        at date: Date,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "DockMagic-Codex-\(formatter.string(from: date)).png"
    }

    static func defaultClaudeCodeFileName(
        at date: Date,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "DockMagic-Claude-Code-\(formatter.string(from: date)).png"
    }

    static func activityCardFileName(
        for brand: StreakServiceBrand,
        at date: Date,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let provider = switch brand {
        case .codex: "Codex"
        case .claudeCode: "Claude-Code"
        case .antigravity: "Antigravity"
        }
        return "DockMagic-\(provider)-Activity-\(formatter.string(from: date)).png"
    }

    static func antigravityQuotaCardFileName(
        at date: Date,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "DockMagic-Antigravity-Quota-\(formatter.string(from: date)).png"
    }

    static func antigravityAvailabilityCardFileName(
        at date: Date,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "DockMagic-Antigravity-Availability-\(formatter.string(from: date)).png"
    }
}

@MainActor
private struct AntigravityQuotaShareCard: View {
    let quota: AntigravityQuotaSnapshot
    let isStale: Bool

    @Environment(\.designTheme) private var theme
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides

    private let maximumVisibleBuckets = 4
    private var isDense: Bool { quota.buckets.count > 2 }

    var body: some View {
        ZStack(alignment: .top) {
            theme.opaqueSurface

            header
                .padding(.horizontal, 14)
                .padding(.top, 11)

            VStack(alignment: .leading, spacing: 0) {
                Text("MODEL-POOL QUOTA")
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(theme.textSecondary)

                Spacer(minLength: isDense ? 3 : 8)

                VStack(alignment: .leading, spacing: isDense ? 3 : 16) {
                    ForEach(Array(quota.buckets.prefix(maximumVisibleBuckets))) {
                        bucket in
                        quotaRow(bucket)
                    }
                }

                Spacer(minLength: isDense ? 3 : 8)

                if quota.buckets.count > maximumVisibleBuckets {
                    Text("+\(quota.buckets.count - maximumVisibleBuckets) model \(quota.buckets.count - maximumVisibleBuckets == 1 ? "pool" : "pools") omitted")
                        .font(.system(size: isDense ? 7 : 7.5, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .frame(height: isDense ? 228 : 220)
            .padding(.horizontal, 14)
            .padding(.top, isDense ? 38 : 43)

            Text("DockMagic")
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 8)
        }
        .frame(width: 300, height: 300)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Antigravity model-pool quota card")
        .accessibilityValue(accessibilityValue)
    }

    private var header: some View {
        HStack(spacing: 8) {
            PreservedVectorAssetImage(
                assetName: StreakServiceBrand.antigravity.logoAssetName
            )
            .scaledToFit()
            .frame(width: 22, height: 22)
            .clipShape(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .accessibilityHidden(true)

            Text("Antigravity")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 8)

            Text("\(isStale ? "LAST KNOWN" : "CHECKED") · \(Self.shortDate(quota.fetchedAt))")
                .font(.system(size: 7.5, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(height: 22)
    }

    private func quotaRow(_ bucket: AntigravityQuotaBucket) -> some View {
        let remaining = min(1, max(0, bucket.remainingFraction))
        let progressFill = remaining <= 0.05 ? theme.danger
            : remaining <= 0.2 ? theme.warning : theme.action
        let valueForeground = remaining <= 0.05 ? theme.dangerForeground
            : remaining <= 0.2 ? theme.warningForeground : theme.textPrimary
        return VStack(alignment: .leading, spacing: isDense ? 1 : 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(bucket.groupName)
                    .font(.system(size: isDense ? 8.5 : 11, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(Int((remaining * 100).rounded()))%")
                        .font(.system(
                            size: isDense ? 13 : 27,
                            weight: .black,
                            design: .rounded
                        ))
                        .foregroundStyle(valueForeground)
                        .monospacedDigit()

                    Text("LEFT")
                        .font(.system(size: isDense ? 6 : 7.5, weight: .bold))
                        .tracking(0.9)
                        .foregroundStyle(theme.textSecondary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            Text(bucket.title == bucket.windowTitle
                 ? "\(bucket.windowTitle) window"
                 : "\(bucket.title) · \(bucket.windowTitle) window")
                .font(.system(size: isDense ? 7 : 8, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.outlineStrong)
                    Capsule()
                        .fill(progressFill)
                        .frame(width: geometry.size.width * CGFloat(remaining))
                }
            }
            .frame(height: isDense ? 4 : 7)
            .overlay {
                Capsule().strokeBorder(
                    theme.outlineStrong,
                    lineWidth: accessibilityOverrides.increaseContrast == true
                        ? 1.25 : 0.75
                )
            }
            .accessibilityHidden(true)

            Text(bucket.resetsAt.map {
                "Resets \($0.formatted(.dateTime.year().month(.abbreviated).day().hour().minute()))"
            } ?? "Reset time unavailable")
            .font(.system(size: isDense ? 7 : 8, weight: .medium))
            .foregroundStyle(theme.textSecondary)
        }
    }

    private var accessibilityValue: String {
        let poolValues = quota.buckets.prefix(maximumVisibleBuckets).map { bucket in
            let remaining = min(1, max(0, bucket.remainingFraction))
            let reset = bucket.resetsAt.map { "resets \($0.formatted())" }
                ?? "reset time unavailable"
            return "\(bucket.groupName), \(bucket.title), \(bucket.windowTitle) window, \(Int((remaining * 100).rounded())) percent remaining, \(reset)"
        }
        let additionalCount = quota.buckets.count - poolValues.count
        let omitted = additionalCount > 0
            ? ". \(additionalCount) more pools are not shown on this card"
            : ""
        return "\(isStale ? "Last known. " : "")\(poolValues.joined(separator: ". "))\(omitted). Checked \(quota.fetchedAt.formatted())."
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date).localizedUppercase
    }
}

/// A purpose-built activity image shared by Save, Copy, and Share so every
/// export tells the same focused badge, token, and momentum story.
@MainActor
private struct DockMagicUsageActivityCard: View {
    let tokenUsage: CodexAccountTokenUsage?
    let streakSummary: TokenUsageStreakSummary?
    let momentum: CodexShipMomentum?
    let brand: StreakServiceBrand
    let now: Date
    let dataTimestamp: Date
    let isStale: Bool
    let isHistoryPartial: Bool
    let showsUnavailableChartCue: Bool
    let datePrefixOverride: String?
    let isAvailabilityCard: Bool

    @Environment(\.designTheme) private var theme
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides

    private var milestone: TokenUsageStreakMilestone? {
        streakSummary?.earnedBadge
    }
    private var displayedMilestone: TokenUsageStreakMilestone {
        milestone ?? .firstPrompt
    }
    private var accent: Color {
        brand == .claudeCode ? ProjectTheme.claudeCodeUsage : theme.action
    }
    private var strongOutlineWidth: CGFloat {
        accessibilityOverrides.increaseContrast == true ? 1.5 : 0.75
    }
    private var chartSamples: [Int64?] {
        CodexDashboardCaptureService.activityCardChartSamples(
            from: tokenUsage,
            now: now
        )
    }
    private var showsChart: Bool {
        CodexDashboardCaptureService.activityCardChartHasRenderableTrend(
            chartSamples
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            theme.opaqueSurface

            header
                .padding(.horizontal, 14)
                .padding(.top, 11)
                .zIndex(1)

            VStack(spacing: 0) {
                StreakBadgeView(
                    milestone: displayedMilestone,
                    size: 144,
                    isUnlocked: milestone != nil
                )
                .accessibilityHidden(true)

                Text("CURRENT BADGE")
                    .font(.system(size: 7, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.top, 1)

                Text(milestone?.title.localizedUppercase ?? "READY TO BEGIN")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
                    .padding(.horizontal, 8)

                Text(badgeSubtitle)
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.top, 1)

                divider
                    .padding(.top, 5)

                tokenMetric
                    .padding(.top, 3)

                shipMomentum
                    .padding(.top, 5)

                Text("DockMagic")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 8)
        }
        .frame(
            width: CodexDashboardCaptureService.activityCardSize.width,
            height: CodexDashboardCaptureService.activityCardSize.height
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isAvailabilityCard
                ? "\(brand.displayName) activity availability card"
                : "\(brand.displayName) daily activity card"
        )
        .accessibilityValue(accessibilityValue)
    }

    private var header: some View {
        HStack(spacing: 8) {
            brandLogo

            Text(brand.displayName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 8)

            Text(Self.dateLabel(
                dataTimestamp,
                now: now,
                isStale: isStale,
                freshPrefix: datePrefixOverride
            ))
                .font(.system(size: 7.5, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(height: 22)
    }

    @ViewBuilder
    private var brandLogo: some View {
        if brand == .codex {
            PreservedVectorAssetImage(assetName: brand.logoAssetName)
                .scaledToFill()
                .frame(width: 34, height: 34)
                .frame(width: 22, height: 22)
                .clipShape(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .accessibilityHidden(true)
        } else {
            PreservedVectorAssetImage(assetName: brand.logoAssetName)
                .scaledToFit()
                .frame(width: 22, height: 22)
                .clipShape(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .accessibilityHidden(true)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.outline)
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }

    private var tokenMetric: some View {
        Group {
            if showsChart {
                HStack(alignment: .center, spacing: 12) {
                    tokenMetricText(alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    UsageActivityMiniAreaChart(
                        samples: chartSamples,
                        accent: accent
                    )
                    .frame(width: 82, height: 29)
                    .frame(width: 88, alignment: .trailing)
                }
            } else if showsUnavailableChartCue {
                HStack(alignment: .center, spacing: 12) {
                    tokenMetricText(alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    UsageActivityUnavailableChartCue()
                        .frame(width: 82, height: 29)
                        .frame(width: 88, alignment: .trailing)
                }
            } else {
                tokenMetricText(alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func tokenMetricText(
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(Self.tokenLabel(momentum?.todayTokens))
                .font(.system(size: 33, weight: .black, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(
                isAvailabilityCard ? "TOKENS UNAVAILABLE"
                    : isHistoryPartial ? "TOKENS OBSERVED TODAY" : "TOKENS TODAY"
            )
                .font(.system(size: isHistoryPartial ? 6.5 : 7.5, weight: .bold))
                .tracking(isHistoryPartial ? 0.72 : 1.4)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }

    private var shipMomentum: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("SHIP MOMENTUM")
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(theme.textSecondary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(theme.outlineStrong)
                        Capsule()
                            .fill(accent)
                            .frame(
                                width: geometry.size.width
                                    * CGFloat(momentum?.score ?? 0) / 100
                            )
                    }
                }
                .frame(height: 7)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            theme.outlineStrong,
                            lineWidth: strongOutlineWidth
                        )
                }
                .accessibilityHidden(true)
            }

            VStack(alignment: .trailing, spacing: 0) {
                Text(momentum.map { "\($0.score) / 100" } ?? "— / 100")
                    .font(.system(size: 12.5, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .monospacedDigit()

                Text(momentum?.rank.title.localizedUppercase ?? "UNAVAILABLE")
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(0.9)
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(minWidth: 64, alignment: .trailing)
        }
    }

    private var badgeSubtitle: String {
        guard let milestone else { return "NO BADGE YET" }
        return "\(milestone.requiredDays)-DAY BADGE"
    }

    private var accessibilityValue: String {
        let badge = milestone?.title ?? "No badge earned"
        let tokens = momentum?.todayTokens.formatted() ?? "unavailable"
        let ship = momentum.map {
            "\($0.score) out of 100, rank \($0.rank.title)"
        } ?? "unavailable"
        let history = showsChart
            ? isHistoryPartial
                ? "Partial locally observed 14-day token history."
                : "14-day token history."
            : "Token history unavailable."
        let dailyLabel = isAvailabilityCard ? "Tokens unavailable"
            : isHistoryPartial ? "Tokens observed today" : "Tokens today"
        let freshness = isStale ? "Last known at \(dataTimestamp.formatted()). " : ""
        let source = isAvailabilityCard
            ? "Quota was checked at \(dataTimestamp.formatted()); activity was not observed. "
            : ""
        return "\(freshness)\(source)Badge: \(badge). \(dailyLabel): \(tokens). \(history) Ship momentum: \(ship)."
    }

    private static func dateLabel(
        _ date: Date,
        now: Date,
        isStale: Bool,
        freshPrefix: String?
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MMM d, yyyy"
        let prefix = isStale || !Calendar.current.isDate(date, inSameDayAs: now)
            ? "LAST KNOWN" : freshPrefix ?? "TODAY"
        return "\(prefix) · \(formatter.string(from: date).localizedUppercase)"
    }

    private static func tokenLabel(_ tokens: Int64?) -> String {
        guard let tokens else { return "—" }
        let amount = max(0, tokens)
        let units: [(threshold: Int64, suffix: String)] = [
            (1_000_000_000, "B"),
            (1_000_000, "M"),
            (1_000, "K")
        ]
        guard let unit = units.first(where: { amount >= $0.threshold }) else {
            return amount.formatted(
                .number.locale(Locale(identifier: "en_US_POSIX"))
            )
        }
        let value = Double(amount) / Double(unit.threshold)
        let precision = value >= 100 ? 0 : value >= 10 ? 1 : 2
        return String(format: "%.*f", precision, value) + unit.suffix
    }
}

private struct UsageActivityUnavailableChartCue: View {
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: "chart.xyaxis.line")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 15, weight: .medium))

            Text("NO HISTORY")
                .font(.system(size: 6, weight: .bold))
                .tracking(0.5)
        }
        .foregroundStyle(theme.textSecondary)
        .accessibilityHidden(true)
    }
}

private struct UsageActivityMiniAreaChart: View {
    let samples: [Int64?]
    let accent: Color

    @Environment(\.designTheme) private var theme
    @Environment(\.dsAccessibilityOverrides) private var accessibilityOverrides

    var body: some View {
        ZStack {
            UsageActivityAreaShape(samples: samples)
                .fill(
                    accent.opacity(
                        accessibilityOverrides.increaseContrast == true
                            ? 0.28
                            : 0.18
                    )
                )

            UsageActivityLineShape(samples: samples)
                .stroke(
                    accent,
                    style: StrokeStyle(
                        lineWidth: accessibilityOverrides.increaseContrast == true
                            ? 1.25
                            : 1,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

            UsageActivityMissingSamplesShape(samples: samples)
                .stroke(
                    theme.outlineStrong,
                    style: StrokeStyle(
                        lineWidth: accessibilityOverrides.increaseContrast == true
                            ? 1
                            : 0.75,
                        lineCap: .round,
                        dash: [1.5, 1.25]
                    )
                )
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

private struct UsageActivityAreaShape: Shape {
    let samples: [Int64?]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for segment in UsageActivityChartGeometry.segments(
            samples: samples,
            rect: rect
        ) where segment.count >= 2 {
            guard let first = segment.first, let last = segment.last else {
                continue
            }
            path.move(to: CGPoint(x: first.x, y: rect.maxY))
            path.addLine(to: first)
            for point in segment.dropFirst() {
                path.addLine(to: point)
            }
            path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

private struct UsageActivityLineShape: Shape {
    let samples: [Int64?]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for segment in UsageActivityChartGeometry.segments(
            samples: samples,
            rect: rect
        ) where segment.count >= 2 {
            guard let first = segment.first else { continue }
            path.move(to: first)
            for point in segment.dropFirst() {
                path.addLine(to: point)
            }
        }
        return path
    }
}

private struct UsageActivityMissingSamplesShape: Shape {
    let samples: [Int64?]

    func path(in rect: CGRect) -> Path {
        guard samples.count > 1 else { return Path() }
        let step = rect.width / CGFloat(samples.count - 1)
        var path = Path()
        for index in samples.indices where samples[index] == nil {
            let x = rect.minX + CGFloat(index) * step
            path.move(to: CGPoint(x: max(rect.minX, x - 1.5), y: rect.maxY - 0.5))
            path.addLine(to: CGPoint(x: min(rect.maxX, x + 1.5), y: rect.maxY - 0.5))
        }
        return path
    }
}

private enum UsageActivityChartGeometry {
    static func segments(
        samples: [Int64?],
        rect: CGRect
    ) -> [[CGPoint]] {
        guard samples.count > 1 else { return [] }
        let maximum = max(1, samples.compactMap { $0 }.max() ?? 1)
        let step = rect.width / CGFloat(samples.count - 1)
        let drawableHeight = max(1, rect.height - 1.5)
        var result: [[CGPoint]] = []
        var current: [CGPoint] = []

        for (index, sample) in samples.enumerated() {
            guard let sample else {
                if !current.isEmpty { result.append(current) }
                current = []
                continue
            }
            let fraction = CGFloat(max(0, sample)) / CGFloat(maximum)
            current.append(
                CGPoint(
                    x: rect.minX + CGFloat(index) * step,
                    y: rect.maxY - 0.5 - drawableHeight * fraction
                )
            )
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}

private extension CodexUsageState {
    var isStale: Bool {
        if case .stale = self { return true }
        return false
    }
}

private extension AntigravityUsageState {
    var isStale: Bool {
        if case .stale = self { return true }
        return false
    }
}
