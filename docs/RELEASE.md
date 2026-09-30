# Release preparation

Official downloads from version 1.0.2 onward are Developer ID signed and notarized
by Apple. Releases support Apple silicon and macOS 14+. The Homebrew tap installs
the same DMG published on GitHub Releases. Local builds default to ad-hoc signing.

## Build and notarize

Use a valid Developer ID Application certificate with its private key in the
signing Mac's Keychain. Configure a notarytool Keychain profile locally; never
commit credentials, certificates with private keys, or passwords.

1. Update the version and build number in `scripts/build-app.sh`.
2. Run `./scripts/format.sh --check` and `./scripts/check.sh`.
3. Sign and submit the app. Set the identity and profile below to your local values.

```sh
export STASH_SIGN_IDENTITY='Developer ID Application: YOUR EXACT IDENTITY'
./scripts/build-app.sh release
ditto -c -k --keepParent dist/Stash.app dist/Stash-notarization.zip
xcrun notarytool submit dist/Stash-notarization.zip --keychain-profile YOUR_PROFILE --wait
```

Continue only after **Accepted**. Retrieve the submission log with `notarytool log`
and review any issues. Staple the app before packaging so the installed app carries
its approval ticket even when separated from the DMG.

```sh
xcrun stapler staple dist/Stash.app
xcrun stapler validate dist/Stash.app
spctl --assess --type execute --verbose=2 dist/Stash.app
./scripts/package-dmg.sh
```

Submit the versioned DMG produced by the packaging script. The following example
uses version 1.0.2; change its filename for later releases.

```sh
xcrun notarytool submit dist/Stash-1.0.2-arm64.dmg --keychain-profile YOUR_PROFILE --wait
# Continue only after Accepted; review the submission log.
xcrun stapler staple dist/Stash-1.0.2-arm64.dmg
xcrun stapler validate dist/Stash-1.0.2-arm64.dmg
spctl --assess --type open --context context:primary-signature --verbose=2 dist/Stash-1.0.2-arm64.dmg
(cd dist && shasum -a 256 Stash-1.0.2-arm64.dmg > Stash-1.0.2-arm64.dmg.sha256)
```

Stapling changes the DMG bytes: regenerate the checksum **after** stapling.

## Update feed

Installed apps read `releases/latest/download/appcast.xml`, so every release must
include an `appcast.xml` asset. Create it **after** stapling the DMG, because the
feed carries the DMG's EdDSA signature and length:

```sh
./scripts/make-appcast.sh
```

The signing key is in the maintainer's login Keychain (Sparkle account `stash`); its
public half is `SUPublicEDKey` in `scripts/build-app.sh`. Keep an offline backup
(`generate_keys --account stash -x <file>`). Without it, installed apps cannot
accept new updates. Raise `CFBundleVersion` for every release: Sparkle compares it.
Mount the final DMG read-only and verify the enclosed app's signature and ticket.

## Publish and verify

Commit the exact source, tag its version, and publish the DMG, checksum and `appcast.xml` on
GitHub Releases with a link to that tag's source. Never replace an existing
version's binary; publish a new version so source, tag, and checksum agree.
Update `version` and `sha256` in `Casks/stash.rb` in
[the Homebrew tap](https://github.com/AugmentedMode/homebrew-stash) after the asset
is available. Remove obsolete unsigned-app caveats for signed releases.

Run **Public download smoke test** on GitHub Actions. Fresh macOS 14, 15, and 26
runners install the public Homebrew cask, require Gatekeeper acceptance and a valid
stapled ticket, check normal and sample-data process startup, and uninstall.
These tests do not replace interactive Accessibility consent and cross-app paste
testing. Intel hardware is not tested and no Intel binary is distributed.

## Local builds

```sh
./scripts/build-app.sh release
./scripts/package-dmg.sh
```

Without `STASH_SIGN_IDENTITY`, these builds are ad-hoc signed and not notarized.
The optional DMG Finder-layout helper uses `ds-store==1.3.1` and
`mac-alias==2.2.2` installed under `.build/dmg-tools`. The app's only third-party
runtime dependency is Sparkle, pinned in `Package.swift` and embedded in
`Contents/Frameworks`. Packaging includes only the app, Applications symlink,
hidden installer background and Finder layout metadata; never clipboard history or
Application Support data.

## Source and licensing

Original source is GPL-3.0-only. Distribute `LICENSE` and `THIRD_PARTY_NOTICES.md`
inside the app and provide corresponding source and build scripts for each
binary release. Service-icon redistribution permission was confirmed by the
maintainer; retain notices and the asset inventory. The marketing website is a
separate repository and must not be bundled with the app.

References: [Developer ID](https://developer.apple.com/developer-id/) and
[Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
