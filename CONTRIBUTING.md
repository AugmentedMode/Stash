# Contributing to Stash

Stash is a native macOS clipboard utility written in SwiftUI and AppKit. The app
has no third-party runtime dependencies. Start with [the architecture](docs/ARCHITECTURE.md)
and [manual acceptance checks](TESTING.md).

## Local setup

Use an Apple Swift toolchain with the macOS 26 SDK (Xcode 26 or matching Command
Line Tools). The deployment target remains macOS 14; the SDK is needed to compile
the availability-guarded Liquid Glass implementation. Formatting uses `swift format`.

```sh
./scripts/check.sh
./scripts/format.sh --check
STASH_APP_OUTPUT='dist/Stash QA.app' ./scripts/build-app.sh debug
open 'dist/Stash QA.app'
```

The QA bundle uses sample data, separate preferences, no collection, and no global
hotkey. Copy buttons still write to the clipboard. Tests use named pasteboards and
temporary directories and do not access your real clipboard or saved history.
Run them in a macOS login session with pasteboard access. `swift test` is not the
test entry point: `StashCoreChecks` is an executable so Command Line Tools users
can run it without XCTest.

## Making a change

Keep a change focused on a concrete problem. Put data rules in `StashCore`, UI in
the relevant feature folder, and system lifecycle code in `Application`. Avoid
adding network access to capture, search, or preview paths. Preserve the original
clipboard representations and backwards compatibility with existing JSON files.

Add a regression check for behavior changes, register it in `CoreChecks.swift`,
and run `./scripts/check.sh`. Run `./scripts/format.sh` to format edits, then
`./scripts/format.sh --check`. Capture, paste, keyboard, and focus changes also
need the relevant manual flows in `TESTING.md`; passing core checks does not
establish cross-app UI behavior.

Describe the trigger, resulting behavior, and verification in your pull request.
Use synthetic clipboard content in screenshots, fixtures, and logs. Never attach
your real `history.json` or `prompts.json` to an issue.

## Assets and releases

SVG category masters are in `Assets/CategoryArt`; the application bundles the
matching PDFs. Service icon provenance is in `Assets/ServiceIcons/README.md` and
`THIRD_PARTY_NOTICES.md`. Keep provenance with any asset changes.

The marketing website is maintained in a separate repository. Do not add a nested
website checkout, hosting credentials, or workspace preview images to app commits.

Contributions to the Stash application source are under GPL-3.0-only, the same
license as the project. Public binary releases require the source and asset
checks in [release preparation](docs/RELEASE.md).
