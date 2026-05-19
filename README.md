# MacAppGrid

MacAppGrid is an alpha-stage standalone macOS app grid launcher. It is intended to provide a safe Launchpad-style workflow without modifying Apple Launchpad internals, requiring SIP changes, or using private APIs.

Current status: MVP candidate for local testing, not yet notarized for public release.

## What Works

- Scans common macOS application folders.
- Shows app icons and names in a grid.
- Searches apps by name.
- Launches apps through `NSWorkspace`.
- Opens from a menu bar icon and global hotkey.
- Supports basic folders and app ordering.
- Includes a Settings window for launch behavior, icon size, hidden apps, refresh, and layout reset.
- Supports login item toggling through `SMAppService`.
- Stores settings, layout, folders, usage, and app cache JSON under Application Support.
- Tracks recent and frequent apps after successful launches.

## What Is Not Finished

- Custom hotkey recording UI.
- Full Launchpad-style drag-app-onto-app folder creation.
- Apple Developer ID certificate-backed signing and notarization in this checkout.
- GitHub Release upload automation.

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

## Release Package

The release script builds a Release app bundle and creates a DMG under `release/`.
Signing and notarization run only when the required local Apple credentials are configured.

```bash
./script/release_build.sh
```

Optional signed/notarized build:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARYTOOL_PROFILE="your-notarytool-profile" \
./script/release_build.sh
```

Runtime data is stored here:

```txt
~/Library/Application Support/MacAppGrid/
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
