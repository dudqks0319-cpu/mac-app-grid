# Distribution Strategy

MacAppGrid has two realistic release tracks. The first public track should be Developer ID distribution. A Mac App Store edition should be a later sandbox-safe variant.

## Track 1: Developer ID External Distribution

Recommended for `v0.1.0-beta.1`.

Requirements:

- Developer ID Application certificate.
- Hardened Runtime signing.
- Notarized and stapled DMG.
- Gatekeeper assessment.
- SHA256 checksum.
- Public documentation for privacy, security, install, uninstall, and known issues.

This track preserves the current product behavior:

- Scans common Applications folders.
- Launches apps through `NSWorkspace`.
- Provides global hotkeys and a menu bar entry.
- Supports login item registration through `SMAppService`.
- Uses a fullscreen overlay and best-effort trackpad gestures.
- Stores app metadata, layout, folders, hidden apps, usage counts, and settings locally.

Public unsigned DMGs should not be shipped. Unsigned builds are for local testing only.

## Track 2: Mac App Store Sandbox Edition

Recommended after external beta validation.

Create a separate `appstore-sandbox` branch before making App Store-specific tradeoffs.

Expected changes:

- Enable App Sandbox.
- Keep network access disabled unless a future feature explicitly needs it.
- Avoid "Launchpad restoration" or "Apple Launchpad replacement" marketing.
- Present the app as a standalone Mac app grid launcher.
- Add an `NSOpenPanel` fallback when sandbox restrictions block direct app-folder scanning.
- Store security-scoped bookmarks for user-selected Applications folders.
- Make global gestures optional or disable them if review or sandbox behavior is unreliable.
- Keep administrator privileges, SIP changes, private APIs, and Launchpad database edits out of scope.

## Marketing Language

Use:

- Mac app grid launcher.
- Launchpad-style workflow.
- Safe standalone app launcher.
- Does not modify Apple Launchpad internals.

Avoid:

- Launchpad restoration.
- Apple Launchpad replacement.
- Restores Apple system features.
- Modifies system Launchpad.

## Release Gate

A public beta release should pass:

- `swift build`
- `swift test`
- `xcodebuild -scheme MacAppGrid -destination 'platform=macOS' build`
- `./script/build_and_run.sh --verify`
- `REQUIRE_SIGNED_RELEASE=1 ./script/release_build.sh` with Developer ID and notarytool credentials
- `codesign --verify --deep --strict --verbose=2 release/MacAppGrid.app`
- `spctl --assess --type execute --verbose release/MacAppGrid.app`
- `spctl --assess --type open --context context:primary-signature --verbose release/MacAppGrid-<version>.dmg`
- `xcrun stapler validate release/MacAppGrid-<version>.dmg`
- `shasum -a 256 -c release/MacAppGrid-<version>.dmg.sha256`
