import SwiftUI

struct AntigravityQuotaRows: View {
    let state: CodexUsageState
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            if let group = state.snapshot?.antigravityTelemetry?.selectedGroup, !group.buckets.isEmpty {
                ForEach(group.buckets.prefix(4)) { bucket in row(bucket) }
            } else {
                HStack {
                    Image(systemName: "gauge.with.dots.needle.33percent").accessibilityHidden(true)
                    Text("Quota unavailable")
                    Spacer()
                    Text("—").monospacedDigit()
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .padding(12)
            }
        }
    }

    private func row(_ bucket: AntigravityQuotaBucket) -> some View {
        VStack(spacing: 3) {
            HStack {
                Label(bucket.title, systemImage: bucket.kind == .weekly ? "calendar" : "clock")
                    .font(.system(size: 10.5, weight: .semibold))
                Spacer(minLength: 6)
                Text(bucket.remainingFraction.map { "\(Int(($0 * 100).rounded()))% left" } ?? "Unavailable")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(theme.textPrimary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.dockTrack)
                    if let fraction = bucket.remainingFraction {
                        Capsule().fill(accent(fraction)).frame(width: proxy.size.width * fraction)
                    }
                }
            }
            .frame(height: 5)
            HStack {
                Text(resetLabel(bucket))
                Spacer()
                if bucket.kind == nil { Text("Window not reported") }
            }
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(theme.textTertiary)
            .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(theme.opaqueSurfaceInset, in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(theme.outline, lineWidth: 0.5) }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("antigravity.quota.\(bucket.id)")
    }

    private func accent(_ fraction: Double) -> Color {
        fraction <= 0.1 ? theme.danger : fraction <= 0.25 ? theme.warning : theme.action
    }

    private func resetLabel(_ bucket: AntigravityQuotaBucket) -> String {
        if let date = bucket.resetsAt { return "Resets \(date.formatted(date: .abbreviated, time: .shortened))" }
        return bucket.resetDescription ?? "Reset time unavailable"
    }
}
