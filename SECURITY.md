# Security

## Supported Versions

Security fixes target the latest `main` branch until the first tagged beta release is published.

## Reporting

Open a GitHub issue with a clear reproduction path for non-sensitive reports. For sensitive vulnerabilities, use GitHub private vulnerability reporting if it is enabled for the repository, or contact the maintainer before public disclosure.

Do not include sensitive app inventory, local paths, or private logs unless they are required and redacted.

## Security Boundaries

- No private macOS APIs.
- No SIP disablement.
- No administrator privileges.
- No Apple Launchpad database modification.
- No network transmission of app inventory or usage data.
- Local state is stored under `~/Library/Application Support/MacAppGrid/`.

## Release Security

Public builds should be distributed as Developer ID signed and notarized DMGs. Unsigned DMGs are for local testing only.

Tag releases are expected to fail if Developer ID signing or notarization credentials are missing. A public release should include both the DMG and a SHA256 checksum file.
