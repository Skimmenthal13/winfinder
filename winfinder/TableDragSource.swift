import SwiftUI
import AppKit

// MARK: - SwiftUI wrapper

/// Transparent, non-hit-testable view that installs an NSEvent monitor on the
/// window and starts a native AppKit drag session when the user drags selected
/// rows out of the file table.
///
/// Holding a direct reference to FileExplorerModel (an @Observable reference
/// type) means the event handler always reads the *current* selection — no
/// SwiftUI closure-capture race condition between mouseDown and mouseDragged.
struct TableDragSource: NSViewRepresentable {
    let model: FileExplorerModel

    func makeNSView(context: Context) -> DragSourceNSView {
        let v = DragSourceNSView()
        v.model = model
        return v
    }

    func updateNSView(_ nsView: DragSourceNSView, context: Context) {
        nsView.model = model   // keep reference current across view rebuilds
    }
}

// MARK: - AppKit implementation

final class DragSourceNSView: NSView, NSDraggingSource {
    weak var model: FileExplorerModel?

    private var monitor: Any?
    private var downPoint: NSPoint?
    private var dragActive = false

    // MARK: Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handle(event)
            return event   // never consume — only observe
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

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            downPoint  = event.locationInWindow
            dragActive = false

        case .leftMouseDragged:
            guard !dragActive, let downPt = downPoint else { return }
            let cur = event.locationInWindow
            guard hypot(cur.x - downPt.x, cur.y - downPt.y) > 4 else { return }
            // Read selection from the model reference — always current, no race.
            let urls = selectedURLs()
            guard !urls.isEmpty else { return }
            dragActive = true
            downPoint  = nil
            startDrag(urls: urls, event: event)

        case .leftMouseUp:
            downPoint  = nil
            dragActive = false

        default:
            break
        }
    }

    // MARK: Helpers

    private func selectedURLs() -> [URL] {
        guard let model else { return [] }
        return model.displayed
            .filter { model.selection.contains($0.id) }
            .map(\.url)
    }

    // MARK: Drag session

    private func startDrag(urls: [URL], event: NSEvent) {
        let mouseInSelf = convert(event.locationInWindow, from: nil)

        let draggingItems: [NSDraggingItem] = urls.enumerated().map { idx, url in
            let item   = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon   = NSWorkspace.shared.icon(forFile: url.path)
            let offset = CGFloat(idx) * 2
            item.setDraggingFrame(
                NSRect(x: mouseInSelf.x - 16 + offset,
                       y: mouseInSelf.y - 16 + offset,
                       width: 32, height: 32),
                contents: icon
            )
            return item
        }

        beginDraggingSession(with: draggingItems, event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        switch context {
        case .outsideApplication: return .copy
        case .withinApplication:  return NSEvent.modifierFlags.contains(.command) ? .copy : .move
        @unknown default:          return .copy
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        DispatchQueue.main.async { [weak self] in self?.model?.reload() }
    }
}
