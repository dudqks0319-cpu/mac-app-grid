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
- Supports Launchpad-style folder mode: apps inside folders can be hidden from the main grid while remaining searchable.
- Supports app-to-app drag folder creation when that setting is enabled.
- Tracks recent and frequent apps after successful launches.

## What Is Not Finished

- Polished hotkey conflict detection.
- Full Launchpad-quality folder hover animation.
- Apple Developer ID certificate-backed signing and notarization in this checkout.
- Fully signed GitHub Release automation with Apple credentials.

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

## Install

For local testing, build the DMG and drag `MacAppGrid.app` into `/Applications`.

```bash
./script/release_build.sh
open release/MacAppGrid-0.1.0.dmg
```

Unsigned local builds may show Gatekeeper warnings. Public distribution should use a Developer ID signed and notarized DMG.

## Uninstall

Quit MacAppGrid from the menu bar, remove the app from `/Applications`, then remove runtime data if you want a clean reset:

```bash
rm -rf "$HOME/Library/Application Support/MacAppGrid"
```

## Troubleshooting

- If apps are missing, open Settings > Advanced and run app refresh.
- If layout or folder state looks wrong, use layout reset.
- If cached data appears corrupt, delete app/icon cache from Settings > Advanced.
- If login item toggling fails, retry from a signed `.app` bundle in `/Applications`.

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
