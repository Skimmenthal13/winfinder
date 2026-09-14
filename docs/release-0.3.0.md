# Win Finder 0.3.0 candidate — build 11

Status: signed and notarized candidate, not published. On 2026-09-14 Apple
accepted both the app submission and the final DMG. Tickets are stapled to the
app and DMG; Gatekeeper accepts both as `Notarized Developer ID`. The app was
also verified directly inside the final DMG, including both architectures and
all embedded Sparkle components.

Local packages, notarization receipts and SHA-256 checksums are in
`release-artifacts/0.3.0/` (excluded from Git). `WinFinder-v0.3.0.dmg` is the
installer with an Applications shortcut; `WinFinder-v0.3.0.zip` contains the
stapled app. These supersede the earlier unsigned candidate in `/tmp`.

## Release notes draft

Win Finder now targets macOS 14 Sonoma and later on Apple Silicon and Intel.
This corrects the minimum OS mismatch reported in #2. Earlier downloadable builds
still require macOS 26.

This update also adds back/forward navigation and keyboard shortcuts, keeps file
commands confined to the active window, fixes cut/paste between windows, and
shows errors when file operations fail. Transfers and ZIP creation run in the
background. Search refreshes after filesystem changes, cancels obsolete queries,
and explicitly reports the 500-result limit. Sorting survives refreshes.

## Remaining release steps

1. Run the commands in [testing.md](testing.md). They include the compatibility
   check for the main executable and all embedded Mach-O components.
2. If any executable or bundle content changes, create a new signed archive,
   repeat notarization, and verify the newly packaged app. The current candidate
   has already completed this process.
3. Ask the issue reporter to test the signed candidate on Sequoia. There is no
   local macOS 14/15 runtime validation yet.
4. Publish a new v0.3.0 release only when ready. Generate a new Sparkle signature
   and enclosure size from the final DMG. Use build 11 and minimumSystemVersion
   14.0 in the new appcast entry, then update the website download link and remove
   the temporary published-v0.2.0 compatibility notice from the READMEs.

## Draft reply to issue #2 (not sent)

Thanks for the detailed report. The project now targets macOS 14 Sonoma, the
minimum required by its Observation APIs. The candidate builds for both Apple
Silicon and Intel, and checks confirm a 14.0 minimum for the app and compatible
minima for embedded Sparkle components. The old DMGs are unchanged. The v0.3.0 candidate is now Developer ID signed and Apple-notarized;
testing it on your Sequoia Mac would be very helpful before the final release.

## Signing and notarization references

The candidate uses Xcode's Developer ID archive/export workflow so embedded
Sparkle helpers are signed for distribution. See [Sparkle's distribution
documentation](https://sparkle-project.org/documentation/) and [Apple's custom
notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
The ZIP submitted to Apple was followed by stapling the app, then creating,
signing, notarizing and stapling the final DMG. The distributable ZIP was
recreated from the stapled app.
