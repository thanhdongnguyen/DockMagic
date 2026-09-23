import AppKit
import SwiftUI

/// Native tracking, keyboard adjustment and AX; Maia supplies drawing only.
final class DSMaiaSliderCell: NSSliderCell {
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        // AppKit's bar and knob bounds have different centers at some control
        // sizes. Align our track to the thumb while preserving native tracking.
        let centerY = knobRect(flipped: flipped).midY
        let track = NSRect(x: rect.minX, y: centerY - 6, width: rect.width, height: 12)
        NSColor(ProjectTheme.current.surfaceInset).setFill()
        NSBezierPath(roundedRect: track, xRadius: 6, yRadius: 6).fill()
        let fraction = maxValue > minValue ? min(max((doubleValue - minValue) / (maxValue - minValue), 0), 1) : 0
        let fill = NSRect(x: track.minX, y: track.minY, width: track.width * fraction, height: track.height)
        NSColor(ProjectTheme.current.action).withAlphaComponent(isEnabled ? 1 : 0.5).setFill()
        NSBezierPath(roundedRect: fill, xRadius: 6, yRadius: 6).fill()
    }

    override func knobRect(flipped: Bool) -> NSRect {
        let native = super.knobRect(flipped: flipped)
        return NSRect(x: native.midX - 8, y: native.midY - 8, width: 16, height: 16)
    }

    override func drawKnob(_ knobRect: NSRect) {
        // Preserve AppKit's native knob geometry for hit-testing, pointer
        // tracking, keyboard adjustment, and accessibility without rendering
        // a visible thumb. The filled track communicates the current value.
    }
}

class DSNativeSlider: NSSlider {
    var keyboardStep: Double?
    override func keyDown(with event: NSEvent) {
        guard isEnabled, let step = keyboardStep, step > 0,
              [123, 124, 125, 126].contains(event.keyCode) else { super.keyDown(with: event); return }
        let direction = (event.keyCode == 124 || event.keyCode == 126) ? 1.0 : -1.0
        doubleValue = min(max(doubleValue + direction * step, minValue), maxValue)
        sendAction(action, to: target)
        needsDisplay = true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        cell = DSMaiaSliderCell()
        isContinuous = true
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        cell = DSMaiaSliderCell()
    }
}

struct DSSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil
    @Environment(\.isEnabled) private var enabled

    init(value: Binding<Double>, in range: ClosedRange<Double>, step: Double? = nil) {
        _value = value
        self.range = range
        self.step = step
    }
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeNSView(context: Context) -> DSNativeSlider {
        let slider = DSNativeSlider(frame: .zero)
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.changed(_:))
        updateNSView(slider, context: context)
        return slider
    }
    func updateNSView(_ slider: DSNativeSlider, context: Context) {
        context.coordinator.parent = self
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.doubleValue = value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : range.lowerBound
        slider.isEnabled = enabled
        slider.keyboardStep = step
        slider.needsDisplay = true
    }
    final class Coordinator: NSObject {
        var parent: DSSlider
        init(parent: DSSlider) { self.parent = parent }
        @objc func changed(_ sender: NSSlider) {
            let raw = sender.doubleValue
            let snapped = parent.step.flatMap { $0 > 0 ? $0 : nil }.map {
                parent.range.lowerBound + ((raw - parent.range.lowerBound) / $0).rounded() * $0
            } ?? raw
            let value = min(max(snapped, parent.range.lowerBound), parent.range.upperBound)
            sender.doubleValue = value
            parent.value = value
        }
    }
}
