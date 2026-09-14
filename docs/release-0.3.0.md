# Win Finder 0.3.0 candidate — build 11

Status: signed and notarized, published as a GitHub prerelease. On 2026-09-14
Apple accepted both the app submission and the final DMG. Tickets are stapled
to the app and DMG; Gatekeeper accepts both as `Notarized Developer ID`. The
app was also verified directly inside the final DMG, including both
architectures and all embedded Sparkle components. The DMG is Sparkle-signed
(see `release-artifacts/0.3.0/sparkle-signature.txt`), but the appcast has
intentionally not been updated yet — this is a prerelease pending Sequoia
feedback, not the promoted stable channel.

Published at https://github.com/Skimmenthal13/winfinder/releases/tag/v0.3.0.

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
3. Done: asked the issue reporter (#2) to test the signed candidate on
   Sequoia — https://github.com/Skimmenthal13/winfinder/issues/2#issuecomment-5670859864.
   There is still no local macOS 14/15 runtime validation.
4. Done: published as a GitHub prerelease
   (https://github.com/Skimmenthal13/winfinder/releases/tag/v0.3.0) with the
   DMG, ZIP and SHA256SUMS.txt attached.
5. Once Sequoia feedback comes back positive, promote the release (uncheck
   prerelease), add the appcast entry (build 11, minimumSystemVersion 14.0,
   the Sparkle signature already generated in
   `release-artifacts/0.3.0/sparkle-signature.txt`), update the website
   download link, and remove the temporary published-v0.2.0 compatibility
   notice from the READMEs.

## Reply sent to issue #2

Posted at https://github.com/Skimmenthal13/winfinder/issues/2#issuecomment-5670859864,
linking the published prerelease and asking for a test on Sequoia.

## Signing and notarization references

The candidate uses Xcode's Developer ID archive/export workflow so embedded
Sparkle helpers are signed for distribution. See [Sparkle's distribution
documentation](https://sparkle-project.org/documentation/) and [Apple's custom
notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
The ZIP submitted to Apple was followed by stapling the app, then creating,
signing, notarizing and stapling the final DMG. The distributable ZIP was
recreated from the stapled app.
