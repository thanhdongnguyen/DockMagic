import AppKit
import Observation
import SwiftTerm
import SwiftUI

@MainActor
struct AntigravityConnectionSettingsView: View {
    let store: AntigravityUsageStore
    let installationState: DeveloperToolInstallationState
    let installCLI: () -> Void

    @State private var terminalSessionID: UUID?
    @State private var showsTerminal = false
    @State private var ignoresNextTerminalExit = false
    @State private var terminalController = AntigravityTerminalController()
    @FocusState private var focusedAction: FocusedAction?
    @Environment(\.designTheme) private var theme

    private enum FocusedAction: Hashable {
        case signIn
        case refresh
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.large) {
            connectionRow

            if let detail = presentation.detail {
                Text(detail)
                    .font(DSTypography.metadata)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(detailAccessibilityIdentifier)
            }

            if let terminalSessionID, let executableURL = store.executableURL {
                authenticationTerminal(
                    sessionID: terminalSessionID,
                    executableURL: executableURL
                )
                .frame(height: showsTerminal ? nil : 0)
                .clipped()
                .allowsHitTesting(showsTerminal)
                .accessibilityHidden(!showsTerminal)
            }
        }
        .padding(DSSpacing.xLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface(
            RoundedRectangle(
                cornerRadius: DSRadius.largePanel,
                style: .continuous
            ),
            kind: .raised,
            elevation: .primary
        )
    }

    private var connectionRow: some View {
        HStack(spacing: DSSpacing.standard) {
            Text("Antigravity connection")
                .font(DSTypography.sectionTitle)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: DSSpacing.section)

            if showsConnectionSummary {
                connectionSummary
            }
            actions
        }
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
    }

    private var connectionSummary: some View {
        HStack(spacing: DSSpacing.small) {
            if isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            } else if let systemImage = presentation.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        presentation.role == .neutral
                            ? theme.textSecondary
                            : theme.accentForeground(for: presentation.role)
                    )
                    .accessibilityHidden(true)
            }

            Text(presentation.title)
                .font(DSTypography.bodyEmphasis)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            if let metadata = presentation.metadata {
                Text(metadata)
                    .font(DSTypography.metadata)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .accessibilityIdentifier(detailAccessibilityIdentifier)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityIdentifier("settings.antigravity.connectionStatus")
    }

    @ViewBuilder
    private var actions: some View {
        switch store.connectionState {
        case .cliMissing:
            HStack(spacing: DSSpacing.small) {
                Button("Install agy", action: installCLI)
                    .buttonStyle(DSButtonStyle(kind: .primary))
                    .disabled(installationState == .installing)
                    .accessibilityIdentifier("settings.antigravity.install")
                if store.isBridgeInstalled { moreActions }
            }
        case .signedOut:
            HStack(spacing: DSSpacing.small) {
                Button("Sign in with Antigravity") {
                    startSignIn()
                }
                .buttonStyle(DSButtonStyle(kind: .primary))
                .focused($focusedAction, equals: .signIn)
                .accessibilityIdentifier("settings.antigravity.signIn")
                if store.isBridgeInstalled { moreActions }
            }
        case .connected:
            HStack(spacing: DSSpacing.small) {
                refreshButton
                moreActions
            }
        case .stale:
            HStack(spacing: DSSpacing.small) {
                Button("Retry") { Task { await store.refresh() } }
                    .buttonStyle(DSButtonStyle(kind: .primary))
                    .disabled(store.isRefreshing)
                    .accessibilityIdentifier("settings.antigravity.retry")
                moreActions
            }
        case .failed:
            HStack(spacing: DSSpacing.small) {
                Button("Retry") { Task { await store.refresh() } }
                    .buttonStyle(DSButtonStyle(kind: .primary))
                    .disabled(store.isRefreshing)
                    .accessibilityIdentifier("settings.antigravity.retry")
                if store.isBridgeInstalled { moreActions }
            }
        case .checking, .signingIn, .signingOut:
            EmptyView()
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await store.refresh() }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(DSIconButtonStyle(visualSize: 28, hitSize: 36))
        .disabled(store.isRefreshing)
        .focused($focusedAction, equals: .refresh)
        .help("Refresh Antigravity quota")
        .accessibilityLabel("Refresh Antigravity quota")
        .accessibilityIdentifier("settings.antigravity.refresh")
    }

    private var moreActions: some View {
        Menu {
            if terminalSessionID != nil {
                Button(showsTerminal ? "Hide authentication log" : "Show authentication log") {
                    showsTerminal.toggle()
                }
                .accessibilityIdentifier("settings.antigravity.showAuthLog")

                if store.isBridgeInstalled || canSignOut { Divider() }
            }

            if store.isBridgeInstalled {
                Button("Disconnect local session metrics") {
                    store.disconnectStatusLine()
                }
                .accessibilityIdentifier(
                    "settings.antigravity.disconnectSessionMetrics"
                )
                if store.bridgeErrorText != nil {
                    Text("Could not disconnect local session metrics. Try again.")
                        .foregroundStyle(theme.dangerForeground)
                }
                if canSignOut { Divider() }
            }

            if canSignOut {
                Button(role: .destructive) {
                    startSignOut()
                } label: {
                    Label(
                        "Sign Out",
                        systemImage: "rectangle.portrait.and.arrow.right"
                    )
                }
                .accessibilityIdentifier("settings.antigravity.signOut")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 28, height: 28)
                .background(
                    theme.opaqueSurfaceChrome,
                    in: RoundedRectangle(
                        cornerRadius: DSRadius.control,
                        style: .continuous
                    )
                )
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More Antigravity connection actions")
        .accessibilityLabel("More Antigravity connection actions")
        .accessibilityIdentifier("settings.antigravity.moreActions")
    }

    private var canSignOut: Bool {
        switch store.connectionState {
        case .connected, .stale:
            true
        case .cliMissing, .checking, .signedOut, .signingIn, .signingOut,
             .failed:
            false
        }
    }

    private func authenticationTerminal(
        sessionID: UUID,
        executableURL: URL
    ) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.standard) {
            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                Text("Sign in with Antigravity CLI")
                    .font(DSTypography.bodyEmphasis)
                    .foregroundStyle(theme.textPrimary)
                Text(
                    "Use the CLI below directly. Type or paste the Antigravity code with ⌘V, press Return, then choose Check connection. DockMagic does not store the code or credentials."
                )
                    .font(DSTypography.metadata)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AntigravityTerminalSurface(
                sessionID: sessionID,
                executableURL: executableURL,
                controller: terminalController
            ) { exitCode in
                Task { @MainActor in
                    if ignoresNextTerminalExit {
                        ignoresNextTerminalExit = false
                        return
                    }
                    guard exitCode == 0 else { return }
                    showsTerminal = false
                    await store.signInProcessDidFinish()
                    updateFocusAfterAuthentication()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 320)

            HStack(spacing: DSSpacing.small) {
                Button("Cancel") {
                    stopTerminal()
                    Task {
                        await store.cancelAuthentication()
                        updateFocusAfterAuthentication()
                    }
                }
                .buttonStyle(DSButtonStyle())
                .accessibilityIdentifier("settings.antigravity.cancelAuth")

                Button("Paste code") {
                    terminalController.paste()
                }
                .buttonStyle(DSButtonStyle())
                .help("Paste the clipboard into the Antigravity CLI")
                .accessibilityIdentifier("settings.antigravity.pasteCode")

                Button("Check connection") {
                    stopTerminal()
                    Task {
                        await store.signInProcessDidFinish()
                        updateFocusAfterAuthentication()
                    }
                }
                .buttonStyle(DSButtonStyle(kind: .primary))
                .accessibilityIdentifier("settings.antigravity.checkAuth")
            }
        }
    }

    private func startSignIn() {
        guard store.executableURL != nil else {
            installCLI()
            return
        }
        terminalController = AntigravityTerminalController()
        terminalSessionID = UUID()
        ignoresNextTerminalExit = false
        showsTerminal = true
        store.beginSignIn()
    }

    private func startSignOut() {
        showsTerminal = false
        terminalSessionID = nil
        Task {
            await store.signOut()
            updateFocusAfterAuthentication()
        }
    }

    private func stopTerminal() {
        ignoresNextTerminalExit = true
        terminalController.cancel()
        showsTerminal = false
    }

    private func updateFocusAfterAuthentication() {
        switch store.connectionState {
        case .connected, .stale:
            focusedAction = .refresh
        case .signedOut:
            focusedAction = .signIn
        case .cliMissing, .checking, .signingIn, .signingOut, .failed:
            break
        }
    }

    private var presentation: (
        title: String,
        detail: String?,
        metadata: String?,
        systemImage: String?,
        role: DSSemanticRole,
        accessibilityLabel: String
    ) {
        switch store.connectionState {
        case .cliMissing:
            return (
                "CLI required", nil, nil, "terminal", .warning,
                "Antigravity CLI required"
            )
        case .checking:
            return (
                "Checking", nil, nil, nil, .processing,
                "Checking Antigravity connection"
            )
        case .signedOut:
            return (
                "Not signed in", nil, nil,
                "person.crop.circle.badge.xmark", .warning,
                "Not signed in to Antigravity"
            )
        case .signingIn:
            return (
                "Signing in", nil, nil, nil, .processing,
                "Signing in to Antigravity"
            )
        case .signingOut:
            return (
                "Signing out", nil, nil, nil, .processing,
                "Signing out of Antigravity"
            )
        case let .connected(lastUpdated):
            return (
                "Connected", nil,
                "Updated \(relative(lastUpdated))",
                "checkmark.circle.fill", .information,
                "Connected to Antigravity, updated \(relative(lastUpdated))"
            )
        case let .stale(snapshot, message):
            return (
                "Last known quota", message,
                "Updated \(relative(snapshot.fetchedAt))",
                "clock.badge.exclamationmark", .warning,
                "Last known Antigravity quota, updated \(relative(snapshot.fetchedAt))"
            )
        case let .failed(message):
            return (
                "Connection failed", message, nil,
                "xmark.octagon.fill", .danger,
                "Antigravity connection failed"
            )
        }
    }

    private var isProcessing: Bool {
        switch store.connectionState {
        case .checking, .signingIn, .signingOut:
            true
        case .cliMissing, .signedOut, .connected, .stale, .failed:
            false
        }
    }

    private var showsConnectionSummary: Bool {
        switch store.connectionState {
        case .cliMissing, .signedOut:
            false
        case .checking, .signingIn, .signingOut, .connected, .stale, .failed:
            true
        }
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var detailAccessibilityIdentifier: String {
        switch store.connectionState {
        case .connected, .stale:
            "settings.antigravity.lastUpdated"
        case .cliMissing, .checking, .signedOut, .signingIn, .signingOut,
             .failed:
            "settings.antigravity.connectionDetail"
        }
    }
}

private struct AntigravityTerminalSurface: View {
    let sessionID: UUID
    let executableURL: URL
    let controller: AntigravityTerminalController
    let onExit: (Int32?) -> Void

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            terminalTitleBar

            Rectangle()
                .fill(theme.terminalOutline)
                .frame(height: 1)
                .accessibilityHidden(true)

            AntigravityTerminalView(
                sessionID: sessionID,
                executableURL: executableURL,
                controller: controller,
                onExit: onExit
            )
            .padding(.horizontal, DSSpacing.standard)
            .padding(.vertical, DSSpacing.standard)
            .background(theme.terminalBackground)
        }
        .background(theme.terminalBackground)
        .clipShape(
            RoundedRectangle(cornerRadius: DSRadius.row, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.row, style: .continuous)
                .strokeBorder(theme.terminalOutline, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private var terminalTitleBar: some View {
        ZStack {
            Text("Antigravity authentication")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.terminalSecondary)
                .lineLimit(1)
                .accessibilityIdentifier(
                    "settings.antigravity.terminal.title"
                )

            HStack(spacing: 0) {
                AntigravityTerminalTrafficLights()
                    .frame(width: 58, height: 18)
                    .accessibilityHidden(true)

                Spacer(minLength: DSSpacing.standard)

                Text("agy CLI")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.terminalForeground)
                    .padding(.horizontal, DSSpacing.standard)
                    .frame(height: 28)
                    .background(
                        theme.terminalBackground,
                        in: RoundedRectangle(
                            cornerRadius: DSRadius.control,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: DSRadius.control,
                            style: .continuous
                        )
                        .strokeBorder(theme.terminalOutline, lineWidth: 1)
                    }
                    .accessibilityLabel("agy CLI authentication session")
                    .accessibilityIdentifier(
                        "settings.antigravity.terminal.profile"
                    )
            }
        }
        .padding(.horizontal, DSSpacing.standard)
        .frame(height: 48)
        .background(theme.terminalChrome)
    }
}

private struct AntigravityTerminalTrafficLights: View {
    @Environment(\.designTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            light(color: theme.terminalClose)
            light(color: theme.terminalMinimize)
            light(color: theme.terminalZoom)
        }
    }

    private func light(color: SwiftUI.Color) -> some View {
        Image(systemName: "circle.fill")
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(color)
    }
}

@MainActor
@Observable
private final class AntigravityTerminalController {
    @ObservationIgnored weak var terminalView: LocalProcessTerminalView?

    func attach(_ terminalView: LocalProcessTerminalView) {
        self.terminalView = terminalView
    }

    func cancel() {
        terminalView?.process.send(data: [0x03][...])
        let process = terminalView?.process
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            if process?.running == true { process?.terminate() }
        }
    }

    func paste() {
        guard let terminalView else { return }
        terminalView.window?.makeFirstResponder(terminalView)
        terminalView.paste(self)
    }
}

private struct AntigravityTerminalView: NSViewRepresentable {
    let sessionID: UUID
    let executableURL: URL
    let controller: AntigravityTerminalController
    let onExit: (Int32?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onExit: onExit)
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let options = TerminalOptions(
            cols: 80,
            rows: 18,
            termName: "xterm-256color",
            screenReaderMode: true,
            scrollback: 400,
            enableSixelReported: false,
            kittyImageCacheLimitBytes: 0
        )
        let view = LocalProcessTerminalView(
            frame: .zero,
            font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            options: options
        )
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.group)
        view.setAccessibilityLabel("agy authentication terminal")
        view.setAccessibilityIdentifier("settings.antigravity.authTerminal")
        view.processDelegate = context.coordinator
        applyAppearance(to: view, theme: context.environment.designTheme)
        view.allowMouseReporting = false
        view.startProcess(
            executable: executableURL.path,
            args: [],
            environment: authenticationEnvironment,
            execName: "agy",
            currentDirectory: authenticationCurrentDirectory
        )
        controller.attach(view)
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(
        _ nsView: LocalProcessTerminalView,
        context: Context
    ) {
        applyAppearance(to: nsView, theme: context.environment.designTheme)
    }

    static func dismantleNSView(
        _ nsView: LocalProcessTerminalView,
        coordinator: Coordinator
    ) {
        if nsView.process.running { nsView.terminate() }
    }

    private var authenticationEnvironment: [String] {
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["LANG"] = "en_US.UTF-8"
        environment["LC_ALL"] = "en_US.UTF-8"
        environment["AGY_CLI_DISABLE_AUTO_UPDATE"] = "true"
        let parent = executableURL.deletingLastPathComponent().path
        let currentPath = environment["PATH"]
            ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "\(parent):\(currentPath)"
        return environment.map { "\($0.key)=\($0.value)" }
    }

    private var authenticationCurrentDirectory: String {
        let environment = ProcessInfo.processInfo.environment
        if environment["DockMagicUITesting"] == "1",
           let override = environment[
               "DockMagicUITestAntigravityAuthWorkingDirectoryPath"
           ],
           !override.isEmpty {
            return override
        }
        return FileManager.default.temporaryDirectory.path
    }

    private func applyAppearance(
        to view: LocalProcessTerminalView,
        theme: DesignTheme
    ) {
        view.nativeBackgroundColor = NSColor(theme.terminalBackground)
        view.nativeForegroundColor = NSColor(theme.terminalForeground)
        view.caretColor = NSColor(theme.terminalForeground)
        view.selectedTextBackgroundColor = NSColor(theme.selectionFill)
        view.selectedTextForegroundColor = NSColor(theme.terminalForeground)
        view.needsDisplay = true
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let onExit: (Int32?) -> Void

        init(onExit: @escaping (Int32?) -> Void) {
            self.onExit = onExit
        }

        func sizeChanged(
            source: LocalProcessTerminalView,
            newCols: Int,
            newRows: Int
        ) {}

        func setTerminalTitle(
            source: LocalProcessTerminalView,
            title: String
        ) {}

        func hostCurrentDirectoryUpdate(
            source: TerminalView,
            directory: String?
        ) {}

        func processTerminated(
            source: TerminalView,
            exitCode: Int32?
        ) {
            onExit(exitCode)
        }
    }
}
