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
- [ ] Signed/notarized DMG is created with Developer ID credentials.
- [ ] `codesign --verify --deep --strict --verbose=2 release/MacAppGrid.app` passes.
- [ ] `xcrun stapler validate release/MacAppGrid-0.1.0-beta.1.dmg` passes.
- [ ] Gatekeeper assessment passes for the signed/notarized DMG.
- [ ] Login item behavior is checked from the signed app in `/Applications`.

## Release

- [ ] Create tag `v0.1.0-beta.1`.
- [ ] Confirm GitHub Actions build succeeds.
- [ ] Confirm Release contains the DMG asset.
- [ ] Add release notes with highlights and known issues.
