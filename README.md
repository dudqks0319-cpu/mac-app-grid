# MacAppGrid

MacAppGrid is a beta-candidate standalone macOS app grid launcher. It provides a safe Launchpad-style workflow without modifying Apple Launchpad internals, requiring SIP changes, or using private APIs.

Current status: beta candidate for local testing, not yet notarized for public release.

Recommended first release path: Developer ID signed and notarized DMG distribution outside the Mac App Store. A Mac App Store edition should be treated as a separate sandbox-safe review track.

## What Works

- Scans common macOS application folders.
- Shows app icons and names in a grid.
- Searches apps by name.
- Launches apps through `NSWorkspace`.
- Opens from a menu bar icon, configurable global hotkey, and Launchpad-style `Command + L` shortcut.
- Uses larger default grid cells so the launcher fills the display more like Launchpad.
- Supports trackpad gestures: pinch in opens the launcher best-effort, spread closes it, and two-finger horizontal movement changes pages.
- Supports basic folders and app ordering.
- Includes a Settings window for launch behavior, icon size, hidden apps, refresh, and layout reset.
- Supports login item toggling through `SMAppService`.
- Stores settings, layout, folders, usage, and app cache JSON under Application Support.
- Supports Launchpad-style folder mode: apps inside folders can be hidden from the main grid while remaining searchable.
- Supports app-to-app drag folder creation when that setting is enabled.
- Supports launcher sort modes for saved custom layout, original app order, alphabetical order, and recently opened order.
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
Signing and notarization run only when the required local Apple credentials are configured. The script always writes a SHA256 checksum next to the DMG.

```bash
./script/release_build.sh
```

Optional signed/notarized build:

```bash
VERSION="0.1.0-beta.1" \
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARYTOOL_PROFILE="your-notarytool-profile" \
./script/release_build.sh
```

Strict public release build:

```bash
VERSION="0.1.0-beta.1" \
REQUIRE_SIGNED_RELEASE=1 \
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARYTOOL_PROFILE="your-notarytool-profile" \
./script/release_build.sh
```

Signed release verification:

```bash
codesign --verify --deep --strict --verbose=2 release/MacAppGrid.app
spctl --assess --type execute --verbose release/MacAppGrid.app
spctl --assess --type open --context context:primary-signature --verbose release/MacAppGrid-0.1.0-beta.1.dmg
xcrun stapler validate release/MacAppGrid-0.1.0-beta.1.dmg
shasum -a 256 -c release/MacAppGrid-0.1.0-beta.1.dmg.sha256
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

## Distribution Strategy

MacAppGrid should ship publicly as a Developer ID signed and notarized DMG first. The app intentionally avoids private APIs, SIP changes, administrator privileges, and Apple Launchpad database modification, but it still uses app-folder scanning, a menu bar app, global hotkeys, login item integration, a fullscreen overlay, and best-effort trackpad gestures. Those features fit external Developer ID distribution better than a first-pass Mac App Store submission.

Mac App Store submission should be evaluated later on a separate `appstore-sandbox` branch. That edition should enable App Sandbox, avoid "Launchpad restoration" marketing language, and provide a user-selected Applications folder fallback with security-scoped bookmarks if direct app scanning is restricted.

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
- If the menu bar icon is hidden and the hotkey stops working, relaunch the app from Finder or Terminal. MacAppGrid forces the menu bar icon visible when hotkey registration fails.
- If a custom hotkey does not register, restore the default Option + Space shortcut in Settings.

## Beta Release Gate

See:

- [CHANGELOG.md](CHANGELOG.md)
- [KNOWN_ISSUES.md](KNOWN_ISSUES.md)
- [PRIVACY.md](PRIVACY.md)
- [SECURITY.md](SECURITY.md)
- [docs/distribution-strategy.md](docs/distribution-strategy.md)
- [docs/beta-release-checklist.md](docs/beta-release-checklist.md)
- [docs/manual-qa-checklist.md](docs/manual-qa-checklist.md)

## Requirements

- macOS 14 or later
- Xcode command line tools
- Swift 6.1 toolchain or compatible

## Safety Boundaries

- No private macOS APIs.
- No SIP disablement.
- No administrator privileges.
- No Apple Launchpad database modification.
- No network transmission of app inventory data.
