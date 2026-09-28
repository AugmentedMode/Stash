#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
app="${STASH_APP_OUTPUT:-dist/Stash.app}"
[[ -d "$app" ]] || { print -u2 'Build Stash.app first.'; exit 1; }
# Only release apps belong in an installer.
if /usr/libexec/PlistBuddy -c 'Print :StashPreview' "$app/Contents/Info.plist" 2>/dev/null | /usr/bin/grep -q true; then
  print -u2 'Refusing to package a preview app.'; exit 1
fi
codesign --verify --deep --strict "$app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
archs=$(lipo -archs "$app/Contents/MacOS/Stash")
architecture="${archs// /-}"
mkdir -p dist
stage=$(mktemp -d "$PWD/dist/.dmg-stage.XXXXXX")
trap 'rm -rf "$stage"' EXIT
/usr/bin/ditto "$app" "$stage/Stash.app"
ln -s /Applications "$stage/Applications"
cp docs/Start-here.txt "$stage/Start here.txt"
if [[ -z "${STASH_SIGN_IDENTITY:-}" ]]; then
  cat >> "$stage/Start here.txt" <<'NOTE'

PREVIEW DISTRIBUTION
This build is ad-hoc signed, not Developer ID signed or notarized. macOS may
block an app received through a download or sharing service. For a normal
installation experience, request the signed and notarized release. Do not
disable Gatekeeper or other security protections to install this preview.
NOTE
fi
if PYTHONPATH="$PWD/.build/dmg-tools" python3 -c 'import ds_store' 2>/dev/null; then
  PYTHONPATH="$PWD/.build/dmg-tools" python3 scripts/dmg-layout.py "$stage"
else
  print 'Optional Finder layout helper missing; packaging standard folder layout.'
fi
output="dist/Stash-${version}-${architecture}.dmg"
hdiutil create -volname 'Stash — Drag to Applications' -srcfolder "$stage" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$output"
if [[ -n "${STASH_SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$STASH_SIGN_IDENTITY" "$output"
fi
hdiutil verify "$output"
shasum -a 256 "$output" > "$output.sha256"
print "Packaged $output"
