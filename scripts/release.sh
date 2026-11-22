#!/bin/bash
# Builds, signs, notarizes, staples and packages a CraftLook release:
#   CRAFTLOOK_SIGN_ID="Developer ID Application: NAME (TEAM)" scripts/release.sh OUT_DIR ENGINES_DIR
# The notary credentials come from the keychain profile in CRAFTLOOK_NOTARY_PROFILE (craftlook-notary
# by default), saved once with `xcrun notarytool store-credentials`.
set -euo pipefail
cd "$(dirname "$0")/.."
repo="$PWD"
: "${CRAFTLOOK_SIGN_ID:?CRAFTLOOK_SIGN_ID must name a Developer ID Application identity}"
profile="${CRAFTLOOK_NOTARY_PROFILE:-craftlook-notary}"
mkdir -p "$1"
out="$(cd "$1" && pwd)"
engines="$2"
[[ -z "$(git status --porcelain)" ]] || { echo "The work tree has uncommitted changes" >&2; exit 1; }
app="$(./build.sh "$out" "$engines" | tail -n 1)"
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")"
name="craftlook-$version"
upload="$out/$name-notarize.zip"
ditto -c -k --keepParent "$app" "$upload"
xcrun notarytool submit "$upload" --keychain-profile "$profile" --wait --output-format json | tee "$out/notary.json"
rm "$upload"
status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$out/notary.json")"
if [[ "$status" != "Accepted" ]]; then
  id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$out/notary.json")"
  xcrun notarytool log "$id" --keychain-profile "$profile"
  echo "Notarization: $status" >&2
  exit 1
fi
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute -vvv "$app"
cd "$out"
rm -f "$name-macos.zip" "$name-source.zip"
ditto -c -k --keepParent "$(basename "$app")" "$name-macos.zip"
git -C "$repo" archive --format=zip --prefix="$name/" -o "$out/$name-source.zip" HEAD
shasum -a 256 "$name-macos.zip" "$name-source.zip" > "$name-SHA256.txt"
cat "$name-SHA256.txt"
