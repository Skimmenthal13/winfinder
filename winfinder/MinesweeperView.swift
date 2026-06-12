import SwiftUI
import AppKit

// MARK: - Window controller

final class MinesweeperWindowController: NSWindowController {
    private let gameModel = MinesweeperModel()
    private static var retained: MinesweeperWindowController?

    static func openOrFocus() {
        if let existing = NSApp.windows.first(where: { $0.identifier?.rawValue == "minesweeper" }) {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let controller = MinesweeperWindowController()
        retained = controller
        controller.showWindow(nil)
    }

    init() {
        let win = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.identifier = NSUserInterfaceItemIdentifier("minesweeper")
        win.title = "Minesweeper"
        win.isReleasedWhenClosed = false

        let view = MinesweeperView(model: gameModel)
        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        win.contentView = hosting

        super.init(window: win)

        // Size window after hosting view has a layout pass
        DispatchQueue.main.async { [weak self] in
            self?.window?.center()
        }

        win.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }
}

extension MinesweeperWindowController: NSWindowDelegate {}

// MARK: - Root view

struct MinesweeperView: View {
    @Bindable var model: MinesweeperModel

    var body: some View {
        VStack(spacing: 0) {
            difficultyBar
            mainPanel
        }
        .background(Color(hex: "#C0C0C0"))
        .fixedSize()
    }

    // MARK: - Difficulty bar

    private var difficultyBar: some View {
        HStack(spacing: 0) {
            ForEach(MinesweeperDifficulty.allCases, id: \.self) { d in
                Button(d.rawValue) {
                    model.newGame(difficulty: d)
                }
                .buttonStyle(Win95MenuButtonStyle(
                    isSelected: model.difficulty == d
                ))
            }
            Spacer()
        }
        .padding(.horizontal, 2)
        .frame(height: 24)
        .background(Color(hex: "#C0C0C0"))
        .overlay(alignment: .bottom) {
            Divider().background(Color(hex: "#808080"))
        }
    }

    // MARK: - Main panel (header + grid)

    private var mainPanel: some View {
        VStack(spacing: 6) {
            headerPanel
            gridPanel
        }
        .padding(6)
        .background(
            Win95BevelView(outset: true)
        )
        .padding(6)
    }

    // MARK: - Header

    private var headerPanel: some View {
        HStack {
            LCDCounterView(value: max(-99, min(999, model.mineCounter)))
            Spacer()
            faceButton
            Spacer()
            LCDCounterView(value: min(999, model.elapsedSeconds))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Win95BevelView(outset: false))
        .frame(height: 40)
    }

    private var faceButton: some View {
        Button {
            model.newGame()
        } label: {
            Text(faceEmoji)
                .font(.system(size: 18))
        }
        .buttonStyle(Win95CellButtonStyle(isRevealed: false))
        .frame(width: 28, height: 28)
    }

    private var faceEmoji: String {
        switch model.gameState {
        case .won:  return "😎"
        case .lost: return "😵"
        default:    return model.pressingDown ? "😮" : "🙂"
        }
    }

    // MARK: - Grid

    private var gridPanel: some View {
        VStack(spacing: 0) {
            ForEach(0..<model.rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<model.cols, id: \.self) { col in
                        CellView(
                            cell: model.cells[row][col],
                            onReveal:      { model.reveal(col: col, row: row) },
                            onFlag:        { model.toggleFlag(col: col, row: row) },
                            onChord:       { model.chordReveal(col: col, row: row) },
                            onPressChange: { model.setPressingDown($0) }
                        )
                    }
                }
            }
        }
        .padding(2)
        .background(Win95BevelView(outset: false))
    }
}

// MARK: - Cell view

private struct CellView: View {
    let cell: MinesweeperCell
    let onReveal: () -> Void
    let onFlag: () -> Void
    let onChord: () -> Void
    let onPressChange: (Bool) -> Void

    private let size: CGFloat = 28

    var body: some View {
        ZStack {
            cellBackground
            cellContent
        }
        .frame(width: size, height: size)
        .overlay(
            ClickableCellView(
                onPressStart: {
                    if cell.state == .covered { onPressChange(true) }
                },
                onPressEnd: {
                    onPressChange(false)
                },
                onLeftClick: {
                    if cell.state == .covered { onReveal() }
                    else if cell.state == .revealed { onChord() }
                },
                onRightClick: {
                    onFlag()
                }
            )
        )
    }

    @ViewBuilder
    private var cellBackground: some View {
        switch cell.state {
        case .covered:
            Win95BevelView(outset: true)
        case .exploded:
            Rectangle().fill(Color.red)
        default:
            Rectangle()
                .fill(Color(hex: "#BDBDBD"))
                .overlay(
                    Rectangle()
                        .strokeBorder(Color(hex: "#808080"), lineWidth: 0.5)
                )
        }
    }

    @ViewBuilder
    private var cellContent: some View {
        switch cell.state {
        case .covered:
            EmptyView()
        case .flagged:
            Text("🚩").font(.system(size: 14))
        case .revealed:
            if cell.isMine {
                Text("💣").font(.system(size: 14))
            } else if cell.adjacentMines > 0 {
                Text("\(cell.adjacentMines)")
                    .font(.system(size: 14, weight: .heavy, design: .default))
                    .foregroundColor(numberColor(cell.adjacentMines))
            }
        case .exploded:
            Text("💣").font(.system(size: 14))
        }
    }

    private func numberColor(_ n: Int) -> Color {
        switch n {
        case 1: return Color(hex: "#0000FF")
        case 2: return Color(hex: "#007B00")
        case 3: return Color(hex: "#FF0000")
        case 4: return Color(hex: "#00007B")
        case 5: return Color(hex: "#7B0000")
        case 6: return Color(hex: "#007B7B")
        case 7: return Color(hex: "#000000")
        default: return Color(hex: "#7B7B7B")
        }
    }
}

// MARK: - LCD counter

private struct LCDCounterView: View {
    let value: Int

    private var display: String {
        let clamped = max(-99, min(999, value))
        return clamped < 0
            ? String(format: "-%02d", abs(clamped))
            : String(format: "%03d", clamped)
    }

    var body: some View {
        Text(display)
            .font(.custom("Menlo", size: 22).bold())
            .foregroundColor(.red)
            .tracking(2)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.black)
            .frame(width: 52, height: 30)
            .clipped()
    }
}

// MARK: - Win95 bevel (3-D border)

private struct Win95BevelView: View {
    let outset: Bool

    var body: some View {
        let light = Color(hex: outset ? "#FFFFFF" : "#808080")
        let dark  = Color(hex: outset ? "#808080" : "#FFFFFF")
        let bg    = Color(hex: "#C0C0C0")

        ZStack {
            bg
            // Top edge
            VStack(spacing: 0) {
                Rectangle().fill(light).frame(height: 2)
                Spacer()
            }
            // Left edge
            HStack(spacing: 0) {
                Rectangle().fill(light).frame(width: 2)
                Spacer()
            }
            // Bottom edge
            VStack(spacing: 0) {
                Spacer()
                Rectangle().fill(dark).frame(height: 2)
            }
            // Right edge
            HStack(spacing: 0) {
                Spacer()
                Rectangle().fill(dark).frame(width: 2)
            }
        }
    }
}

// MARK: - Button styles

private struct Win95MenuButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .padding(.horizontal, 8)
            .frame(height: 22)
            .foregroundColor(.primary)
            .background(
                isSelected || configuration.isPressed
                    ? Color(hex: "#808080").opacity(0.3)
                    : Color.clear
            )
    }
}

private struct Win95CellButtonStyle: ButtonStyle {
    let isRevealed: Bool

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            if configuration.isPressed || isRevealed {
                Color(hex: "#BDBDBD")
            } else {
                Win95BevelView(outset: true)
            }
            configuration.label
        }
    }
}

// MARK: - Clickable cell (NSViewRepresentable for reliable left + right mouse handling)

private final class ClickableCellNSView: NSView {
    var onPressStart: () -> Void = {}
    var onPressEnd:   () -> Void = {}
    var onLeftClick:  () -> Void = {}
    var onRightClick: () -> Void = {}

    override func mouseDown(with event: NSEvent) {
        onPressStart()
        // Don't call super — prevents event from bubbling to SwiftUI gesture recognizers
    }

    override func mouseUp(with event: NSEvent) {
        onPressEnd()
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) {
            onLeftClick()
        }
        // Don't call super
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick()
        // Don't call super — prevents the system context menu
    }
}

private struct ClickableCellView: NSViewRepresentable {
    let onPressStart: () -> Void
    let onPressEnd:   () -> Void
    let onLeftClick:  () -> Void
    let onRightClick: () -> Void

    func makeNSView(context: Context) -> ClickableCellNSView {
        let v = ClickableCellNSView()
        v.onPressStart = onPressStart
        v.onPressEnd   = onPressEnd
        v.onLeftClick  = onLeftClick
        v.onRightClick = onRightClick
        return v
    }

    func updateNSView(_ nsView: ClickableCellNSView, context: Context) {
        nsView.onPressStart = onPressStart
        nsView.onPressEnd   = onPressEnd
        nsView.onLeftClick  = onLeftClick
        nsView.onRightClick = onRightClick
    }
}

// MARK: - Color hex init

extension Color {
    fileprivate init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double((int >>  0) & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
