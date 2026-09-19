import AppKit
import SwiftUI

struct DSPlanBadge: View {
    let plan: String
    var providerName: String = "Codex"

    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                DSIcon(systemName: systemImage)
                    .symbolRenderingMode(.monochrome)
                    .dsFont(size: 9, weight: .bold)
                    .accessibilityHidden(true)
            }

            Text(plan.localizedUppercase)
                .dsFont(size: 10, weight: isPremium ? .bold : .semibold)
                .tracking(isPremium ? 0.25 : 0)
        }
        .foregroundStyle(isPremium ? theme.textPrimary : theme.textSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .circular).fill(
                isPremium ? theme.opaqueSurfaceInset : theme.opaqueSurfaceRaised
            )
        )
        .overlay {
            Capsule(style: .circular).strokeBorder(
                isPremium ? theme.outlineStrong : theme.outline,
                lineWidth: isPremium ? 1.25 : 1
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(providerName) \(plan.localizedCapitalized) plan")
    }

    private var normalizedPlan: String {
        plan.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isPremium: Bool {
        normalizedPlan == "pro" || normalizedPlan == "plus"
    }

    private var systemImage: String? {
        switch normalizedPlan {
        case "pro":
            "crown.fill"
        case "plus":
            "sparkles"
        default:
            nil
        }
    }
}
