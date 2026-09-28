#!/bin/zsh
# Uses only the Swift toolchain; integration checks use isolated named pasteboards.
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
swift build --disable-sandbox --cache-path "$PWD/.build/package-cache"
swift run --disable-sandbox --cache-path "$PWD/.build/package-cache" StashCoreChecks
