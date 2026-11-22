#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
build="${1:-$PWD/build}"
engines="${2:-}"
if [[ -n "$engines" ]]; then engines="$(cd "$engines" && pwd)"; fi
mkdir -p "$build"
build="$(cd "$build" && pwd)"
app="$build/ArtCraft Quick Look.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$build/cache"
python3 configure.py "$app"
cp "Resources/ArtCraftQuickLook.icns" "$app/Contents/Resources/ArtCraftQuickLook.icns"
cp LICENSE ARTWORK.md "$app/Contents/Resources/"
common=(Sources/Archive.swift Sources/DocumentImage.swift Sources/Drawing.swift Sources/Timeline.swift Sources/RenderXPC.swift)
for arch in arm64 x86_64; do
  flags=(-target "$arch-apple-macos13.0" -module-cache-path "$build/cache" -O)
  xcrun swiftc "${flags[@]}" Sources/Host.swift -o "$build/host-$arch"
  xcrun swiftc "${flags[@]}" "${common[@]}" Sources/HeadlessRenderer.swift Sources/RenderService.swift \
    -o "$build/CraftRender-$arch"
  for name in Preview Thumbnail; do
    xcrun swiftc "${flags[@]}" -application-extension -module-name "$name" \
      -Xlinker -e -Xlinker _NSExtensionMain "${common[@]}" "Sources/QuickLook$name.swift" -o "$build/$name-$arch"
  done
done
xcrun lipo -create "$build/host-arm64" "$build/host-x86_64" -output "$app/Contents/MacOS/ArtCraftQuickLook"
if [[ -n "$engines" ]]; then
  mkdir -p "$app/Contents/Resources/Notices" "$build/engine-binaries"
  for name in $(python3 scripts/prepare_renderers.py --list); do
    source="$engines/$name"
    target="$build/engine-binaries/$name-cli"
    cp "$source/$name-cli" "$target"
    ditto "$source/Notices" "$app/Contents/Resources/Notices/$name"
    codesign --force --sign - "$target"
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
codesign --force --sign - --entitlements "$build/Service.entitlements" "$service"
for name in Preview Thumbnail; do
  codesign --force --sign - --entitlements "$build/Extension.entitlements" "$app/Contents/PlugIns/$name.appex"
done
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
echo "$app"
