# Upstream renderers

CraftLook packages the official macOS CLI releases listed below. Upstream ships them as universal ZIPs; CraftLook keeps only the arm64 slice. Each renderer's complete upstream documentation and notices ship in `CraftLook.app/Contents/Resources/Notices/<name>/`. This includes font licenses and VectorCraft's nested PDF backend licenses. VectorCraft also renders SVG files. Each renderer is the latest release, pre-releases included: SolidCraft 0.46.2 is one.

| Renderer | Upstream release | CLI archive SHA-256 |
| --- | --- | --- |
| FigCraft | [0.18.1](https://github.com/storytold/figcraft/releases/tag/v0.18.1) | `87efbca334e0925fce328ede159faef2df781b2a167d573888044127bfd4b0de` |
| DesignCraft | [0.20.1](https://github.com/storytold/designcraft/releases/tag/v0.20.1) | `a178783b31e1af48f7af2b516568ec85537a484dfbcc5057b0f03cadee90c0ab` |
| VectorCraft | [0.24.1](https://github.com/storytold/vectorcraft/releases/tag/v0.24.1) | `7f0c8261e5c831d9681e48272f9ba73bf8702dbf6ceb84f98177c7c007faddf2` |
| TextureCraft | [0.6.1](https://github.com/storytold/texturecraft/releases/tag/v0.6.1) | `80a65494a740d100797d54a55c43ff32ee40ee19678eebae8200f52cbba33bdc` |
| SolidCraft | [0.46.2](https://github.com/tangency-labs/solidcraft/releases/tag/v0.46.2) | `c46a6a5ac3068c9de75195b2235d8be6d90024d3426de5fc0f3967065477445b` |
| FilmCraft | [0.20.1](https://github.com/storytold/filmcraft/releases/tag/v0.20.1) | `1651d9defb54f853cbd69016428bb9f72a7bf26d56e4755b8e2a79535fd0ac82` |
| MaterialCraft | [0.4.1](https://github.com/storytold/materialcraft/releases/tag/v0.4.1) | `bcf0e87191dfca39ba14c8110823b21ed5bc5078ad7ae8e4cff380d83fec6edc` |
| EffectCraft | [0.24.1](https://github.com/storytold/effectcraft/releases/tag/v0.24.1) | `2781eda194372ad47f4c0c7df8b1d38501a3e90bb499282f57e9598a85958673` |

SolidCraft comes from Tangency Labs, the other renderers from the ArtCraft team. The upstream notices offer the renderer code under MIT or Apache-2.0 and identify separate terms for third-party components and ArtCraft branding. The macOS build signs local copies of the CLI executables as part of signing the application, with the hardened runtime and the entitlements of their upstream signature: SolidCraft's allow-unsigned-executable-memory, for the WebAssembly code its wasmtime compiles, is the only one.

## Sparkle

CraftLook updates itself with [Sparkle 2.11.0-beta.1](https://github.com/sparkle-project/Sparkle/releases/tag/2.11.0-beta.1) (release archive SHA-256 `896daf5116e4edb12d00cc6f87ce1ca90fff1e106c1cbb07988bcdbf3ce38c4c`), the `Sparkle.framework` in `CraftLook.app/Contents/Frameworks/` (the official archive is universal; only the arm64 slice is kept), without its XPC services, which only sandboxed apps use. Sparkle is MIT-licensed, with the notices of the components it includes; its license ships in `CraftLook.app/Contents/Resources/Notices/sparkle/LICENSE`. The build signs the framework and its helpers, `Autoupdate` and `Updater.app`, with the hardened runtime.

## Marks in the app window

The GitHub and Telegram icons of the app window (`Resources/github.svg`, `Resources/telegram.svg` and their PDFs, written by `scripts/icons.py`) are the official marks as drawn by [Simple Icons](https://github.com/simple-icons/simple-icons) 16.38.1, released under CC0-1.0. The marks remain trademarks of GitHub and Telegram ([ARTWORK.md](ARTWORK.md)).
