# Changelog

## 0.3.0 — release candidate, build 11 (not published)

### Compatibility
- Target macOS 14 Sonoma instead of macOS 26. Observation APIs require macOS 14;
  macOS 13 is not supported. Addresses the source/build mismatch in issue #2.
- Verify both Apple Silicon and Intel slices, including embedded Sparkle helpers.
- Correct the feed metadata for the existing v0.2.0 and v0.1.8 downloads; historical
  DMGs remain unchanged and still require macOS 26.

### File operations
- Run copying and moving in the background, with per-item progress and a summary
  of errors. Completed copies are published from temporary staging folders.
- Share cut/paste state across windows and preserve failed moves for retry.
- Keep keyboard actions scoped to the active window; fix Delete event consumption.
- Report creation, rename and deletion failures instead of silently ignoring them.
- Create ZIP archives asynchronously, preserve nested paths and existing archives,
  and avoid publishing incomplete archives on compression failure.
- Pass extension file paths as shell arguments, accepting bare `{file}` and the
  documented standalone quoted placeholders.

### Navigation and search
- Add back/forward history and Option+Left/Right shortcuts.
- Add F2 rename, new file/folder shortcuts and the keyboard shortcuts panel.
- Preserve sorting across refresh and search, with folders first.
- Clear stale selections after deletion or navigation.
- Refresh active searches after filesystem changes, debounce and cancel obsolete
  searches, and display a notice when more than 500 results match.

### Maintenance
- Add a shared Xcode scheme, 17 regression tests, a universal-build compatibility
  checker and a GitHub Actions workflow.
- Keep app version and build number in Xcode build settings as the single source
  used by the generated Info.plist.

### Validation limits
- Local tests run on the available Mac. Runtime testing on macOS 14/15 is pending.
- GitHub Actions has not run remotely yet. Developer ID signing and Apple
  notarization are complete for the app and DMG, with stapled tickets and
  successful Gatekeeper checks. Publishing is still pending.
