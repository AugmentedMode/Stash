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
mountpoint="$stage/mounted"
cleanup() {
  if [[ -d "$mountpoint" ]] && mount | grep -Fq " on $mountpoint "; then
    hdiutil detach "$mountpoint" || return
  fi
  rm -rf "$stage"
}
trap cleanup EXIT
payload="$stage/payload"
mkdir -p "$payload"
/usr/bin/ditto "$app" "$payload/Stash.app"
ln -s /Applications "$payload/Applications"
output="dist/Stash-${version}-${architecture}.dmg"
if PYTHONPATH="$PWD/.build/dmg-tools" python3 -c 'import ds_store, mac_alias' 2>/dev/null; then
  mkdir -p "$payload/.background"
  swift scripts/make-dmg-background.swift "$payload/.background/installer.png"
  hdiutil create -volname 'Install Stash' -srcfolder "$payload" -fs HFS+ -format UDRW "$stage/layout.dmg"
  mkdir -p "$mountpoint"
  hdiutil attach "$stage/layout.dmg" -readwrite -nobrowse -mountpoint "$mountpoint"
  # Create the background alias on the mounted image, so it refers to the
  # distributed volume instead of a temporary folder on the build Mac.
  PYTHONPATH="$PWD/.build/dmg-tools" python3 scripts/dmg-layout.py "$mountpoint"
  hdiutil detach "$mountpoint"
  hdiutil convert "$stage/layout.dmg" -format UDZO -imagekey zlib-level=9 -ov -o "$output"
else
  print 'Optional Finder layout helper missing; packaging standard folder layout.'
  hdiutil create -volname 'Install Stash' -srcfolder "$payload" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$output"
fi
if [[ -n "${STASH_SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$STASH_SIGN_IDENTITY" "$output"
fi
hdiutil verify "$output"
(cd dist && shasum -a 256 "${output:t}") > "$output.sha256"
print "Packaged $output"
