# Release preparation

Public downloads are ad-hoc signed, without Developer ID signing or notarization.
The first release is `v1.0` (`CFBundleVersion` 10), for Apple silicon and macOS 14+.
The DMG and matching checksum are published on [GitHub Releases](https://github.com/AugmentedMode/Stash/releases).
The [Homebrew tap](https://github.com/AugmentedMode/homebrew-stash) installs the same DMG.

## Publish an ad-hoc signed release

1. Run formatting and `./scripts/check.sh`; confirm the source tree contains only
   intended release changes. Update the version and build number in
   `scripts/build-app.sh` for subsequent releases.
2. With `STASH_SIGN_IDENTITY` unset, build and package using the commands below.
3. Verify the DMG and app signature, mount the image, and inspect its contents.
   Test an extracted copy's signature before uploading.
4. Commit the source and create a version tag on that exact commit. Publish the
   DMG and its `.sha256` file in a GitHub Release for that tag. Link the tag's
   corresponding source and explain the architecture and first-launch steps.
5. Update `version` and `sha256` in the tap's `Casks/stash.rb`. Validate it with
   `brew style` and `brew audit --cask`, then test fetching and installation.
   Publish the tap update only after the release asset is available.
6. Never replace an existing version's binary: issue a new version so the
   checksum, tag, and downloadable source remain consistent.

Homebrew preserves macOS quarantine. Users can follow Apple's per-app
[Open Anyway instructions](https://support.apple.com/102445). Quick-paste
Accessibility permission may need to be re-enabled after an update.

## Build locally

```sh
./scripts/build-app.sh release
.build/release/StashCoreChecks
# Optional, build-only Finder layout dependencies:
python3 -m pip install --target .build/dmg-tools ds-store==1.3.1 mac-alias==2.2.2
./scripts/package-dmg.sh
```

The app itself has no third-party runtime dependencies. The DMG contains only Stash.app, an Applications symlink, the getting-started guide, and Finder layout metadata. It never includes the user's Application Support directory, preferences, clipboard, test fixtures, or build tools. A SHA-256 checksum is written next to the DMG.

## Optional Developer ID distribution

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

- Clean-Mac installation acceptance. Developer ID signing and notarization are optional future improvements.
- Actual cross-app keystroke injection after user-granted Accessibility access.
- Intel and older macOS hardware testing; the current DMG is arm64 only.

Local signature integrity and a valid DMG checksum do not substitute for those checks.

## Source publication

The original application source is GPL-3.0-only. Include `LICENSE` and
`THIRD_PARTY_NOTICES.md` with distributions. For a binary release, make the
corresponding source and build scripts for that exact version available and link
them from the release. Clearly label ad-hoc signing and the lack of notarization in release notes.

Service-icon redistribution permission was confirmed by the maintainer; retain
`THIRD_PARTY_NOTICES.md` and the asset inventory. Before each publication, review
the actual staged files and Git history for personal content and credentials.
The marketing website is a separate repository and must not be bundled with the app.

CI runs formatting, isolated integration checks, and a release bundle build on
GitHub's [macOS 26 runner](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
The workflow uses [checkout v7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1).
Public source is maintained on `main`. Check the Checks workflow before publishing binaries.
