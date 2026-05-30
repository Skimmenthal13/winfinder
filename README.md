# Win Finder

A file manager for macOS that feels like home — for anyone who comes from Windows.

🇬🇧 English &nbsp; [🇮🇹 Italiano](README.it.md) &nbsp; [🇩🇪 Deutsch](README.de.md) &nbsp; [🇪🇸 Español](README.es.md) &nbsp; [🇨🇳 中文](README.zh.md) &nbsp; [🇲🇬 Malagasy ❤️](README.mg.md)

![Win Finder screenshot](docs/screenshot.png)

## Why Win Finder?

macOS is a great operating system. But if you spent years on Windows, the Finder feels wrong in ways that are hard to explain: no editable path bar, no inline search, no right-click "New File", Delete doesn't delete. Small things that add up to constant friction.

Win Finder fixes that. It's a native macOS file manager built around the workflows that Windows users already know.

## Features

- **Editable path bar** — always visible, 80% of the toolbar width. Click it, type a path, press Enter. Works exactly like Windows Explorer.
- **Breadcrumb navigation** — the path bar shows each folder as a clickable token. Click any segment to navigate there. Click the `>` separator to see subfolders at that level. Click empty space on the right to switch to editable text mode.
- **Inline search** — search field always visible next to the path bar. Searches recursively through all subfolders by default. Supports wildcards (`*.pdf`, `doc*`). Results show the relative path so you always know where a file lives.
- **Sidebar** — Favorites (Desktop, Documents, Downloads, Pictures), Locations, Devices, and Recent paths — saved across sessions.
- **Windows Explorer-style list** — Name, Date Modified, Size columns with clickable headers for sorting. Folders always on top.
- **Colorful file icons** — 404 file type icons from the [file-icon-vectors](https://github.com/dmhendricks/file-icon-vectors) Vivid set. PDF files are red, ZIPs are purple, Swift files are orange — just like you'd expect on Windows.
- **Right-click context menu** — Open, Open With, Copy, Cut, Paste, Rename, Compress to ZIP, New Folder, New File (creates an empty file with an editable name), AirDrop, Delete.
- **Keyboard shortcuts** — `Delete` moves to Trash, `Shift+Delete` permanently deletes with confirmation, `Cmd+C` / `Cmd+V` copy and paste files.
- **Type-to-select** — press a letter to jump to the first file starting with that letter. Press again to cycle through matches.
- **Drag and drop** — between two Win Finder windows, and to/from the sidebar. `Cmd` held while dragging copies instead of moving.
- **Multi-selection** — `Shift+click` for range selection, `Cmd+click` to toggle individual items.
- **AirDrop** from right-click — share any file directly without opening Finder.
- **Real-time file system monitoring** — the list updates automatically when files change on disk.
- **Extension system** — add custom actions to the right-click menu via JSON files. Supports nested submenus, separators, custom icons, and context filtering. Manage everything from **Win Finder → Manage Extensions**.
- **Multilanguage** — available in English 🇬🇧, Italian 🇮🇹, German 🇩🇪, Spanish 🇪🇸, and Simplified Chinese 🇨🇳. The interface language follows the system language automatically.

## Extension system

Any app can integrate with Win Finder by creating a folder in `~/.config/winfinder/actions/` with an `action.json` file and an optional `icon.png`:

```
~/.config/winfinder/actions/
  my-app/
    action.json
    icon.png        ← loaded automatically if icon field is omitted in JSON
```

```json
{
  "name": "Git",
  "extensions": ["*"],
  "context": ["folder", "background"],
  "submenu": [
    { "name": "Pull", "command": "cd '{file}' && git pull" },
    { "name": "Push", "command": "cd '{file}' && git push" },
    { "separator": true },
    {
      "name": "Branch",
      "submenu": [
        { "name": "Pull from main", "command": "cd '{file}' && git pull origin main" },
        { "name": "Pull from develop", "command": "cd '{file}' && git pull origin develop" }
      ]
    }
  ]
}
```

**Fields:**
- `name` — label shown in the menu
- `extensions` — file extensions to match, or `["*"]` for all files
- `context` — where the action appears: `"file"`, `"folder"`, `"background"` (default: `["file", "folder"]`)
- `command` — shell command to run, `{file}` is replaced with the selected file path
- `submenu` — array of nested items (mutually exclusive with `command`)
- `icon` — optional path to a PNG icon file (if omitted, `icon.png` in the same folder is used automatically)
- `separator` — set to `true` for a menu divider

Win Finder reads these files at startup and adds the actions to the right-click menu automatically — no API, no SDK, no approval process. Use **Win Finder → Manage Extensions** to enable, disable, or delete extensions without touching the filesystem.

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

- [ ] `Option+Tab` to cycle between Win Finder windows
- [ ] Column resizing
- [ ] Icon view and thumbnail preview
- [ ] Keyboard shortcut customization
- [ ] Community extension library — a separate repo with ready-made JSON actions for popular apps (VS Code, iTerm2, Git, FFmpeg...)
- [ ] **"Open with Win Finder"** in Finder's right-click menu — Finder Sync Extension that adds "Open with Win Finder" to the Finder context menu and registers Win Finder as a handler for `public.folder`
- [ ] **WinFinderPicker** — allow third-party developers to use Win Finder as an alternative file picker in their own apps. Two approaches under evaluation: a **Swift Package (SPM)** that developers import directly, or an **XPC Service** that Win Finder exposes as a system service invoked via IPC. The best approach will be chosen based on architecture and developer experience.

## Contributing

Win Finder is open source and welcomes contributions. If you switched from Windows and something feels off, open an issue — that's exactly the kind of feedback that improves this project.

1. Fork the repo
2. Create a branch (`git checkout -b feature/your-feature`)
3. Commit your changes
4. Open a pull request

## Credits

File type icons from [file-icon-vectors](https://github.com/dmhendricks/file-icon-vectors) by [@dmhendricks](https://github.com/dmhendricks) — a fantastic collection of 400+ SVG file type icons, licensed CC BY-SA 4.0. Thank you for making this available to the community.

## License

MIT — do whatever you want with it.

---

Built by [@Skimmenthal13](https://github.com/Skimmenthal13) — a Windows refugee who got tired of fighting the Finder.

> 🤖 This entire project was built with **vibe coding** using [Claude Code](https://claude.ai/code) — from the first line of Swift to the extension system, breadcrumb navigation, and file icons. No shame, only pride.
