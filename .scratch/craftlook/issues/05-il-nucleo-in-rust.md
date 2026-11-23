# Il nucleo in Rust: che cosa sa fare da solo

Type: research
Status: open
Blocked by:

## Question

Quali librerie Rust servono perché il nucleo faccia da solo, su tre piattaforme, quello che oggi
fanno `Sources/Archive.swift`, `DocumentImage.swift`, `Drawing.swift`, `Timeline.swift`,
`SVGResource.swift` e `HeadlessRenderer.swift` con le API di Apple (ImageIO, CGPDF, CoreGraphics,
CoreText)? Con fonte primaria e data:
- ZIP con gli stessi controlli di `Archive.swift` (tetti, CRC, cifrati e ZIP64 rifiutati);
- decodifica PNG, JPEG e della composita dei `.psd`; le anteprime PDF incorporate nei
  `.vectorcraft`: come si rasterizza un PDF in Rust (pdfium, MuPDF, hayro o altro), con licenza e
  peso;
- il disegno della timeline di SoundCraft (forme, testo, caratteri) con `tiny-skia` o simili, e
  il testo con `cosmic-text`, `fontdue` o simili; quale carattere includere perché la timeline sia
  uguale ovunque;
- l'avvio dei renderer con limite di tempo, uccisione del gruppo di processi e coda limitata, su
  Unix e Windows;
- il ponte con Swift per macOS (UniFFI, `swift-bridge`, libreria C) dentro le estensioni Quick
  Look e il servizio XPC in sandbox, firma e runtime protetto compresi; e con C# per WinUI 3;
- licenze compatibili con la MIT di CraftLook.

Esito atteso: le librerie consigliate per ogni parte, con licenza, peso e rischi.
