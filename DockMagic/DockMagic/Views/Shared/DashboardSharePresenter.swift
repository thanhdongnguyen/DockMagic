import AppKit
import SwiftUI

struct DashboardSharePresenter: NSViewRepresentable {
    @Binding var itemURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let itemURL else {
            context.coordinator.presentedURL = nil
            return
        }
        guard context.coordinator.presentedURL != itemURL else {
            return
        }
        context.coordinator.presentedURL = itemURL
        let itemBinding = $itemURL
        let coordinator = context.coordinator

        DispatchQueue.main.async {
            let picker = NSSharingServicePicker(items: [itemURL])
            coordinator.present(picker, relativeTo: nsView)
            itemBinding.wrappedValue = nil
        }
    }

    static func dismantleNSView(
        _ nsView: NSView,
        coordinator: Coordinator
    ) {
        coordinator.endPresentation(closePicker: true)
    }

    @MainActor
    final class Coordinator: NSObject,
        NSSharingServicePickerDelegate,
        NSSharingServiceDelegate
    {
        var presentedURL: URL?
        private var picker: NSSharingServicePicker?
        private weak var presentingWindow: NSWindow?
        private var presentingWindowLevel: NSWindow.Level?

        func present(
            _ picker: NSSharingServicePicker,
            relativeTo sourceView: NSView
        ) {
            endPresentation(closePicker: true)

            if let window = sourceView.window,
               window.level
                    > DockHoverPanelPlacement.sharePresentationWindowLevel {
                presentingWindow = window
                presentingWindowLevel = window.level
                window.level = DockHoverPanelPlacement
                    .sharePresentationWindowLevel
            }

            self.picker = picker
            picker.delegate = self
            picker.show(
                relativeTo: sourceView.bounds,
                of: sourceView,
                preferredEdge: .minY
            )
        }

        func sharingServicePicker(
            _ sharingServicePicker: NSSharingServicePicker,
            delegateFor sharingService: NSSharingService
        ) -> (any NSSharingServiceDelegate)? {
            self
        }

        func sharingServicePicker(
            _ sharingServicePicker: NSSharingServicePicker,
            didChoose service: NSSharingService?
        ) {
            guard service == nil else {
                return
            }
            endPresentation(closePicker: false)
        }

        func sharingService(
            _ sharingService: NSSharingService,
            didShareItems items: [Any]
        ) {
            endPresentation(closePicker: false)
        }

        func sharingService(
            _ sharingService: NSSharingService,
            didFailToShareItems items: [Any],
            error: any Error
        ) {
            endPresentation(closePicker: false)
        }

        func endPresentation(closePicker: Bool) {
            let activePicker = picker
            picker = nil
            activePicker?.delegate = nil
            if closePicker {
                activePicker?.close()
            }

            if let presentingWindow, let presentingWindowLevel {
                presentingWindow.level = presentingWindowLevel
            }
            presentingWindow = nil
            presentingWindowLevel = nil
        }
    }
}

#if DEBUG
extension CodexRateLimitSnapshot {
    static var hoverDesignPreview: Self {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 26
        ))!
        let values: [Int64] = [
            0, 120_000, 510_000, 940_000, 1_080_000,
            260_000, 420_000, 1_120_000, 0, 1_340_000,
            180_000, 670_000, 1_460_000, 310_000, 720_000,
            1_280_000, 770_000, 1_020_000, 590_000, 1_390_000,
            800_000, 1_180_000, 1_000_000, 980_000, 1_320_000,
            1_560_000, 1_210_000, 1_010_000, 730_000, 1_280_000
        ]
        let detailDate = calendar.date(
            byAdding: .day,
            value: values.count - 1,
            to: start
        )!
        func breakdown(
            total: Int64,
            cachedFraction: Double
        ) -> CodexTokenBreakdown {
            let output = max(1, total / 30)
            let input = max(0, total - output)
            return CodexTokenBreakdown(
                inputTokens: input,
                cachedInputTokens: Int64(
                    (Double(input) * cachedFraction).rounded()
                ),
                cacheWriteInputTokens: 0,
                outputTokens: output,
                reasoningOutputTokens: output / 3,
                totalTokens: total
            )
        }
        let hourlyTotals: [Int64] = [
            5_000, 10_000, 15_000, 15_000, 10_000, 15_000,
            30_000, 40_000, 60_000, 110_000, 70_000, 45_000,
            40_000, 60_000, 100_000, 75_000, 35_000, 25_000,
            35_000, 40_000, 45_000, 60_000, 75_000, 40_000
        ]
        let hourlyUsage = hourlyTotals.enumerated().map { hour, total in
            CodexHourlyTokenUsageBucket(
                startDate: calendar.date(
                    byAdding: .hour,
                    value: hour,
                    to: detailDate
                )!,
                usage: breakdown(total: total, cachedFraction: 0.88)
            )
        }
        let detailUsage = hourlyUsage.reduce(CodexTokenBreakdown.zero) {
            $0.adding($1.usage)
        }
        return Self(
            planType: "pro",
            limitID: "codex",
            fiveHour: CodexRateLimitWindow(
                kind: .fiveHour,
                usedPercent: 26,
                windowDurationMinutes: 300,
                resetsAt: calendar.date(from: DateComponents(
                    year: 2026,
                    month: 8,
                    day: 24,
                    hour: 2,
                    minute: 40
                ))
            ),
            weekly: CodexRateLimitWindow(
                kind: .weekly,
                usedPercent: 59,
                windowDurationMinutes: 10_080,
                resetsAt: calendar.date(from: DateComponents(
                    year: 2026,
                    month: 8,
                    day: 28,
                    hour: 9,
                    minute: 15
                ))
            ),
            tokenUsage: CodexAccountTokenUsage(
                lifetimeTokens: 18_400_000,
                peakDailyTokens: 1_560_000,
                longestRunningTurnSeconds: 1_460,
                dailyUsageBuckets: values.enumerated().map { index, tokens in
                    CodexTokenUsageDailyBucket(
                        startDate: calendar.date(
                            byAdding: .day,
                            value: index,
                            to: start
                        )!,
                        tokens: tokens
                    )
                },
                modelUsage: [
                    CodexModelTokenUsage(model: "gpt-5.6", tokens: 8_400_000),
                    CodexModelTokenUsage(model: "gpt-5.5", tokens: 5_700_000),
                    CodexModelTokenUsage(model: "gpt-5.4", tokens: 2_900_000)
                ],
                isModelUsagePartial: false,
                localDailyDetails: [
                    CodexDailyTokenDetail(
                        startDate: detailDate,
                        usage: detailUsage,
                        hourlyUsage: hourlyUsage,
                        modelUsage: [
                            CodexDailyModelTokenUsage(
                                model: "gpt-5.6-sol",
                                usage: breakdown(
                                    total: 780_000,
                                    cachedFraction: 0.90
                                )
                            ),
                            CodexDailyModelTokenUsage(
                                model: "codex-auto-review",
                                usage: breakdown(
                                    total: 180_000,
                                    cachedFraction: 0.84
                                )
                            ),
                            CodexDailyModelTokenUsage(
                                model: "gpt-5.5",
                                usage: breakdown(
                                    total: 95_000,
                                    cachedFraction: 0.81
                                )
                            )
                        ],
                        isPartial: false
                    )
                ]
            ),
            streakSummary: TokenUsageStreakSummary.fixture(
                currentDays: 7,
                bestDays: 28,
                endingAt: detailDate,
                calendar: calendar
            ),
            recentTaskActivity: CodexRecentTaskActivity(
                currentWeekCount: 12,
                previousWeekCount: 8,
                isPartial: false
            ),
            fetchedAt: calendar.date(from: DateComponents(
                year: 2026,
                month: 8,
                day: 25,
                hour: 12
            ))!
        )
    }
}
#endif
