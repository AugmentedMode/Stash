#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
configuration="${1:-release}"
swift build --disable-sandbox --cache-path "$PWD/.build/package-cache" -c "$configuration"
bin_dir="$(swift build --disable-sandbox --cache-path "$PWD/.build/package-cache" -c "$configuration" --show-bin-path)"
app="${STASH_APP_OUTPUT:-dist/Stash.app}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/Stash" "$app/Contents/MacOS/Stash"
# Bundle the native vector artwork for standalone installed apps.
/usr/bin/ditto Sources/Stash/Resources/CategoryArt "$app/Contents/Resources/CategoryArt"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Stash</string>
<key>CFBundleDisplayName</key><string>Stash</string>
<key>CFBundleIdentifier</key><string>app.stash.clipboard</string>
<key>CFBundleExecutable</key><string>Stash</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>7</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>Stash</string>
<key>NSHumanReadableCopyright</key><string>Stash — a local clipboard companion.</string>
</dict></plist>
PLIST
if [[ "$app" == *"Stash QA.app" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier app.stash.qa" "$app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName Stash QA" "$app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Stash QA" "$app/Contents/Info.plist"
fi
if [[ "$configuration" == "debug" ]]; then
  /usr/libexec/PlistBuddy -c "Add :StashPreview bool true" "$app/Contents/Info.plist"
fi
swift scripts/make-icon.swift
iconutil -c icns dist/Stash.iconset -o "$app/Contents/Resources/Stash.icns"
if [[ -n "${STASH_SIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$STASH_SIGN_IDENTITY" "$app"
else
  codesign --force --sign - "$app"
fi
codesign --verify --deep --strict "$app"
echo "Built $app"
