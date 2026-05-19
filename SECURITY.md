# Security

## Supported Versions

Security fixes target the latest `main` branch until the first tagged beta release is published.

## Reporting

Open a GitHub issue with a clear reproduction path. Do not include sensitive app inventory, local paths, or private logs unless they are required and redacted.

## Security Boundaries

- No private macOS APIs.
- No SIP disablement.
- No administrator privileges.
- No Apple Launchpad database modification.
- No network transmission of app inventory or usage data.
- Local state is stored under `~/Library/Application Support/MacAppGrid/`.

## Release Security

Public builds should be distributed as Developer ID signed and notarized DMGs. Unsigned DMGs are for local testing only.
