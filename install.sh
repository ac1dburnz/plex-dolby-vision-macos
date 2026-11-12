#!/bin/bash
set -euo pipefail
# Builds an experimental Plex copy; the original bundle is never modified.
if [[ ${EUID} -eq 0 ]]; then echo 'Run this as your normal macOS user, not root.' >&2; exit 1; fi
if [[ $(uname -s) != Darwin || $(uname -m) != arm64 ]]; then echo 'This experimental patch currently supports Apple Silicon Macs only.' >&2; exit 1; fi
source_app=${1:-/Applications/Plex.app}
target_app=${2:-"$HOME/Applications/Plex DV.app"}
if [[ ! -x "$source_app/Contents/MacOS/Plex" ]]; then echo "Plex app not found: $source_app" >&2; exit 1; fi
if [[ -e "$target_app" ]]; then echo "Destination already exists: $target_app (choose another path; nothing was overwritten)" >&2; exit 1; fi
for cmd in git brew meson ninja pkg-config xcrun codesign ditto python3; do command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2; exit 1; }; done
for dep in libavcodec libavfilter libavformat libavutil libswresample libswscale libplacebo libass vulkan; do pkg-config --exists "$dep" || { echo "Missing build dependency: $dep. See README.md." >&2; exit 1; }; done
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/plex-dv-build.XXXXXX")
staged_app="$(dirname "$target_app")/.plex-dv-stage-$$.app"
cleanup() { rm -rf "$build_dir" "$staged_app"; }
trap cleanup EXIT
mkdir -p "$(dirname "$target_app")"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$source_app/Contents/Info.plist")
echo "Building experimental Plex DV from Plex $version (tested with 1.109.0)."
git init -q "$build_dir/mpv"
git -C "$build_dir/mpv" fetch -q --depth 1 https://github.com/posilash/mpv.git 2297e443d8e104ee3e1f4dac61431969dca0eb40
git -C "$build_dir/mpv" checkout -q --detach FETCH_HEAD
git -C "$build_dir/mpv" apply "$repo_dir/src/plex-opengl.patch"
meson setup "$build_dir/mpv/build" "$build_dir/mpv" -Dlibmpv=true -Dbuild-date=false -Djavascript=disabled -Dlua=disabled -Dvulkan=enabled -Dgl=enabled
ninja -C "$build_dir/mpv/build" libmpv.2.dylib
xcrun clang -dynamiclib -Wno-deprecated-declarations -framework OpenGL "$repo_dir/src/force-gl.c" -o "$build_dir/force-gl.dylib"
codesign --force --sign - "$build_dir/force-gl.dylib"
ditto "$source_app" "$staged_app"
cp "$build_dir/mpv/build/libmpv.2.dylib" "$staged_app/Contents/Frameworks/libmpv.2.dylib"
cp "$build_dir/force-gl.dylib" "$staged_app/Contents/Frameworks/force-gl.dylib"
codesign --force --sign - "$staged_app/Contents/Frameworks/libmpv.2.dylib"
mv "$staged_app/Contents/MacOS/Plex" "$staged_app/Contents/MacOS/Plex-real"
cat > "$staged_app/Contents/MacOS/Plex" <<'LAUNCHER'
#!/bin/sh
app_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export DYLD_INSERT_LIBRARIES="$app_dir/Frameworks/force-gl.dylib"
exec "$app_dir/MacOS/Plex-real" "$@"
LAUNCHER
chmod 755 "$staged_app/Contents/MacOS/Plex"
codesign -d --entitlements :- "$source_app" > "$build_dir/entitlements.plist" 2>/dev/null
/usr/libexec/PlistBuddy -c 'Add :com.apple.security.cs.allow-dyld-environment-variables bool true' "$build_dir/entitlements.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c 'Set :com.apple.security.cs.allow-dyld-environment-variables true' "$build_dir/entitlements.plist"
codesign --force --sign - --options runtime --entitlements "$build_dir/entitlements.plist" "$staged_app/Contents/MacOS/Plex-real"
codesign --force --sign - --options runtime --entitlements "$build_dir/entitlements.plist" "$staged_app"
codesign --verify --deep --strict "$staged_app"
xattr -dr com.apple.quarantine "$staged_app" 2>/dev/null || true
mv "$staged_app" "$target_app"
echo "Installed: $target_app"
echo 'Quit other Plex windows, then open the new app and test a video.'
