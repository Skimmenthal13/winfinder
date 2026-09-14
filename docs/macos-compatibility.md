# macOS compatibility and release verification

The source now targets macOS 14 Sonoma or later. SwiftUI Observation (`@Observable` and `@Bindable`) and the two-argument `onChange` handlers require macOS 14.

Previously published DMGs are not changed by this fix. Issue #2 reports that v0.2.0, v0.1.8, and v0.1.0-beta require macOS 26. The appcast entries for v0.2.0 and v0.1.8 therefore retain a minimum of 26.0 to describe their existing binaries. Audit other historical DMGs before changing their feed metadata.

## Before publishing the corrected release

1. Increment the app version and build number; create a new release rather than replacing signed historical DMGs.
2. Archive a Release build for both arm64 and x86_64 using the project's deployment target, with no command-line override.
3. Check the exported app (and again the app inside the final DMG):

```sh
/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' 'Win Finder.app/Contents/Info.plist'
xcrun vtool -show-build 'Win Finder.app/Contents/MacOS/Win Finder'
lipo -archs 'Win Finder.app/Contents/MacOS/Win Finder'
```

The plist minimum and Mach-O `minos` for both architectures must be 14.0. The SDK version may be newer. Inspect embedded frameworks as well to ensure none requires a newer OS.

4. Sign and notarize using the usual release process. Add a new appcast entry with minimumSystemVersion 14.0, the new version/build, enclosure size, URL, and Sparkle signature from the final artifact.
5. Test launch, navigation, file operations, settings, extensions, and updating on macOS 14 and macOS 15. A successful build on a newer OS does not replace these runtime checks. The reporter of issue #2 offered to test on Sequoia.
