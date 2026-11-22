<p align="center">
  <img src="docs/images/kingfisher.png" width="128" alt="The CraftLook icon, a kingfisher holding a fish">
</p>

<h1 align="center">CraftLook</h1>

<p align="center">Finder thumbnails and Space-bar previews for ArtCraft projects, SoundCraft sessions and SVG files.</p>

<p align="center">
  <a href="https://github.com/Roccobot/CraftLook/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/Roccobot/CraftLook?include_prereleases&label=release&color=03484F"></a>
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-487D82?logo=apple&logoColor=white">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-487D82"></a>
</p>

<p align="center">
  <b><a href="https://github.com/Roccobot/CraftLook/releases/latest">Download for macOS</a></b> · <a href="README.it.md">Guida in italiano</a>
</p>

Select an ArtCraft project in Finder and press **Space** to see what's inside, without opening the app that made it. Select several revisions and flip through them with the arrow keys. Your folders show real thumbnails instead of generic icons.

![Previews of a VectorCraft print, a FilmCraft sunset, a SolidCraft box, a MaterialCraft cube, a SoundCraft timeline and an SVG label](docs/images/formats.png)

<p align="center"><sub>Previews drawn by CraftLook from the project's sample files.</sub></p>

## Supported formats

| App or format | Extension | What you see |
| --- | --- | --- |
| FigCraft | `.figcraft` | A rendered layout. A saved thumbnail can also supply the preview. |
| DesignCraft | `.designcraft` | A rendered design, with the saved preview as a fallback. |
| VectorCraft | `.vectorcraft` | The first artboard from an embedded PDF, a saved preview, or a freshly rendered artboard. Gzip-compressed projects are supported. |
| TextureCraft | `.tcraft` | The saved thumbnail or a rendered view of the project. |
| PhotoCraft | `.pcraft` | The best available saved composite or thumbnail, from a project archive or package. |
| SolidCraft | `.sc`, `.solidcraft` | A rendered view of the design, without the ground grid and the axes. |
| FilmCraft | `.fcproj` | The frame of the active sequence at the saved playhead. A green rounded rectangle takes the place of each picture Quick Look can't read. |
| MaterialCraft | `.mcraft` | The material rendered on the app's 3D scene. |
| EffectCraft | `.ecproj`, `.ecprojx` | The active composition at its current time. |
| SoundCraft | `.scraft` | The timeline on a square card: tracks, clips where and as long as they play, MIDI notes, markers and playhead. |
| Photoshop document | `.psd` | The composite that macOS ImageIO can read. Photoshop is optional. |
| SVG image | `.svg` | The drawing rendered by VectorCraft, text included. |

PdfCraft works on standard PDF files, which macOS previews by itself.

## Install

1. Download the ZIP from the [latest release](https://github.com/Roccobot/CraftLook/releases/latest).
2. Unzip it, move **CraftLook** into **Applications** and open it once.
3. In Finder, select a supported file and press **Space**.

To upgrade, quit the app, replace it in **Applications** with the new one and open it once. CraftLook was called ArtCraft Quick Look up to version 0.2.5: if you have that app, delete it before installing CraftLook, so that the two don't handle the same files. To try it right away, download [River Study, a small VectorCraft project](https://raw.githubusercontent.com/Roccobot/CraftLook/main/examples/river-study.vectorcraft) and keep its `.vectorcraft` extension.

### First launch

The app is ad hoc signed and not yet notarized by Apple, so macOS may refuse to open it the first time. If it does, go to **System Settings**, **Privacy & Security**, and click **Open Anyway**, as [Apple's guide](https://support.apple.com/en-us/102445) explains. You only need to do this once.

If Finder still shows a generic icon, check that the CraftLook extensions are on in **System Settings**, under **General**, **Login Items & Extensions**, **Quick Look**, and that **Show icon preview** is on in Finder's View Options.

### Requirements

- macOS 13 or later, on an Intel or Apple silicon Mac.
- About 1.6 GB of disk space, renderers included.
- No ArtCraft app has to be installed: the renderers ship inside CraftLook. Photoshop isn't needed for `.psd` files either.

## How it works

Two Quick Look extensions give Finder the thumbnails and the larger previews. When a file has no saved preview, a sandboxed service runs the bundled command-line renderer of its app, on your Mac, on a temporary copy of the file, and queues requests that arrive together. Rendering has a 12-second time limit and a 256 MiB input limit. FigCraft and DesignCraft previews reach 2048 pixels on the longest side, and Finder thumbnails prefer a saved image when there is one.

Quick Look doesn't let the renderer read files outside the project, so projects that use them may look different: in a FilmCraft frame, each picture from another file becomes a green rounded rectangle of its size, in its place.

macOS uses one Quick Look extension for each file type. If another app also previews SVG files, such as Looq or Gapplin, turn its extension off in the same Quick Look settings so that CraftLook shows them.

## Build from source

Use a Mac with Xcode Command Line Tools and Python 3. The preparation script downloads the universal CLI releases listed in [THIRD_PARTY.md](THIRD_PARTY.md), each at its latest version, pre-releases included, checks their SHA-256 digests and preserves their notices.

```sh
python3 scripts/prepare_renderers.py "$PWD/engines"
./build.sh "$PWD/build" "$PWD/engines"
```

The result is `build/CraftLook.app`. To use previously downloaded upstream ZIPs, pass `--archives /path/to/archives` to the Python script. For a smaller build that reads only embedded previews, run `./build.sh "$PWD/build-embedded"` in a fresh build directory.

After building, run the document-reader checks with these commands.

```sh
xcrun swiftc Sources/Archive.swift Sources/DocumentImage.swift Sources/Drawing.swift Sources/Timeline.swift Tests/RenderCheck.swift -o build/rendercheck
python3 Tests/check.py build/rendercheck
```

The renderer checks write a small project for each format that only a renderer can show, with that renderer's own command-line tool, then render them.

```sh
python3 Tests/samples.py "$PWD/engines" build/samples
xcrun swiftc -parse-as-library Sources/Archive.swift Sources/DocumentImage.swift Sources/Drawing.swift Sources/Timeline.swift Sources/RenderXPC.swift Sources/HeadlessRenderer.swift Tests/HeadlessCheck.swift -o build/headlesscheck
build/headlesscheck "build/CraftLook.app/Contents/PlugIns/Thumbnail.appex/Contents/XPCServices/CraftRender.xpc/Contents/Helpers" build/samples/* examples/river-study.vectorcraft
```

The service check sends the same files to the app's renderer service, in its sandbox, all at once, and expects a picture for each.

```sh
Tests/service_check.sh "build/CraftLook.app" build/samples/* examples/river-study.vectorcraft
```

Every part of the app is signed with the hardened runtime, ad hoc by default. A release is signed with a Developer ID Application identity, notarized by Apple, stapled and packaged with its SHA-256 checksums. The notary credentials are a keychain profile saved once with `xcrun notarytool store-credentials craftlook-notary`.

```sh
CRAFTLOOK_SIGN_ID="Developer ID Application: NAME (TEAM)" scripts/release.sh "$PWD/release" "$PWD/engines"
```

## Format sources

- [FigCraft](https://github.com/storytold/figcraft/blob/main/crates/format/src/lib.rs)
- [DesignCraft](https://github.com/storytold/craft-libs/blob/main/crates/designcraft-format/src/lib.rs)
- [VectorCraft](https://github.com/storytold/vectorcraft/blob/main/crates/format/src/lib.rs)
- [TextureCraft](https://github.com/storytold/texturecraft/blob/main/crates/formats/src/project_file/mod.rs)
- [PhotoCraft](https://github.com/storytold/photocraft/blob/main/book/src/formats/pcraft.md)
- [SolidCraft](https://github.com/tangency-labs/solidcraft), [FilmCraft](https://github.com/storytold/filmcraft), [MaterialCraft](https://github.com/storytold/materialcraft/blob/main/packaging/macos/Info.plist.in) and [EffectCraft](https://github.com/storytold/effectcraft): the type each app declares, and the image its command-line tool renders
- [SoundCraft](https://github.com/storytold/soundcraft): the type the app declares, and the session that its command-line tool saves
- [Apple Quick Look UI](https://developer.apple.com/documentation/quicklookui/qlpreviewprovider) and [Quick Look Thumbnailing](https://developer.apple.com/documentation/quicklookthumbnailing/qlthumbnailprovider)

## Feedback

For a blank or incorrect preview, include the extension, the macOS version, the version of the app that saved the file and, if possible, a small project you can share. [Report a preview issue](https://github.com/Roccobot/CraftLook/issues/new?template=preview.yml)

## Credits and third-party software

CraftLook is an independent community project. The renderers come from the ArtCraft team, from Tangency Labs for SolidCraft, and from their contributors, and keep their original licenses and notices. [Upstream releases and credits](THIRD_PARTY.md)

## License

The Swift code, build scripts and tests are available under the [MIT license](LICENSE). The kingfisher icon has [separate artwork terms](ARTWORK.md).
