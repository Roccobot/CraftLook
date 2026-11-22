#!/bin/bash
# Runs ServiceCheck against the renderer service of a built app, sandbox included:
# Tests/service_check.sh "build/CraftLook.app" FILE...
# An XPC service answers only the app that contains it, so the check gets an app of its own,
# with a clone of the service.
set -euo pipefail
cd "$(dirname "$0")/.."
service="$1/Contents/PlugIns/Thumbnail.appex/Contents/XPCServices/CraftRender.xpc"
shift
harness="$(mktemp -d)/ServiceCheck.app"
trap 'rm -rf "$(dirname "$harness")"' EXIT
mkdir -p "$harness/Contents/MacOS" "$harness/Contents/XPCServices"
cp -Rc "$service" "$harness/Contents/XPCServices/"
plutil -create xml1 "$harness/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string com.roccobot.craftlook.servicecheck "$harness/Contents/Info.plist"
plutil -insert CFBundleExecutable -string servicecheck "$harness/Contents/Info.plist"
plutil -insert CFBundlePackageType -string APPL "$harness/Contents/Info.plist"
xcrun swiftc -parse-as-library -O Sources/Archive.swift Sources/DocumentImage.swift Sources/Drawing.swift \
  Sources/Timeline.swift Sources/RenderXPC.swift Tests/ServiceCheck.swift -o "$harness/Contents/MacOS/servicecheck"
codesign --force --sign - "$harness"
id=$(plutil -extract CFBundleIdentifier raw "$service/Contents/Info.plist")
"$harness/Contents/MacOS/servicecheck" "$id" "$@"
