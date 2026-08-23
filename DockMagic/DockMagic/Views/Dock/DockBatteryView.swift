import SwiftUI

struct DockBatteryView: View {
    let snapshot: BatteryMetricsSnapshot
    let errorDescription: String?
    let animatesChanges: Bool

    @Environment(\.designTheme) private var theme

    var body: some View {
        BatteryDockTileSurface { side in
            if snapshot.dockDevices.isEmpty {
                Image(systemName: errorDescription == nil
                    ? "battery.0percent"
                    : "exclamationmark.triangle.fill")
                    .font(.system(size: side * 0.31, weight: .medium))
                    .foregroundStyle(
                        errorDescription == nil
                            ? theme.dockOutline
                            : theme.dangerForeground
                    )
            } else {
                BatteryDeviceGrid(
                    devices: snapshot.dockDevices,
                    side: side,
                    animatesChanges: animatesChanges
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery levels")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("dock.batteries")
    }

    private var accessibilityValue: String {
        if let errorDescription, snapshot.devices.isEmpty {
            return "Unavailable, \(errorDescription)"
        }
        if snapshot.devices.isEmpty {
            return "No battery-powered devices detected"
        }
        return snapshot.dockDevices.map {
            "\($0.name) \($0.percentage) percent, \($0.detail)"
        }.joined(separator: ", ")
    }
}

private struct BatteryDockTileSurface<Content: View>: View {
    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast

    private let content: (CGFloat) -> Content

    init(@ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let shape = RoundedRectangle(
                cornerRadius: side * 0.22,
                style: .continuous
            )

            ZStack {
                shape.fill(
                    LinearGradient(
                        colors: [
                            theme.dockBackgroundRaised,
                            theme.dockBackgroundInset
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                shape.strokeBorder(
                    theme.dockOutline.opacity(
                        contrast == .increased ? 0.9 : 0.48
                    ),
                    lineWidth: contrast == .increased ? 2 : 1.25
                )

                content(side)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct BatteryDeviceGrid: View {
    let devices: [BatteryDeviceSnapshot]
    let side: CGFloat
    let animatesChanges: Bool

    var body: some View {
        ZStack {
            ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                BatteryRing(
                    device: device,
                    diameter: diameter,
                    tileSide: side,
                    animatesChanges: animatesChanges
                )
                .position(position(for: index))
                .transition(.scale(scale: 0.82).combined(with: .opacity))
            }
        }
        .frame(width: side, height: side)
        .animation(animation, value: devices.map(\.id))
    }

    private var diameter: CGFloat {
        switch devices.count {
        case 1:
            side * 0.68
        case 2:
            side * 0.43
        default:
            side * 0.36
        }
    }

    private func position(for index: Int) -> CGPoint {
        switch devices.count {
        case 1:
            CGPoint(x: side * 0.5, y: side * 0.5)
        case 2:
            CGPoint(
                x: side * (index == 0 ? 0.28 : 0.72),
                y: side * 0.5
            )
        case 3:
            if index == 2 {
                CGPoint(x: side * 0.5, y: side * 0.71)
            } else {
                CGPoint(
                    x: side * (index == 0 ? 0.29 : 0.71),
                    y: side * 0.29
                )
            }
        default:
            CGPoint(
                x: side * (index.isMultiple(of: 2) ? 0.29 : 0.71),
                y: side * (index < 2 ? 0.29 : 0.71)
            )
        }
    }

    private var animation: Animation? {
        animatesChanges ? DSMotion.metricChange : nil
    }
}

private struct BatteryRing: View {
    let device: BatteryDeviceSnapshot
    let diameter: CGFloat
    let tileSide: CGFloat
    let animatesChanges: Bool

    @Environment(\.designTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    contrast == .increased
                        ? theme.dockOutline
                        : Color.white.opacity(0.2),
                    lineWidth: lineWidth
                )

            if device.level >= 1 {
                Circle()
                    .stroke(tint, lineWidth: lineWidth)
            } else if device.level > 0 {
                Circle()
                    .trim(from: 0, to: device.level)
                    .stroke(
                        tint,
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
            }

            BatteryDeviceGlyph(
                kind: device.kind,
                color: theme.dockOutline,
                size: diameter * 0.34
            )

            if device.showsPowerIndicator {
                Image(systemName: "bolt.fill")
                    .font(.system(size: diameter * 0.22, weight: .black))
                    .foregroundStyle(tint)
                    .padding(diameter * 0.025)
                    .background(Circle().fill(theme.dockBackgroundRaised))
                    .offset(y: -diameter * 0.48)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(animation, value: device.level)
    }

    private var lineWidth: CGFloat {
        max(3, tileSide * 0.035)
    }

    private var tint: Color {
        BatteryLevelStyle.color(for: device.level, theme: theme)
    }

    private var animation: Animation? {
        guard animatesChanges, !reduceMotion else {
            return nil
        }
        return DSMotion.metricChange
    }
}

struct BatteryDeviceGlyph: View {
    let kind: BatteryDeviceKind
    let color: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: kind.systemImage)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(color)
            .symbolRenderingMode(.monochrome)
            .accessibilityHidden(true)
    }
}

enum BatteryLevelStyle {
    static let healthy = Color(
        red: 52 / 255,
        green: 211 / 255,
        blue: 102 / 255
    )
    static let low = Color(
        red: 1,
        green: 171 / 255,
        blue: 42 / 255
    )
    static let critical = Color(
        red: 1,
        green: 86 / 255,
        blue: 86 / 255
    )

    static func role(for level: Double) -> DSSemanticRole {
        if level < 0.2 {
            return .danger
        }
        if level < 0.5 {
            return .warning
        }
        return .processing
    }

    static func color(for level: Double, theme: DesignTheme) -> Color {
        switch role(for: level) {
        case .danger:
            critical
        case .warning:
            low
        case .processing:
            healthy
        case .neutral, .information:
            healthy
        }
    }

    static func foreground(for level: Double, theme: DesignTheme) -> Color {
        color(for: level, theme: theme)
    }
}
