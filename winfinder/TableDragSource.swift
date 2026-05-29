import SwiftUI
import AppKit

// MARK: - SwiftUI wrapper

struct KeyDeleteMonitor: NSViewRepresentable {
    let model: FileExplorerModel

    func makeNSView(context: Context) -> KeyDeleteNSView {
        let v = KeyDeleteNSView()
        v.model = model
        return v
    }

    func updateNSView(_ nsView: KeyDeleteNSView, context: Context) {
        nsView.model = model
    }
}

// MARK: - AppKit window-level Delete key monitor

final class KeyDeleteNSView: NSView {
    weak var model: FileExplorerModel?
    private var monitor: Any?

    // Never participate in hit-testing so clicks fall through to file list rows.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    // MARK: Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil, let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    // MARK: Event handling

    private func handle(_ event: NSEvent) -> NSEvent? {
        // keyCode 51 = Delete (⌫). Forward Delete (⌦) is 117 — not handled here.
        guard event.keyCode == 51 else { return event }

        // If any text input has focus, let it handle the delete itself.
        // NSText is the common superclass of NSTextField's field editor (NSTextView)
        // and NSTextView directly, so one check covers both.
        if NSApp.keyWindow?.firstResponder is NSText { return event }

        guard let model else { return event }
        let selected = model.displayed.filter { model.selection.contains($0.url) }
        guard !selected.isEmpty else { return event }

        if event.modifierFlags.contains(.shift) {
            // Permanent delete — show confirmation on the next run-loop tick so the
            // key event finishes dispatching before the modal takes over the run loop.
            DispatchQueue.main.async { self.confirmAndDeletePermanently(selected, model: model) }
        } else {
            model.delete(selected)
        }
        return nil  // consume: prevent further dispatch
    }

    // MARK: Permanent-delete confirmation

    private func confirmAndDeletePermanently(_ items: [FileItem], model: FileExplorerModel) {
        let alert = NSAlert()
        let label = items.count == 1
            ? "\"\(items[0].name)\""
            : "\(items.count) elementi"
        alert.messageText = "Eliminare definitivamente \(label)?"
        alert.informativeText = "Questa operazione non può essere annullata."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Elimina")
        alert.addButton(withTitle: "Annulla")
        if alert.runModal() == .alertFirstButtonReturn {
            model.deletePermanently(items)
        }
    }
}
