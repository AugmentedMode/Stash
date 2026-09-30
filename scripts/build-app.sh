#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
configuration="${1:-release}"
[[ "$configuration" == release || "$configuration" == debug ]] || { print -u2 "Use debug or release."; exit 1; }
swift build --disable-sandbox --cache-path "$PWD/.build/package-cache" -c "$configuration"
bin_dir="$(swift build --disable-sandbox --cache-path "$PWD/.build/package-cache" -c "$configuration" --show-bin-path)"
app="${STASH_APP_OUTPUT:-dist/Stash.app}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp "$bin_dir/Stash" "$app/Contents/MacOS/Stash"
# Sparkle (update checks) ships inside the app; the binary finds it through this rpath.
rm -rf "$app/Contents/Frameworks/Sparkle.framework"
/usr/bin/ditto "$bin_dir/Sparkle.framework" "$app/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$app/Contents/MacOS/Stash"
cp LICENSE "$app/Contents/Resources/LICENSE.txt"
cp THIRD_PARTY_NOTICES.md "$app/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp .build/artifacts/sparkle/Sparkle/LICENSE "$app/Contents/Resources/Sparkle-LICENSE.txt"
# Bundle the native vector artwork for standalone installed apps.
/usr/bin/ditto Sources/Stash/Resources/CategoryArt "$app/Contents/Resources/CategoryArt"
/usr/bin/ditto Sources/Stash/Resources/ServiceIcons "$app/Contents/Resources/ServiceIcons"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Stash</string>
<key>CFBundleDisplayName</key><string>Stash</string>
<key>CFBundleIdentifier</key><string>app.stash.clipboard</string>
<key>CFBundleExecutable</key><string>Stash</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.5</string>
<key>CFBundleVersion</key><string>15</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>Stash</string>
<key>SUFeedURL</key><string>https://github.com/AugmentedMode/Stash/releases/latest/download/appcast.xml</string>
<key>SUPublicEDKey</key><string>fdV3JFaB8mjJQo3Zjw6iHOFcZNNkiTExe5HJ1cBqej8=</string>
<key>SUEnableAutomaticChecks</key><true/>
<key>SUScheduledCheckInterval</key><integer>86400</integer>
<key>SUEnableSystemProfiling</key><false/>
<key>NSHumanReadableCopyright</key><string>Stash — a local clipboard companion.</string>
</dict></plist>
PLIST
if [[ "$app" == *"Stash QA.app" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier app.stash.qa" "$app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName Stash QA" "$app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Stash QA" "$app/Contents/Info.plist"
fi
# Only real release apps check for updates; QA and preview builds never replace themselves.
if [[ "$app" == *"Stash QA.app" || "$configuration" == "debug" ]]; then
  /usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$app/Contents/Info.plist"
fi
if [[ "$configuration" == "debug" ]]; then
  /usr/libexec/PlistBuddy -c "Add :StashPreview bool true" "$app/Contents/Info.plist"
fi
swift scripts/make-icon.swift
iconutil -c icns dist/Stash.iconset -o "$app/Contents/Resources/Stash.icns"
if [[ -n "${STASH_SIGN_IDENTITY:-}" ]]; then
  sign=(codesign --force --options runtime --timestamp --sign "$STASH_SIGN_IDENTITY")
else
  sign=(codesign --force --sign -)
fi
# Sign Sparkle's helpers inside-out, as Sparkle documents, then the app itself.
sparkle="$app/Contents/Frameworks/Sparkle.framework/Versions/B"
"${sign[@]}" "$sparkle/XPCServices/Installer.xpc"
"${sign[@]}" --preserve-metadata=entitlements "$sparkle/XPCServices/Downloader.xpc"
"${sign[@]}" "$sparkle/Autoupdate"
"${sign[@]}" "$sparkle/Updater.app"
"${sign[@]}" "$app/Contents/Frameworks/Sparkle.framework"
"${sign[@]}" "$app"
codesign --verify --deep --strict "$app"
echo "Built $app"
