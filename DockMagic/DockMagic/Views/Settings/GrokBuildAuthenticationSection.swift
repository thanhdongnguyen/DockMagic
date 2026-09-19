import AppKit
import SwiftUI
import SwiftTerm

@MainActor
struct GrokBuildAuthenticationSection: View {
    let store: GrokBuildUsageStore
    @State private var confirmsSignOut = false
    @State private var signOutConfiguration: GrokBuildCLIConfiguration?
    @Environment(\.designTheme) private var theme

    private var busy: Bool {
        store.authentication.isRunning || store.connection == .signingIn
            || store.connection == .signingOut || store.connection == .checking
    }
    private var canAuthenticate: Bool {
        store.isEnabled && store.configuration != nil
            && store.authentication.supports(version: store.cliVersion) && !busy
    }

    var body: some View {
        DSSettingsSection(title: "Grok account", detail: "Local token history does not require sign-in. Grok CLI owns authentication; DockMagic never reads or copies credentials.") {
            VStack(alignment: .leading, spacing: DSSpacing.standard) {
                Text(status).font(DSTypography.bodyEmphasis)
                    .accessibilityIdentifier("settings.grokBuild.connection")
                if busy {
                    ProgressView(store.authentication.isCancelling ? "Cancelling sign-in…" : "Waiting for Grok…")
                        .controlSize(.small)
                        .accessibilityIdentifier("settings.grokBuild.authProgress")
                }
                Text(GrokBuildDashboardManifest.quotaNote)
                    .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !store.authentication.supports(version: store.cliVersion) {
                    Text("Authentication commands have been checked with CLI 1.0.30 only. Choose that version and refresh; other versions remain disabled pending verification.")
                        .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                }
                HStack {
                    Button("Sign in with Grok") { store.authentication.start(store: store, deviceCode: false) }
                        .disabled(!canAuthenticate).accessibilityIdentifier("settings.grokBuild.signIn")
                    Button("Device code") { store.authentication.start(store: store, deviceCode: true) }
                        .disabled(!canAuthenticate).accessibilityIdentifier("settings.grokBuild.deviceCode")
                    Button("Sign out") {
                        signOutConfiguration = store.configuration
                        confirmsSignOut = true
                    }.disabled(!canAuthenticate).accessibilityIdentifier("settings.grokBuild.signOut")
                    if store.authentication.isRunning || store.connection == .signingOut {
                        Button("Cancel") { store.cancelAuthentication() }
                            .accessibilityIdentifier("settings.grokBuild.cancelAuth")
                    }
                }.buttonStyle(DSButtonStyle())
                Button("Check quota") { Task { await store.refreshQuota(force: true) } }
                    .buttonStyle(DSButtonStyle())
                    .disabled(!store.isEnabled || store.configuration == nil || busy)
                    .accessibilityIdentifier("settings.grokBuild.checkQuota")
                if store.authentication.isRunning, !store.authentication.isCancelling, store.connection == .signingIn {
                    Text(store.authentication.usesDeviceCode
                         ? "Complete the device-code instructions below. The code is temporary and is cleared when this attempt ends."
                         : "Complete sign-in in the browser opened by Grok. Closing Settings or leaving this page cancels the attempt.")
                        .font(DSTypography.metadata).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    GrokBuildLoginOutputView(output: store.authentication.output)
                        .frame(height: 220)
                        .background(theme.terminalBackground)
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.control))
                        .overlay(RoundedRectangle(cornerRadius: DSRadius.control).strokeBorder(theme.terminalOutline, lineWidth: 1))
                }
            }
        }
        .dsAlert("Sign out of Grok?", isPresented: $confirmsSignOut) {
            DSDialogButton("Sign out", role: .destructive) {
                let confirmed = signOutConfiguration
                Task {
                    guard store.configuration == confirmed else { return }
                    await store.signOut()
                }
            }.accessibilityIdentifier("settings.grokBuild.confirmSignOut")
            DSDialogButton("Cancel", role: .cancel) {}
        } message: {
            Text("This runs grok logout for the configured Grok home. Local token history and earned badges are kept. Account verification may remain unavailable while the billing safety gate is closed.")
        }
        .onDisappear { store.cancelAuthentication() }
    }

    private var status: String {
        switch store.connection {
        case .notConfigured: return "Account: not checked"
        case .checking: return "Checking account quota…"
        case .signedOut: return "Signed out · local history remains available"
        case .connected: return "Account quota connected"
        case .unsupportedAuthentication: return "Account quota requires a supported Grok sign-in"
        case .signingIn: return "Signing in with Grok…"
        case .signingOut: return "Signing out with Grok…"
        case let .failed(error):
            if error == .signOutUnverified { return error.localizedDescription }
            if store.signInCommandCompleted { return "Sign-in command completed · quota not verified. \(error.localizedDescription)" }
            return "Account not verified. \(error.localizedDescription)"
        }
    }
}

/// Reuses SwiftTerm and the app's terminal theme without giving the view a
/// shell, stdin, clipboard escape handler, or authority to open output links.
/// Grok's browser/device flow needs no terminal input. Output is bounded and
/// discarded by the authentication controller, never saved as a terminal log.
private struct GrokBuildLoginOutputView: NSViewRepresentable {
    let output: Data
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> TerminalView {
        let options = TerminalOptions(cols: 100, rows: 14, convertEol: true, termName: "dumb", screenReaderMode: true,
                                      scrollback: 200, enableSixelReported: false, kittyImageCacheLimitBytes: 0)
        let view = TerminalView(frame: .zero, font: .monospacedSystemFont(ofSize: 13, weight: .regular), options: options)
        view.allowMouseReporting = false
        view.setAccessibilityLabel("Grok sign-in output, read only")
        view.setAccessibilityIdentifier("settings.grokBuild.authTerminal")
        return view
    }
    func updateNSView(_ view: TerminalView, context: Context) {
        let theme = context.environment.designTheme
        view.nativeBackgroundColor = NSColor(theme.terminalBackground)
        view.nativeForegroundColor = NSColor(theme.terminalForeground)
        view.caretColor = NSColor(theme.terminalForeground)
        view.selectedTextBackgroundColor = NSColor(theme.selectionFill)
        view.selectedTextForegroundColor = NSColor(theme.terminalForeground)
        view.needsDisplay = true
        // No delegate: terminal requests cannot write clipboard/open links or
        // send a reply. The byte cap includes both stdout and stderr.
        let previous = context.coordinator.bytesFed
        if output.count > previous {
            view.feed(byteArray: Array(output.dropFirst(previous))[...])
            context.coordinator.bytesFed = output.count
        }
    }
    final class Coordinator { var bytesFed = 0 }
}
