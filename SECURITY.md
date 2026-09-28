# Security

Stash handles clipboard content, which can contain sensitive information. The app
is local-only, but its history and prompts are plaintext files protected by your
macOS account and owner-only permissions. Password-manager exclusions and
clipboard markers do not detect every possible secret.

## Reporting a vulnerability

Please use [GitHub private vulnerability reporting](https://github.com/AugmentedMode/Stash/security/advisories/new)
for security issues. Include the affected commit, macOS version, reproduction
steps using synthetic content, and the expected and observed behavior.

Do not post real clipboard history, saved prompts, tokens, credentials, or
personal screenshots in public issues. If private reporting is unavailable,
open an issue asking for a private reporting channel without disclosing the vulnerability.

The project currently develops on `main`; there are no maintained older release
branches. Security fixes are made on `main`. Response times are not guaranteed.
