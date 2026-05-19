# Known Issues

- Public release DMGs must be Developer ID signed and notarized. Unsigned local DMGs may trigger Gatekeeper warnings.
- Hotkey conflict detection is best-effort. Some system or third-party shortcuts may only be detected after registration fails.
- Folder creation works by dropping one app onto another, but the hover preview is not yet Launchpad-quality.
- Login item behavior should be validated again from a signed `.app` installed in `/Applications`.
- Icon caching is currently in-memory. App metadata is cached on disk.
- UI automation coverage is limited; current automated tests focus on storage and policy logic.
