# Release preparation

The current artifact is `dist/Stash-1.0-arm64.dmg`, for Apple silicon and macOS 14+. It is ad-hoc signed. It is a local preview build, not a notarized public release. No valid Developer ID signing identities were present when this artifact was built.

## Build locally

```sh
./scripts/build-app.sh release
.build/release/StashCoreChecks
# Optional, build-only Finder layout dependencies:
python3 -m pip install --target .build/dmg-tools ds-store==1.3.1 mac-alias==2.2.2
./scripts/package-dmg.sh
```

The app itself has no third-party runtime dependencies. The DMG contains only Stash.app, an Applications symlink, the getting-started guide, and Finder layout metadata. It never includes the user's Application Support directory, preferences, clipboard, test fixtures, or build tools. A SHA-256 checksum is written next to the DMG.

## Signed public distribution

An Apple Developer account and a **Developer ID Application** certificate with its private key must be available in the signing Mac's keychain. Use the certificate's exact identity for `STASH_SIGN_IDENTITY`. The build script then enables Hardened Runtime and secure timestamps.

```sh
export STASH_SIGN_IDENTITY='Developer ID Application: YOUR EXACT IDENTITY'
./scripts/build-app.sh release
.build/release/StashCoreChecks
./scripts/package-dmg.sh
```

Configure a notarytool keychain profile outside this repository, then submit the DMG. Do not put Apple credentials in source files or chat. Replace `YOUR_PROFILE` with the existing profile's name:

```sh
xcrun notarytool submit dist/Stash-1.0-arm64.dmg --keychain-profile YOUR_PROFILE --wait
# Continue only after the response says Accepted.
xcrun stapler staple dist/Stash-1.0-arm64.dmg
xcrun stapler validate dist/Stash-1.0-arm64.dmg
shasum -a 256 dist/Stash-1.0-arm64.dmg > dist/Stash-1.0-arm64.dmg.sha256
```

Test a downloaded copy on another Mac under normal Gatekeeper settings. Launch from Applications, grant optional Accessibility permission yourself, and verify a text paste into a disposable document. Test without network access after stapling. Never disable Gatekeeper to make the preview appear release-ready.

Apple's references: [Developer ID](https://developer.apple.com/developer-id/) and [notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Release gates still requiring an external setup

- Developer ID signing, notarization, and clean-Mac installation acceptance.
- Actual cross-app keystroke injection after user-granted Accessibility access.
- Intel and older macOS hardware testing; the current DMG is arm64 only.

Local signature integrity and a valid DMG checksum do not substitute for those checks.
