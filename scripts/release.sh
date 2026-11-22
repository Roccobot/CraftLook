#!/bin/bash
# Builds, signs, notarizes, staples and packages a CraftLook release, with its Sparkle appcast:
#   [CRAFTLOOK_SIGN_ID="Developer ID Application: NAME (TEAM)"] scripts/release.sh OUT_DIR ENGINES_DIR
# With CRAFTLOOK_SIGN_ID the app is notarized with the keychain profile in CRAFTLOOK_NOTARY_PROFILE
# (craftlook-notary by default, saved once with `xcrun notarytool store-credentials`); without it the
# release is signed ad hoc and not notarized. The update archive is signed for Sparkle with the EdDSA
# key of the keychain account in CRAFTLOOK_SPARKLE_ACCOUNT (craftlook by default), the one whose
# public half is SUPublicEDKey; macOS may ask once to let sign_update use it.
set -euo pipefail
cd "$(dirname "$0")/.."
repo="$PWD"
profile="${CRAFTLOOK_NOTARY_PROFILE:-craftlook-notary}"
account="${CRAFTLOOK_SPARKLE_ACCOUNT:-craftlook}"
mkdir -p "$1"
out="$(cd "$1" && pwd)"
engines="$(cd "$2" && pwd)"
tools="$engines/sparkle/bin"
[[ -z "$(git status --porcelain)" ]] || { echo "The work tree has uncommitted changes" >&2; exit 1; }
app="$(./build.sh "$out" "$engines" | tail -n 1)"
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$app/Contents/Info.plist"; }
version="$(plist CFBundleShortVersionString)"
build="$(plist CFBundleVersion)"
feed="$(plist SUFeedURL)"
if [[ "$("$tools/generate_keys" --account "$account" -p)" != "$(plist SUPublicEDKey)" ]]; then
  echo "The keychain key (account $account) is not the one in SUPublicEDKey" >&2
  exit 1
fi
name="craftlook-$version"
if [[ -n "${CRAFTLOOK_SIGN_ID:-}" ]]; then
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
else
  echo "CRAFTLOOK_SIGN_ID is not set: the release is signed ad hoc and not notarized" >&2
fi
cd "$out"
rm -f "$name-macos.zip" "$name-source.zip" appcast.xml
# The download and Sparkle's update archive are the same ZIP.
ditto -c -k --sequesterRsrc --keepParent "$(basename "$app")" "$name-macos.zip"
git -C "$repo" archive --format=zip --prefix="$name/" -o "$out/$name-source.zip" HEAD
signed="$("$tools/sign_update" --account "$account" "$name-macos.zip")"
signature="$(sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' <<<"$signed")"
length="$(sed -n 's/.*length="\([0-9]*\)".*/\1/p' <<<"$signed")"
[[ -n "$signature" && "$length" == "$(stat -f %z "$name-macos.zip")" ]] || { echo "Unexpected sign_update output: $signed" >&2; exit 1; }
"$tools/sign_update" --account "$account" --verify "$name-macos.zip" "$signature"
releases="https://github.com/Roccobot/CraftLook/releases"
python3 "$repo/scripts/appcast.py" --out appcast.xml --version "$version" --build "$build" \
  --url "$releases/download/v$version/$name-macos.zip" --length "$length" --signature "$signature" \
  --notes "$releases/tag/v$version" --min-system "$(plist LSMinimumSystemVersion)" --previous "$feed"
shasum -a 256 "$name-macos.zip" "$name-source.zip" > "$name-SHA256.txt"
cat "$name-SHA256.txt"
echo "Upload to the release v$version: $name-macos.zip, $name-source.zip, $name-SHA256.txt and appcast.xml"
