# Changelog

## v0.1.0-beta.1 - Planned

### Highlights

- Launchpad-style app grid launcher for macOS.
- App search and launch through `NSWorkspace`.
- Folder mode with app-to-app drag folder creation.
- Apps inside folders can be hidden from the main grid while remaining searchable.
- Hidden apps, layout reset, cache reset, and diagnostics in Settings.
- Custom global hotkey recording with fallback behavior.
- Login item support through `SMAppService`.
- Local JSON storage under Application Support.
- SwiftPM tests and GitHub Actions CI.
- Larger app grid cells, centered page controls, and launcher sort modes.
- More robust overlay dismissal for Escape, spread gestures, and stale window state.
- Compact recent/frequent app strips.
- Release packaging now creates SHA256 checksums and enforces signing credentials for tag releases.

### Known Limits

- Signed and notarized DMG requires Apple Developer credentials.
- Folder hover preview and Launchpad-grade animation are not complete.
- Hotkey conflict detection is best-effort and still depends on Carbon registration results.
- Mac App Store submission requires a separate sandbox-safe review track.
