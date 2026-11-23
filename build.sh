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
if [[ -n "$engines" ]]; then python3 configure.py "$app"; else python3 configure.py "$app" --embedded-only; fi
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
common=(Sources/Archive.swift Sources/DocumentImage.swift Sources/Drawing.swift Sources/Timeline.swift Sources/RenderXPC.swift Sources/SVGResource.swift)
# Apple silicon only: one slice, no universal lipo. Intel was dropped in 0.5.0.
thin_arm64() {
  local f="$1" archs
  archs="$(xcrun lipo -archs "$f" 2>/dev/null)" || return 0
  if [[ "$archs" == *x86_64* && "$archs" == *arm64* ]]; then
    xcrun lipo -thin arm64 "$f" -output "$f.arm64"
    mv "$f.arm64" "$f"
  elif [[ "$archs" == *x86_64* ]]; then
    echo "No arm64 slice in $f ($archs)" >&2
    exit 1
  fi
}
flags=(-target "arm64-apple-macos13.0" -module-cache-path "$build/cache" -O)
xcrun swiftc "${flags[@]}" -parse-as-library ${updater[@]+"${updater[@]}"} Sources/Host.swift Sources/Intro.swift \
  -o "$app/Contents/MacOS/CraftLook"
xcrun swiftc "${flags[@]}" "${common[@]}" Sources/HeadlessRenderer.swift Sources/RenderService.swift \
  -o "$build/CraftRender"
for name in Preview Thumbnail; do
  xcrun swiftc "${flags[@]}" -application-extension -module-name "$name" \
    -Xlinker -e -Xlinker _NSExtensionMain "${common[@]}" "Sources/QuickLook$name.swift" -o "$build/$name"
done
if [[ -n "$engines" ]]; then
  mkdir -p "$app/Contents/Resources/Notices" "$build/engine-binaries"
  for name in $(python3 scripts/prepare_renderers.py --list); do
    source="$engines/$name"
    target="$build/engine-binaries/$name-cli"
    cp "$source/$name-cli" "$target"
    thin_arm64 "$target"
    ditto "$source/Notices" "$app/Contents/Resources/Notices/$name"
    # Each renderer keeps the entitlements of its upstream signature: only SolidCraft has one,
    # allow-unsigned-executable-memory, for the WebAssembly code its wasmtime compiles.
    "${sign[@]}" --preserve-metadata=entitlements "$target"
  done
fi
if [[ -n "$engines" ]]; then
  mkdir -p "$app/Contents/Helpers"
  mv "$build"/engine-binaries/*-cli "$app/Contents/Helpers/"
fi
for name in Preview Thumbnail; do
  ext="$app/Contents/PlugIns/$name.appex"
  mkdir -p "$ext/Contents/MacOS"
  cp "$build/$name" "$ext/Contents/MacOS/$name"
  # The same thin service in each extension. The CLIs live once in Contents/Helpers; a hard link
  # in the service lets the sandbox run them without a second copy on disk.
  service="$ext/Contents/XPCServices/CraftRender.xpc"
  mkdir -p "$service/Contents/MacOS"
  cp "$build/CraftRender" "$service/Contents/MacOS/CraftRender"
  if [[ -n "$engines" ]]; then
    mkdir -p "$service/Contents/Helpers"
    ln "$app/Contents/Helpers/"*-cli "$service/Contents/Helpers/"
  fi
  "${sign[@]}" --entitlements "$build/Service.entitlements" "$service"
done
for name in Preview Thumbnail; do
  "${sign[@]}" --entitlements "$build/Extension.entitlements" "$app/Contents/PlugIns/$name.appex"
done
if (( ${#updater[@]} )); then
  # The app is not sandboxed, so Sparkle's XPC services stay out; its helpers are signed inside out.
  framework="$app/Contents/Frameworks/Sparkle.framework"
  mkdir -p "$app/Contents/Frameworks" "$app/Contents/Resources/Notices/sparkle"
  ditto "$engines/sparkle/Sparkle.framework" "$framework"
  rm -rf "$framework/XPCServices" "$framework/Versions/B/XPCServices"
  # The official Sparkle archive is universal; keep only arm64 in the app.
  while IFS= read -r -d '' f; do thin_arm64 "$f"; done < <(find "$framework" -type f -print0)
  cp "$engines/sparkle/LICENSE" "$app/Contents/Resources/Notices/sparkle/"
  "${sign[@]}" "$framework/Versions/B/Autoupdate"
  "${sign[@]}" "$framework/Versions/B/Updater.app"
  "${sign[@]}" "$framework"
fi
"${sign[@]}" "$app"
# Nothing x86_64 may remain in the build: Intel was dropped in 0.5.0.
while IFS= read -r -d '' f; do
  archs="$(xcrun lipo -archs "$f" 2>/dev/null)" || continue
  if [[ "$archs" == *x86_64* ]]; then
    echo "x86_64 remains in $f ($archs)" >&2
    exit 1
  fi
done < <(find "$app" -type f -print0)
codesign --verify --deep --strict "$app"
echo "$app"
