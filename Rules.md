# Rules.md: regole del progetto ArtCraft Quick Look (repo `Roccobot/artcraft-quick-look`)

> **Cos'è questo file.** Il testo completo delle regole di **ArtCraft Quick Look**. Vale per
> **tutti gli agenti**: il nucleo, cioè ogni regola in una riga, vive in `AGENTS.md`, e questo file
> ne dà il perché. Nessun agente lo carica da sé: si legge per intero prima di lavorare su una cosa
> di cui parla. Le regole trasversali vivono nell'hub `Roccobot/roccobot.github.io` (`AGENTS.md` e
> `Rules.md`), quelle universali in `rules/Roccobot.md` di `Roccobot/tools`.

## 🧭 Che cos'è

- **Un'app per macOS 13 o successivi, su Mac Intel e Apple silicon**, che mostra nel Finder
  miniature e anteprime statiche dei progetti della suite ArtCraft e dei `.psd`. Da quale parte del
  file viene l'immagine di ogni formato lo dice la tabella del `README.md`.
- **Com'è fatta**: un'app ospite (`Sources/Host.swift`), due estensioni Quick Look
  (`Sources/QuickLookPreview.swift` e `Sources/QuickLookThumbnail.swift`) e un servizio XPC privato
  in sandbox (`Sources/RenderService.swift`) che avvia i renderer su una copia temporanea del
  progetto. I renderer sono le CLI universali di FigCraft, DesignCraft, VectorCraft e TextureCraft,
  che `scripts/prepare_renderers.py` scarica controllandone lo SHA-256.
- **Repo principale dal 2026-11-22** (scelta `Elenco-01` dell'utente, card `Pescatore`); la sessione
  titolare è `CraftWorks`, quella che lavora con le applicazioni della suite ArtCraft.

## 🌿 Ramo e versione

- **Ramo principale `main`.**
- **Versione SemVer**, con la fonte unica in `configure.py`: `CFBundleShortVersionString` è la
  versione mostrata, `CFBundleVersion` il numero di build, che sale di uno a ogni versione
  pubblicata. Al 2026-11-22 sono `0.2.5` e `9`.
- **Una versione pubblicata è una release di GitHub** di questo repo, con l'app costruita da
  `build.sh`, firmata ad hoc e non notarizzata da Apple (lo dice il README).

## 🧰 Build e prove

- **Solo su macOS, con gli strumenti di Xcode e Python 3**: i comandi sono nella sezione 'Build e
  controlli' del README. Un contenitore Linux non compila il progetto.
- `build.sh <cartella di build> [cartella dei renderer]`: senza il secondo argomento costruisce la
  variante che legge solo le anteprime già contenute nei file.
- `Tests/check.py`, con l'eseguibile di `Tests/RenderCheck.swift`, prova la decodifica senza
  l'editor sulle fixture sintetiche: la scelta del composito e il rifiuto dei file corrotti, senza
  immagine o oltre i limiti.

## ⚖️ Licenze e illustrazione

- **Il codice, gli script e le prove sono MIT** (`LICENSE`).
- **Il martin pescatore è fuori da quella licenza** (`ARTWORK.md`): `Resources/ArtCraftQuickLook.icns`
  e `docs/images/kingfisher.png` si usano così come sono, come ogni icona e immagine dell'utente
  (`rules/Roccobot.md` § '🧹 Bonifica e ottimizzazione degli asset').
- **I renderer tengono le licenze e gli avvisi dei progetti originali** (`THIRD_PARTY.md`), che
  `build.sh` copia nell'app.

## 📖 Il README in due lingue

- `README.md` è in inglese e `README.it.md` in italiano, con lo stesso contenuto: una modifica
  all'uno si porta all'altro nello stesso commit.
