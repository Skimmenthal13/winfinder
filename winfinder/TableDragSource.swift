import SwiftUI
import AppKit

// MARK: - SwiftUI wrapper

struct TableDragSource: NSViewRepresentable {
    let model: FileExplorerModel

    func makeNSView(context: Context) -> DragSourceNSView {
        let v = DragSourceNSView()
        v.model = model
        return v
    }

    func updateNSView(_ nsView: DragSourceNSView, context: Context) {
        nsView.model = model
    }
}

// MARK: - AppKit drag source

final class DragSourceNSView: NSView, NSDraggingSource {
    weak var model: FileExplorerModel?

    private var monitor: Any?
    private var mouseDownEvent: NSEvent?   // beginDraggingSession requires the mouseDown event
    private var dragActive = false

    // Never participate in hit-testing: all clicks fall through to the Table.
    // Using the AppKit override (not SwiftUI's allowsHitTesting) guarantees
    // the view stays in the real window hierarchy so viewDidMoveToWindow fires.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    // MARK: Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handle(event)
            return event    // never consume — only observe
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
            mouseDownEvent = event   // save for beginDraggingSession
            dragActive = false

        case .leftMouseDragged:
            guard !dragActive, let downEvent = mouseDownEvent else { return }
            let down = downEvent.locationInWindow
            let cur  = event.locationInWindow
            guard hypot(cur.x - down.x, cur.y - down.y) > 4 else { return }
            let urls = selectedURLs()
            guard !urls.isEmpty else { return }
            dragActive = true
            mouseDownEvent = nil
            startDrag(urls: urls, event: downEvent)   // must pass the mouseDown event

        case .leftMouseUp:
            mouseDownEvent = nil
            dragActive = false

        default:
            break
        }
    }

    // MARK: Selection

    private func selectedURLs() -> [URL] {
        // model.selection is Set<URL>; no id mapping needed — compare URLs directly.
        guard let model, !model.selection.isEmpty else { return [] }
        let visible = Set(model.displayed.map(\.url))
        return model.selection.filter { visible.contains($0) }
    }

    // MARK: Drag session

    private func startDrag(urls: [URL], event: NSEvent) {
        let origin = convert(event.locationInWindow, from: nil)

        let items: [NSDraggingItem] = urls.enumerated().map { idx, url in
            let di     = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon   = NSWorkspace.shared.icon(forFile: url.path)
            let offset = CGFloat(idx) * 2
            di.setDraggingFrame(
                NSRect(x: origin.x - 16 + offset,
                       y: origin.y - 16 + offset,
                       width: 32, height: 32),
                contents: icon
            )
            return di
        }

        beginDraggingSession(with: items, event: event, source: self)
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
        dragActive = false
        mouseDownEvent = nil
        DispatchQueue.main.async { [weak self] in self?.model?.reload() }
    }
}
