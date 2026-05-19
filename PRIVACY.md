# Privacy

MacAppGrid stores app layout, folder configuration, hidden app IDs, usage counts, hotkey settings, and cached app metadata locally under:

```txt
~/Library/Application Support/MacAppGrid/
```

MacAppGrid does not transmit app inventory, layout data, folder data, usage data, or diagnostics over the network.

App inventory can reveal what applications are installed on your Mac. Treat exported diagnostics and support files as potentially sensitive.

Diagnostics copied from Settings include:

- MacAppGrid version
- Application Support path
- configured hotkey label
- hidden app count
- launch-at-login setting
- folder visibility mode

MacAppGrid does not request administrator privileges, does not require SIP changes, does not modify Apple Launchpad databases, and does not use private macOS APIs.
