# Verification

Use Xcode 26 or newer and the shared `winfinder` scheme. Tests create isolated
folders in the temporary directory; they do not operate on personal documents.

```sh
xcodebuild -project winfinder.xcodeproj -scheme winfinder \
  -destination 'platform=macOS' -derivedDataPath /tmp/winfinder-tests \
  CODE_SIGNING_ALLOWED=NO test

xcodebuild -project winfinder.xcodeproj -scheme winfinder \
  -configuration Release -derivedDataPath /tmp/winfinder-tests \
  CODE_SIGNING_ALLOWED=NO ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build

python3 scripts/check_macos_compatibility.py \
  '/tmp/winfinder-tests/Build/Products/Release/Win Finder.app'
```

The tests cover stale selection, ordering after reload and during search,
non-destructive name collisions, and real ZIP creation (nested names, failure
cleanup, and existing archives). Compression runs a child process asynchronously;
archives preserve paths relative to the current directory and store symlinks as
links rather than following them. Only one compression per window runs at a time.

The GitHub workflow runs the same checks on pushes and pull requests. It uses
GitHub's [macOS runner images](https://github.com/actions/runner-images) and
[checkout action](https://github.com/actions/checkout). No signing secrets are
required. It does not publish releases. GitHub execution is verified only after
the workflow has been pushed and has run successfully.

The compatibility check reads the app plist and every embedded Mach-O image,
including Sparkle helpers, and verifies both architectures and OS minima.
It does not prove runtime compatibility with macOS 14 or 15.

Before a release, also exercise two windows manually: select a disposable file
in each; rename/delete only in the active window; cut in one and paste in the
other; navigate back/forward; try renaming to an existing name. Verify that
compression leaves the interface responsive and that an error never leaves a
partial ZIP exposed as the final archive.

Transfers use a shared background queue, with progress measured in completed
items rather than bytes. Copies are built in a private temporary folder and
published when complete. Moving a folder into itself is rejected, including
paths that traverse symlinks. Moving an item to its existing parent is a no-op.
Errors are collected after the batch; a failed cut/paste can be retried without
moving successful items again. Clipboard tests use uniquely named pasteboards,
so they do not replace the user's clipboard.

Recursive search waits 200 ms after changes, cancels obsolete work with a
synchronized token, and refreshes through the same reload path used by filesystem
events. A notice appears only when more than 500 entries match. Tests exercise
refresh, rapid query changes, the 500/501 boundary, transfer collisions, partial
failure and clipboard retries.
