# Win Finder 0.3.0 — build 11

Status: stable release, promoted from the GitHub prerelease on 2026-09-23. On 2026-09-14
Apple accepted both the app submission and the final DMG. Tickets are stapled
to the app and DMG; Gatekeeper accepts both as `Notarized Developer ID`. The
app was also verified directly inside the final DMG, including both
architectures and all embedded Sparkle components. The DMG is Sparkle-signed
(see `release-artifacts/0.3.0/sparkle-signature.txt`), and the stable appcast now advertises build 11 with a macOS 14.0 minimum.
The website download and all six READMEs point to 0.3.0.

Published at https://github.com/Skimmenthal13/winfinder/releases/tag/v0.3.0.

Local packages, notarization receipts and SHA-256 checksums are in
`release-artifacts/0.3.0/` (excluded from Git). `WinFinder-v0.3.0.dmg` is the
installer with an Applications shortcut; `WinFinder-v0.3.0.zip` contains the
stapled app. These supersede the earlier unsigned candidate in `/tmp`.

## Release notes

Win Finder now targets macOS 14 Sonoma and later on Apple Silicon and Intel.
This corrects the minimum OS mismatch reported in #2. The unchanged v0.2.0 and v0.1.8 DMGs
still require macOS 26.

This update also adds back/forward navigation and keyboard shortcuts, keeps file
commands confined to the active window, fixes cut/paste between windows, and
shows errors when file operations fail. Transfers and ZIP creation run in the
background. Search refreshes after filesystem changes, cancels obsolete queries,
and explicitly reports the 500-result limit. Sorting survives refreshes.

## Validation and publication

- Published the signed and notarized DMG, ZIP and SHA256SUMS.txt as a prerelease
  on 2026-09-14. The stable release reuses these exact assets without rebuilding.
- Verified local package sizes and SHA-256 checksums against the published assets
  before promotion. The appcast uses the existing Sparkle signature.
- GitHub Actions passed for commit `804287a`, including the project checks.
- On 2026-09-23, the maintainer chose to release without waiting for the issue
  reporter. Issue #2 is documented as fixed by the corrected deployment target
  and release metadata. Direct runtime testing on macOS 14/15 and reporter
  confirmation remain pending; no such confirmation is claimed.
- Future executable or bundle changes require a new signed archive, notarization
  and package verification. See [testing.md](testing.md) for validation commands.

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
