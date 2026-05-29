import SwiftUI
import AppKit

// MARK: - SwiftUI wrapper

/// Transparent, non-hit-testable view that installs an NSEvent monitor
/// on the window and starts native AppKit drag sessions when the user
/// drags from within an NSTableView — without touching SwiftUI gestures,
/// so Table row selection is never interrupted.
struct TableDragSource: NSViewRepresentable {
    let getURLs: () -> [URL]
    let reload:  () -> Void

    func makeNSView(context: Context) -> DragSourceNSView {
        let v = DragSourceNSView()
        v.getURLs = getURLs
        v.reload  = reload
        return v
    }

    func updateNSView(_ nsView: DragSourceNSView, context: Context) {
        nsView.getURLs = getURLs
        nsView.reload  = reload
    }
}

// MARK: - AppKit implementation

final class DragSourceNSView: NSView, NSDraggingSource {
    var getURLs: (() -> [URL])?
    var reload:  (() -> Void)?

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
            guard !dragActive, let dp = downPoint else { return }
            let cur = event.locationInWindow
            guard hypot(cur.x - dp.x, cur.y - dp.y) > 4 else { return }
            guard let urls = getURLs?(), !urls.isEmpty else { return }
            guard isOverTable(at: dp) else { return }
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

    // MARK: Drag session

    private func startDrag(urls: [URL], event: NSEvent) {
        let mouseInSelf = convert(event.locationInWindow, from: nil)

        // NSURL conforms to NSPasteboardWriting and is understood by both
        // Finder and our own onDrop handlers via loadObject(ofClass: URL.self)
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
        DispatchQueue.main.async { [weak self] in self?.reload?() }
    }

    // MARK: Helpers

    private func isOverTable(at windowPoint: NSPoint) -> Bool {
        guard let root = window?.contentView else { return false }
        return findTable(in: root, at: windowPoint) != nil
    }

    private func findTable(in view: NSView, at pt: NSPoint) -> NSTableView? {
        if let tv = view as? NSTableView {
            let local = tv.convert(pt, from: nil)
            if tv.bounds.contains(local) { return tv }
        }
        for sub in view.subviews {
            if let found = findTable(in: sub, at: pt) { return found }
        }
        return nil
    }
}
