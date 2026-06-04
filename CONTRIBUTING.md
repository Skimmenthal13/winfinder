# Contributing to Win Finder

Thank you for your interest in contributing! Win Finder is built for people who switched from Windows to Mac and find Finder's UX frustrating. The best contributions come from people who actually feel that friction.

## Ways to Contribute

### Report a bug
Open an [issue](https://github.com/Skimmenthal13/winfinder/issues) and include:
- macOS version and chip (Apple Silicon or Intel)
- Win Finder version
- Steps to reproduce
- What you expected vs what happened

### Suggest a feature
Open an issue with the `enhancement` label. Describe the Windows Explorer behavior you're trying to replicate or the workflow you're trying to improve.

### Submit a pull request
1. Fork the repository
2. Create a branch: `git checkout -b feature/your-feature-name`
3. Make your changes
4. Test on macOS 13+ (Ventura or later)
5. Commit with a clear message: `git commit -m "Add: column resizing support"`
6. Push and open a Pull Request against `main`

## Code Style

- Swift idiomatic code — follow existing patterns in the codebase
- Keep UI changes consistent with the existing aesthetic (native macOS controls, no third-party UI frameworks)
- Comment non-obvious logic

## Extension System Contributions

If you're contributing a ready-made extension (JSON action file), consider opening a PR against the community extension library repo (coming soon) rather than the main repo.

## Translations

Win Finder currently supports English, Italian, German, Spanish, Simplified Chinese, and Malagasy. If you want to add or improve a translation, edit the relevant `.lproj` strings file and open a PR.

## What Gets Merged

PRs are more likely to be merged if they:
- Fix a real bug or replicate a genuine Windows Explorer behavior
- Are focused and minimal (one thing at a time)
- Don't introduce external dependencies
- Work on both Apple Silicon and Intel

## Questions

Open an issue — there are no dumb questions, especially from Windows refugees still finding their feet on macOS.
