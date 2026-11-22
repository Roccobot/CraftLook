#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
build="${1:-$PWD/build}"
engines="${2:-}"
if [[ -n "$engines" ]]; then engines="$(cd "$engines" && pwd)"; fi
mkdir -p "$build"
build="$(cd "$build" && pwd)"
# Signing: a Developer ID Application identity in CRAFTLOOK_SIGN_ID, for notarization, or ad hoc.
# Every piece gets the hardened runtime, inside out; a real identity also gets a secure timestamp.
identity="${CRAFTLOOK_SIGN_ID:--}"
sign=(codesign --force --options runtime --sign "$identity")
if [[ "$identity" == "-" ]]; then sign+=(--timestamp=none); else sign+=(--timestamp); fi
app="$build/CraftLook.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$build/cache"
python3 configure.py "$app"
cp "Resources/CraftLook.icns" "$app/Contents/Resources/CraftLook.icns"
# The marks of the window (Sources/Intro.swift), as vector PDFs (scripts/icons.py).
cp Resources/tian.pdf Resources/github.pdf Resources/telegram.pdf "$app/Contents/Resources/"
cp LICENSE ARTWORK.md "$app/Contents/Resources/"
# Sparkle, prepared beside the renderers: the app links it from Contents/Frameworks. Without it the
# app is built without updates (Sources/Host.swift and Sources/Intro.swift, canImport(Sparkle)).
updater=()
if [[ -n "$engines" && -d "$engines/sparkle/Sparkle.framework" ]]; then
  updater=(-F "$engines/sparkle" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks)
fi
common=(Sources/Archive.swift Sources/DocumentImage.swift Sources/Drawing.swift Sources/Timeline.swift Sources/RenderXPC.swift)
for arch in arm64 x86_64; do
  flags=(-target "$arch-apple-macos13.0" -module-cache-path "$build/cache" -O)
  xcrun swiftc "${flags[@]}" -parse-as-library ${updater[@]+"${updater[@]}"} Sources/Host.swift Sources/Intro.swift \
    -o "$build/host-$arch"
  xcrun swiftc "${flags[@]}" "${common[@]}" Sources/HeadlessRenderer.swift Sources/RenderService.swift \
    -o "$build/CraftRender-$arch"
  for name in Preview Thumbnail; do
    xcrun swiftc "${flags[@]}" -application-extension -module-name "$name" \
      -Xlinker -e -Xlinker _NSExtensionMain "${common[@]}" "Sources/QuickLook$name.swift" -o "$build/$name-$arch"
  done
done
xcrun lipo -create "$build/host-arm64" "$build/host-x86_64" -output "$app/Contents/MacOS/CraftLook"
if [[ -n "$engines" ]]; then
  mkdir -p "$app/Contents/Resources/Notices" "$build/engine-binaries"
  for name in $(python3 scripts/prepare_renderers.py --list); do
    source="$engines/$name"
    target="$build/engine-binaries/$name-cli"
    cp "$source/$name-cli" "$target"
    ditto "$source/Notices" "$app/Contents/Resources/Notices/$name"
    # Each renderer keeps the entitlements of its upstream signature: only SolidCraft has one,
    # allow-unsigned-executable-memory, for the WebAssembly code its wasmtime compiles.
    "${sign[@]}" --preserve-metadata=entitlements "$target"
  done
fi
for name in Preview Thumbnail; do
  ext="$app/Contents/PlugIns/$name.appex"
  mkdir -p "$ext/Contents/MacOS"
  xcrun lipo -create "$build/$name-arm64" "$build/$name-x86_64" -output "$ext/Contents/MacOS/$name"
done
service="$app/Contents/PlugIns/Thumbnail.appex/Contents/XPCServices/CraftRender.xpc"
mkdir -p "$service/Contents/MacOS"
xcrun lipo -create "$build/CraftRender-arm64" "$build/CraftRender-x86_64" -output "$service/Contents/MacOS/CraftRender"
if [[ -n "$engines" ]]; then
  mkdir -p "$service/Contents/Helpers"
  mv "$build"/engine-binaries/*-cli "$service/Contents/Helpers/"
fi
"${sign[@]}" --entitlements "$build/Service.entitlements" "$service"
for name in Preview Thumbnail; do
  "${sign[@]}" --entitlements "$build/Extension.entitlements" "$app/Contents/PlugIns/$name.appex"
done
if (( ${#updater[@]} )); then
  # The app is not sandboxed, so Sparkle's XPC services stay out; its helpers are signed inside out.
  framework="$app/Contents/Frameworks/Sparkle.framework"
  mkdir -p "$app/Contents/Frameworks" "$app/Contents/Resources/Notices/sparkle"
  ditto "$engines/sparkle/Sparkle.framework" "$framework"
  rm -rf "$framework/XPCServices" "$framework/Versions/B/XPCServices"
  cp "$engines/sparkle/LICENSE" "$app/Contents/Resources/Notices/sparkle/"
  "${sign[@]}" "$framework/Versions/B/Autoupdate"
  "${sign[@]}" "$framework/Versions/B/Updater.app"
  "${sign[@]}" "$framework"
fi
"${sign[@]}" "$app"
codesign --verify --deep --strict "$app"
echo "$app"
