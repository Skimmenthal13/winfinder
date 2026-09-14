import SwiftUI
import AppKit

// MARK: - Window controller

final class KeyboardShortcutsWindowController: NSWindowController {
    private static var retained: KeyboardShortcutsWindowController?

    static func openOrFocus() {
        if let existing = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "keyboard-shortcuts"
        }) {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = KeyboardShortcutsWindowController()
        retained = controller
        controller.showWindow(nil)
    }

    init() {
        let win = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.identifier = NSUserInterfaceItemIdentifier("keyboard-shortcuts")
        win.title = String(localized: "Keyboard Shortcuts")
        win.isReleasedWhenClosed = false

        let hosting = NSHostingView(rootView: KeyboardShortcutsView())
        hosting.translatesAutoresizingMaskIntoConstraints = false
        win.contentView = hosting

        super.init(window: win)

        win.delegate = self
        DispatchQueue.main.async { [weak win] in win?.center() }
        NSApp.activate(ignoringOtherApps: true)
    }

    required init?(coder: NSCoder) { fatalError() }
}

extension KeyboardShortcutsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        Self.retained = nil
    }
}

// MARK: - Data model

private struct ShortcutEntry {
    let label: String
    let keys: [String]
}

private struct ShortcutSection {
    let title: String
    let entries: [ShortcutEntry]
}

// MARK: - View

struct KeyboardShortcutsView: View {
    private var sections: [ShortcutSection] {[
        ShortcutSection(title: String(localized: "Navigation"), entries: [
            ShortcutEntry(label: String(localized: "Back"),    keys: ["⌥", "←"]),
            ShortcutEntry(label: String(localized: "Forward"), keys: ["⌥", "→"]),
        ]),
        ShortcutSection(title: String(localized: "Files and Folders"), entries: [
            ShortcutEntry(label: String(localized: "New Window"),         keys: ["⌘", "N"]),
            ShortcutEntry(label: String(localized: "New Folder"),         keys: ["⌘", "⇧", "N"]),
            ShortcutEntry(label: String(localized: "New File"),           keys: ["⌘", "⇧", "F"]),
            ShortcutEntry(label: String(localized: "Rename"),             keys: ["F2"]),
            ShortcutEntry(label: String(localized: "Delete"),             keys: ["⌫"]),
            ShortcutEntry(label: String(localized: "Delete Permanently"), keys: ["⇧", "⌫"]),
        ]),
        ShortcutSection(title: String(localized: "General"), entries: [
            ShortcutEntry(label: String(localized: "Copy"),               keys: ["⌘", "C"]),
            ShortcutEntry(label: String(localized: "Cut"),                keys: ["⌘", "X"]),
            ShortcutEntry(label: String(localized: "Paste"),              keys: ["⌘", "V"]),
            ShortcutEntry(label: String(localized: "Settings"),           keys: ["⌘", ","]),
            ShortcutEntry(label: String(localized: "Manage Extensions…"), keys: ["⌘", "⇧", "E"]),
        ]),
    ]}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()
            sectionsView
        }
        .frame(width: 360)
        .fixedSize()
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "Keyboard Shortcuts"))
                .font(.title3)
                .fontWeight(.semibold)
            Text("Win Finder")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var sectionsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.offset) { idx, section in
                sectionView(section)
                if idx < sections.count - 1 {
                    Divider()
                        .padding(.vertical, 6)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func sectionView(_ section: ShortcutSection) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(section.title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.bottom, 5)
            ForEach(Array(section.entries.enumerated()), id: \.offset) { _, entry in
                HStack {
                    Text(entry.label)
                        .font(.body)
                    Spacer(minLength: 16)
                    HStack(spacing: 3) {
                        ForEach(entry.keys, id: \.self) { key in
                            KeyCapView(text: key)
                        }
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }
}

// MARK: - Keycap

private struct KeyCapView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color(NSColor.shadowColor).opacity(0.25),
                            radius: 0, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
    }
}
