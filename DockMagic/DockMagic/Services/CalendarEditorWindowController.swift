import AppKit
import SwiftUI

/// A normal key window keeps typing/confirmation independent of the transient
/// Dock hover panel and of the Settings preview sheet.
@MainActor
final class CalendarEditorWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private weak var store: CalendarStore?
    private var isDirty = false

    func show(store: CalendarStore, kind: CalendarEditKind, event: CalendarEvent?, reminder: CalendarReminder?) {
        if let window {
            if window.isMiniaturized { window.deminiaturize(nil) }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        self.store = store; isDirty = false
        store.clearMutationError()
        store.setInterest(.editor, active: true)
        let isNew = event == nil && reminder == nil
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 520, height: 610),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "\(isNew ? "New" : "Edit") \(kind.title)"
        window.identifier = NSUserInterfaceItemIdentifier("calendar.editor")
        window.isReleasedWhenClosed = false
        window.delegate = self
        let editor = CalendarItemEditorView(store: store, kind: kind, event: event, reminder: reminder,
            onDirty: { [weak self] in self?.isDirty = $0 },
            onCancel: { [weak self] in self?.requestClose() },
            onSaved: { [weak self] in self?.window?.close() })
        let mode = DSAppearanceMode(rawValue: DockMagicRuntimeDefaults.current.string(forKey: DSAppearanceMode.storageKey) ?? "") ?? .system
        window.contentView = NSHostingView(rootView: DockMagicThemeRoot(content: editor, appearanceMode: mode))
        self.window = window
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        requestClose()
        return false
    }

    private func requestClose() {
        guard let window, store?.isSaving != true, window.attachedSheet == nil else { return }
        guard isDirty else { window.close(); return }
        let alert = NSAlert()
        alert.messageText = "Discard unsaved changes?"
        alert.informativeText = "Your changes have not been saved to Calendar or Reminders."
        alert.addButton(withTitle: "Keep Editing")
        alert.addButton(withTitle: "Discard Changes")
        alert.beginSheetModal(for: window) { response in
            if response == .alertSecondButtonReturn { window.close() }
        }
    }

    func windowWillClose(_ notification: Notification) {
        window?.contentView = nil
        window = nil; isDirty = false
        store?.setInterest(.editor, active: false)
        store?.clearMutationError()
        store = nil
    }
}
