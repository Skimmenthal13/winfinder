# WinFinder

A file manager for macOS that feels like home — for anyone who comes from Windows.

![WinFinder screenshot](docs/screenshot.png)

## Why WinFinder?

macOS is a great operating system. But if you spent years on Windows, the Finder feels wrong in ways that are hard to explain: no editable path bar, no inline search, no right-click "New File", Delete doesn't delete. Small things that add up to constant friction.

WinFinder fixes that. It's a native macOS file manager built around the workflows that Windows users already know.

## Features

- **Editable path bar** — always visible, 80% of the toolbar width. Click it, type a path, press Enter. Works exactly like Windows Explorer.
- **Inline search** — search field always visible next to the path bar, filters the current folder in real time. Supports wildcards (`*.pdf`, `doc*`).
- **Sidebar** — Favorites (Desktop, Documents, Downloads, Pictures), Locations, Devices, and Recent paths — saved across sessions.
- **Windows Explorer-style list** — Name, Date Modified, Size columns with clickable headers for sorting. Folders always on top.
- **Right-click context menu** — Open, Open With, Copy, Cut, Paste, Rename, Compress to ZIP, New Folder, New File (creates an empty file with an editable name), AirDrop, Delete.
- **Keyboard shortcuts** — `Delete` moves to Trash, `Shift+Delete` permanently deletes with confirmation, `Cmd+C` / `Cmd+V` copy and paste files.
- **Type-to-select** — press a letter to jump to the first file starting with that letter. Press again to cycle through matches.
- **Drag and drop** — between two WinFinder windows, and to/from the sidebar. `Cmd` held while dragging copies instead of moving.
- **Multi-selection** — `Shift+click` for range selection, `Cmd+click` to toggle individual items.
- **AirDrop** from right-click — share any file directly without opening Finder.
- **Real-time file system monitoring** — the list updates automatically when files change on disk.

## Installation

### Requirements
- macOS 13 Ventura or later
- Apple Silicon or Intel Mac

### Build from source

```bash
git clone https://github.com/Skimmenthal13/winfinder.git
cd winfinder
open winfinder.xcodeproj
```

Then press `Cmd+R` in Xcode to build and run.

## Roadmap

- [ ] `Option+Tab` to cycle between WinFinder windows
- [ ] Customizable right-click actions ("Open with Notepad++")
- [ ] Column resizing
- [ ] Icon view and thumbnail preview
- [ ] Tabs
- [ ] Keyboard shortcut customization

## Contributing

WinFinder is open source and welcomes contributions. If you switched from Windows and something feels off, open an issue — that's exactly the kind of feedback that improves this project.

1. Fork the repo
2. Create a branch (`git checkout -b feature/your-feature`)
3. Commit your changes
4. Open a pull request

## License

MIT — do whatever you want with it.

---

Built by [@Skimmenthal13](https://github.com/Skimmenthal13) — a Windows refugee who got tired of fighting the Finder.

## Credits

File type icons in the file list are from the [file-icon-vectors](https://github.com/dmhendricks/file-icon-vectors) project (Vivid set) by Daniel M. Hendricks, licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
