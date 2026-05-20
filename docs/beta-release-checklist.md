# Beta Release Checklist

Target: `v0.1.0-beta.1`

## Required

- [ ] README status says beta candidate and does not mention alpha.
- [ ] `CHANGELOG.md` is updated.
- [ ] `KNOWN_ISSUES.md` is updated.
- [ ] `PRIVACY.md` and `SECURITY.md` are present.
- [ ] `swift build` passes.
- [ ] `swift test` passes.
- [ ] `xcodebuild -scheme MacAppGrid -destination 'platform=macOS' build` passes.
- [ ] `./script/build_and_run.sh --verify` passes.
- [ ] `./script/release_build.sh` creates a local DMG.
- [ ] Local DMG checksum is created as `release/*.dmg.sha256`.
- [ ] Signed/notarized DMG is created with Developer ID credentials.
- [ ] `codesign --verify --deep --strict --verbose=2 release/MacAppGrid.app` passes.
- [ ] `spctl --assess --type execute --verbose release/MacAppGrid.app` passes for signed builds.
- [ ] `xcrun stapler validate release/MacAppGrid-0.1.0-beta.1.dmg` passes.
- [ ] Gatekeeper assessment passes for the signed/notarized DMG.
- [ ] `shasum -a 256 -c release/MacAppGrid-0.1.0-beta.1.dmg.sha256` passes.
- [ ] Login item behavior is checked from the signed app in `/Applications`.
- [ ] Trackpad gestures are checked on real hardware.
- [ ] External display behavior is checked.
- [ ] Fullscreen-app overlay behavior is checked.

## Release

- [ ] Create tag `v0.1.0-beta.1`.
- [ ] Confirm GitHub Actions build succeeds.
- [ ] Confirm tag releases fail if Developer ID/notarization secrets are missing.
- [ ] Confirm Release contains the DMG and SHA256 assets.
- [ ] Add release notes with highlights and known issues.
