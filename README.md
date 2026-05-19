# MacAppGrid

MacAppGrid is an alpha-stage standalone macOS app grid launcher. It is intended to provide a safe Launchpad-style workflow without modifying Apple Launchpad internals, requiring SIP changes, or using private APIs.

Current status: alpha prototype, not ready for public release.

## What Works

- Scans common macOS application folders.
- Shows app icons and names in a grid.
- Searches apps by name.
- Launches apps through `NSWorkspace`.
- Opens from a menu bar icon and global hotkey.
- Supports basic folders and app ordering.
- Tracks recent and frequent apps after successful launches.

## What Is Not Finished

- Settings UI.
- Login item support.
- Hidden app management.
- Application Support JSON persistence.
- App and icon caching.
- Launchpad-style drag-to-folder UX.
- Release signing, notarization, and DMG packaging.

## Build

```bash
swift build
```

## Run

For local GUI testing, use the project script. It builds the SwiftPM executable, stages a local `.app` bundle under `dist/`, opens it, and verifies the process starts.

```bash
./script/build_and_run.sh --verify
```

Default run:

```bash
./script/build_and_run.sh
```

## Requirements

- macOS 14 or later
- Xcode command line tools
- Swift 6.2 toolchain or compatible

## Safety Boundaries

- No private macOS APIs.
- No SIP disablement.
- No administrator privileges.
- No Apple Launchpad database modification.
- No network transmission of app inventory data.

