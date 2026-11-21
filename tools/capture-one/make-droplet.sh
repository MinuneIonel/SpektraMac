#!/bin/zsh
# Builds SpektraDroplet.app: the AppleScript droplet with spektra-cli and its resources inside.
#   tools/capture-one/make-droplet.sh [output folder]   (default: build/)
set -euo pipefail
cd "$(dirname "$0")/../.."
out="${1:-build}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

swift build -c release --package-path Engine --product spektra-cli
bin="$(swift build -c release --package-path Engine --show-bin-path)"

app="$out/SpektraDroplet.app"
rm -rf "$app"
mkdir -p "$out"
# -s: stay open, so photos Capture One sends while it works aren't lost (see the script).
osacompile -s -o "$app" tools/capture-one/SpektraDroplet.applescript
# The CLI finds its shaders and profiles in the resource bundle beside it (Bundle.module).
mkdir -p "$app/Contents/Resources/spektra"
cp "$bin/spektra-cli" "$app/Contents/Resources/spektra/"
cp -R "$bin/SpektraEngine_SpektraEngine.bundle" "$app/Contents/Resources/spektra/"
# Accept TIFF and PNG files dropped on it or sent by Open With.
plist="$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDocumentTypes:0:LSItemContentTypes:0 public.tiff" "$plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" \
                             -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string public.tiff" "$plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:1 string public.png" "$plist"
/usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes:0:CFBundleTypeExtensions" "$plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes:0:CFBundleTypeOSTypes" "$plist" 2>/dev/null || true
codesign --force --deep --sign - "$app"
echo "Built $app"
