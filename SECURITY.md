# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest release | ✅ Yes |
| Older releases | ❌ No — please update |

Win Finder is under active development. Security fixes are applied to the latest release only.

## Reporting a Vulnerability

If you discover a security vulnerability in Win Finder, **please do not open a public issue.**

Instead, report it privately by:
1. Going to the [Security tab](https://github.com/Skimmenthal13/winfinder/security) of this repository
2. Clicking **"Report a vulnerability"**

Please include:
- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Your suggested fix (optional but appreciated)

You can expect an acknowledgment within 7 days and a resolution or status update within 30 days.

## Scope

Security issues we care about:
- Arbitrary code execution triggered by opening a folder or file
- Extension system abuse (malicious `action.json` executing unintended commands)
- Privilege escalation
- Data exfiltration (Win Finder should never send data anywhere)

## Privacy

Win Finder collects no data and has no network component. If you observe the app making unexpected network connections, that is a serious bug — please report it immediately.

See the full [Privacy Policy](https://skimmenthal13.github.io/winfinder/privacy-policy.html) and [Terms of Service](https://skimmenthal13.github.io/winfinder/terms-of-service.html).
