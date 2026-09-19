import SwiftUI

private struct DSIconSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 16
}

extension EnvironmentValues {
    var dsIconSize: CGFloat {
        get { self[DSIconSizeKey.self] }
        set { self[DSIconSizeKey.self] = newValue }
    }
}

struct DSIcon: View {
    let name: DSIconName
    var size: CGFloat?
    private var stretches = false
    @Environment(\.dsIconSize) private var inheritedSize

    init(_ name: DSIconName, size: CGFloat? = nil) {
        self.name = name
        self.size = size
    }

    /// Boundary for existing domain models that also supply native menu icons.
    init(systemName: String) {
        let resolved = DSIconName.fromLegacySymbol(systemName)
        assert(resolved != nil, "Unmapped Maia icon: \(systemName)")
        name = resolved ?? .help
    }

    var body: some View {
        if stretches {
            Image(name.rawValue).resizable().scaledToFit()
        } else {
            Image(name.rawValue).resizable().scaledToFit()
                .frame(width: size ?? inheritedSize, height: size ?? inheritedSize)
        }
    }

    func resizable() -> Self {
        var result = self
        result.stretches = true
        return result
    }
}

struct DSLabel: View {
    let title: String
    let icon: DSIconName

    init(_ title: String, icon: DSIconName) {
        self.title = title
        self.icon = icon
    }

    init(_ title: String, systemImage: String) {
        self.init(title, icon: DSIconName.fromLegacySymbol(systemImage) ?? .help)
    }

    var body: some View {
        Label { Text(title) } icon: { DSIcon(icon).accessibilityHidden(true) }
    }
}

extension View {
    /// Proportional renderer typography also supplies the adjacent icon size.
    func dsFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        font(DSTypography.font(size: size, weight: weight, design: design))
            .environment(\.dsIconSize, size)
    }
}
