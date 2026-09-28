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
(cd dist && shasum -a 256 "${output:t}") > "$output.sha256"
print "Packaged $output"
