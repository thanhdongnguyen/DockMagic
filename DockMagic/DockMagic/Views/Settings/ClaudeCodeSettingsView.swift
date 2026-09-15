import AppKit
import Observation
import SwiftTerm
import SwiftUI

@MainActor
struct ClaudeCodeConnectionSettingsView: View {
    let store: ClaudeCodeUsageStore
    let installationState: DeveloperToolInstallationState
    let installCLI: () -> Void

    @State private var loginSessionID: UUID?
    @State private var showsTerminal = false
    @State private var terminalController = ClaudeCodeLoginTerminalController()
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

            if let loginSessionID, let executableURL = store.executableURL {
                loginTerminal(
                    sessionID: loginSessionID,
                    executableURL: executableURL
                )
                .frame(height: showsTerminal ? 380 : 0)
                .clipped()
                .allowsHitTesting(showsTerminal)
                .accessibilityHidden(!showsTerminal)
            }

            if let warning = store.bridgeCleanupWarning {
                DSStatusCard(
                    title: "Status line cleanup needs attention",
                    detail: warning,
                    systemImage: "exclamationmark.triangle.fill",
                    role: .warning
                )
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
            if case .signedOut = store.connectionState {
                Spacer(minLength: 0)
                actions
            } else {
                Text("Claude Code connection")
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer(minLength: DSSpacing.section)

                connectionSummary
                actions
            }
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
        .accessibilityIdentifier("settings.claudeCode.connectionStatus")
    }

    @ViewBuilder
    private var actions: some View {
        switch store.connectionState {
        case .cliMissing:
            Button("Install Claude CLI", action: installCLI)
                .buttonStyle(DSButtonStyle(kind: .primary))
                .disabled(installationState == .installing)
                .accessibilityIdentifier("settings.claudeCode.install")
        case .cliOutdated:
            Link(
                "Update Claude CLI",
                destination: URL(string: "https://code.claude.com/docs/en/setup")!
            )
            .buttonStyle(DSButtonStyle(kind: .primary))
            .accessibilityIdentifier("settings.claudeCode.updateCLI")
        case .signedOut:
            Button("Sign in with Claude", action: startSignIn)
                .buttonStyle(DSButtonStyle(kind: .primary))
                .focused($focusedAction, equals: .signIn)
                .accessibilityIdentifier("settings.claudeCode.signIn")
        case .signingIn, .signingOut:
            EmptyView()
        case .connected:
            HStack(spacing: DSSpacing.small) {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(DSIconButtonStyle(visualSize: 28, hitSize: 36))
                .disabled(store.isRefreshing)
                .focused($focusedAction, equals: .refresh)
                .help("Refresh Claude quota")
                .accessibilityLabel("Refresh Claude quota")
                .accessibilityIdentifier("settings.claudeCode.refresh")

                moreActions
            }
        case .quotaUnavailable:
            HStack(spacing: DSSpacing.small) {
                Button("Sign in with Claude plan", action: startSignIn)
                    .buttonStyle(DSButtonStyle(kind: .primary))
                    .accessibilityIdentifier("settings.claudeCode.signInPlan")
                Button("Retry") { Task { await store.refresh() } }
                    .buttonStyle(DSButtonStyle())
                    .accessibilityIdentifier("settings.claudeCode.retry")
                moreActions
            }
        case .stale:
            HStack(spacing: DSSpacing.small) {
                Button("Retry") { Task { await store.refresh() } }
                    .buttonStyle(DSButtonStyle(kind: .primary))
                    .disabled(store.isRefreshing)
                    .accessibilityIdentifier("settings.claudeCode.retry")
                moreActions
            }
        case .failed:
            Button("Retry") { Task { await store.refresh() } }
                .buttonStyle(DSButtonStyle(kind: .primary))
                .disabled(store.isRefreshing)
                .accessibilityIdentifier("settings.claudeCode.retry")
        case .checking, .signedInWaitingForQuota:
            EmptyView()
        }
    }

    private var moreActions: some View {
        Menu {
            if loginSessionID != nil {
                Button(showsTerminal ? "Hide sign-in log" : "Show sign-in log") {
                    showsTerminal.toggle()
                }
                .accessibilityIdentifier("settings.claudeCode.showLoginLog")

                Divider()
            }

            Button(role: .destructive) {
                Task {
                    await store.signOut()
                    if case .signedOut = store.connectionState {
                        focusedAction = .signIn
                    }
                }
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .accessibilityIdentifier("settings.claudeCode.signOut")
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
        .help("More Claude connection actions")
        .accessibilityLabel("More Claude connection actions")
        .accessibilityIdentifier("settings.claudeCode.moreActions")
    }

    private func loginTerminal(
        sessionID: UUID,
        executableURL: URL
    ) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.standard) {
            VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                Text("Complete sign-in in your browser")
                    .font(DSTypography.bodyEmphasis)
                    .foregroundStyle(theme.textPrimary)
                Text("Keep this window open. The terminal runs only `claude auth login --claudeai` and closes after authentication.")
                    .font(DSTypography.metadata)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ClaudeCodeLoginTerminalSurface(
                sessionID: sessionID,
                executableURL: executableURL,
                controller: terminalController
            ) { _ in
                Task { @MainActor in
                    await store.loginProcessDidFinish()
                    if case .connected = store.connectionState {
                        showsTerminal = false
                        focusedAction = .refresh
                    } else if case .signedOut = store.connectionState {
                        focusedAction = .signIn
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 268)

            HStack(spacing: DSSpacing.small) {
                Button("Cancel") {
                    terminalController.cancel()
                    showsTerminal = false
                    Task {
                        await store.cancelSignIn()
                        focusedAction = .signIn
                    }
                }
                .buttonStyle(DSButtonStyle())
                .accessibilityIdentifier("settings.claudeCode.cancelSignIn")

                Button("Open in Terminal") {
                    ClaudeCodeLoginFallback.open(executableURL: executableURL)
                }
                .buttonStyle(DSButtonStyle())
                .accessibilityIdentifier("settings.claudeCode.openInTerminal")
            }
        }
    }

    private func startSignIn() {
        guard store.executableURL != nil else {
            installCLI()
            return
        }
        terminalController = ClaudeCodeLoginTerminalController()
        loginSessionID = UUID()
        showsTerminal = true
        store.beginSignIn()
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
                "Claude CLI required"
            )
        case let .cliOutdated(installed, required):
            return (
                "Update required",
                "Installed \(installed). DockMagic requires \(required) or later for accessible /usage output.",
                nil, "exclamationmark.triangle.fill", .warning,
                "Claude CLI update required"
            )
        case .checking:
            return (
                "Checking", nil, nil, nil, .processing,
                "Checking Claude connection"
            )
        case .signedOut:
            return (
                "Not signed in", nil, nil,
                "person.crop.circle.badge.xmark", .warning,
                "Not signed in to Claude"
            )
        case .signingIn:
            return (
                "Signing in", nil, nil, nil, .processing,
                "Signing in to Claude"
            )
        case .signingOut:
            return (
                "Signing out", nil, nil, nil, .processing,
                "Signing out of Claude"
            )
        case let .signedInWaitingForQuota(info):
            return (
                "Loading quota", nil, nil, nil, .processing,
                "Signed in with \(info.displayName), loading Claude quota"
            )
        case .connected:
            return (
                "Connected", nil, nil,
                "checkmark.circle.fill", .information,
                "Connected to Claude"
            )
        case let .quotaUnavailable(_, reason):
            return (
                "Quota unavailable", reason, nil,
                "exclamationmark.triangle.fill", .warning,
                "Claude quota unavailable"
            )
        case let .stale(snapshot, message):
            return (
                "Last known quota", message,
                "Updated \(relative(snapshot.fetchedAt))",
                "clock.badge.exclamationmark", .warning,
                "Last known Claude quota, updated \(relative(snapshot.fetchedAt))"
            )
        case let .failed(message):
            return (
                "Connection failed", message, nil,
                "xmark.octagon.fill", .danger,
                "Claude connection failed"
            )
        }
    }

    private var isProcessing: Bool {
        switch store.connectionState {
        case .checking, .signingIn, .signingOut, .signedInWaitingForQuota:
            true
        default:
            false
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
            "settings.claudeCode.lastUpdated"
        default:
            "settings.claudeCode.connectionDetail"
        }
    }
}

private struct ClaudeCodeLoginTerminalSurface: View {
    let sessionID: UUID
    let executableURL: URL
    let controller: ClaudeCodeLoginTerminalController
    let onExit: (Int32?) -> Void

    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            terminalTitleBar

            Rectangle()
                .fill(theme.terminalOutline)
                .frame(height: 1)
                .accessibilityHidden(true)

            ClaudeCodeLoginTerminalView(
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
            Text("Claude sign-in")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.terminalSecondary)
                .lineLimit(1)
                .accessibilityIdentifier("settings.claudeCode.terminal.title")

            HStack(spacing: 0) {
                ClaudeCodeTerminalTrafficLights()
                    .frame(width: 58, height: 18)
                    .accessibilityHidden(true)

                Spacer(minLength: DSSpacing.standard)

                Text("Claude CLI")
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
                    .accessibilityLabel("Claude CLI login session")
                    .accessibilityIdentifier(
                        "settings.claudeCode.terminal.profile"
                    )
            }
        }
        .padding(.horizontal, DSSpacing.standard)
        .frame(height: 48)
        .background(theme.terminalChrome)
    }
}

private struct ClaudeCodeTerminalTrafficLights: View {
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
final class ClaudeCodeLoginTerminalController {
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
}

private struct ClaudeCodeLoginTerminalView: NSViewRepresentable {
    let sessionID: UUID
    let executableURL: URL
    let controller: ClaudeCodeLoginTerminalController
    let onExit: (Int32?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onExit: onExit)
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let options = TerminalOptions(
            cols: 108,
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
        view.setAccessibilityLabel("Claude CLI login terminal")
        view.setAccessibilityIdentifier("settings.claudeCode.loginTerminal")
        view.processDelegate = context.coordinator
        applyAppearance(
            to: view,
            theme: context.environment.designTheme
        )
        view.allowMouseReporting = false
        view.startProcess(
            executable: executableURL.path,
            args: ["auth", "login", "--claudeai"],
            environment: loginEnvironment,
            execName: "claude",
            currentDirectory: loginCurrentDirectory
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
        applyAppearance(
            to: nsView,
            theme: context.environment.designTheme
        )
    }

    static func dismantleNSView(
        _ nsView: LocalProcessTerminalView,
        coordinator: Coordinator
    ) {
        if nsView.process.running { nsView.terminate() }
    }

    private var loginEnvironment: [String] {
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["LANG"] = "en_US.UTF-8"
        environment["LC_ALL"] = "en_US.UTF-8"
        return environment.map { "\($0.key)=\($0.value)" }
    }

    private var loginCurrentDirectory: String {
        let environment = ProcessInfo.processInfo.environment
        if environment["DockMagicUITesting"] == "1",
           let override = environment[
               "DockMagicUITestClaudeLoginWorkingDirectoryPath"
           ],
           !override.isEmpty
        {
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

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {
            onExit(exitCode)
        }
    }
}

private enum ClaudeCodeLoginFallback {
    static func open(executableURL: URL) {
        let commandURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "DockMagic-Claude-Login-\(UUID().uuidString).command"
            )
        let quotedPath = "'" + executableURL.path
            .replacingOccurrences(of: "'", with: "'\\''") + "'"
        let contents = "#!/bin/zsh\nexec \(quotedPath) auth login --claudeai\n"
        do {
            try Data(contents.utf8).write(to: commandURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: commandURL.path
            )
            NSWorkspace.shared.open(commandURL)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(60))
                try? FileManager.default.removeItem(at: commandURL)
            }
        } catch {
            NSSound.beep()
        }
    }
}
