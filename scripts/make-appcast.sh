#!/bin/zsh
# Writes dist/appcast.xml for the DMG built from dist/Stash.app, signed with the Sparkle
# EdDSA key in this Mac's Keychain (account "stash"). Upload it to the GitHub release
# next to the DMG; installed apps read releases/latest/download/appcast.xml.
set -euo pipefail
cd "${0:A:h:h}"
app="${STASH_APP_OUTPUT:-dist/Stash.app}"
plist="$app/Contents/Info.plist"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")
minimum=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")
dmg="${1:-dist/Stash-${version}-arm64.dmg}"
[[ -f "$dmg" ]] || { print -u2 "Missing $dmg. Package and staple it first."; exit 1; }
base="${STASH_DOWNLOAD_BASE:-https://github.com/AugmentedMode/Stash/releases/download/v$version}"
notes="${STASH_RELEASE_NOTES_URL:-https://github.com/AugmentedMode/Stash/releases/tag/v$version}"
tool=".build/artifacts/sparkle/Sparkle/bin/sign_update"
[[ -x "$tool" ]] || swift package resolve >/dev/null
# Prints: sparkle:edSignature="..." length="..."
signature=$("$tool" --account stash "$dmg")
cat > "${STASH_APPCAST_OUTPUT:-dist/appcast.xml}" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Stash</title>
    <item>
      <title>Stash $version</title>
      <pubDate>$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')</pubDate>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$minimum</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>$notes</sparkle:releaseNotesLink>
      <enclosure url="$base/${dmg:t}" type="application/octet-stream" $signature/>
    </item>
  </channel>
</rss>
XML
echo "Wrote ${STASH_APPCAST_OUTPUT:-dist/appcast.xml} for Stash $version ($build)"
