# Win Finder 0.3.0 candidate — build 11

Status: local candidate, not published. The release has not been signed or
notarized. Do not replace the historical DMGs or add an appcast enclosure until
the final artifact has been produced and its signature and size are known.

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
2. Archive/export using the project's Developer ID signing configuration and
   complete Apple's notarization process. Verify the final exported app and the
   app inside the final DMG with the compatibility checker again.
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
minima for embedded Sparkle components. The old DMGs are unchanged. We are
preparing v0.3.0; testing the signed candidate on your Sequoia Mac would be very
helpful before the final release.
