# Rules.md: regole del progetto ArtCraft Quick Look (repo `Roccobot/CraftLook`)

> **Cos'è questo file.** Il testo completo delle regole di **ArtCraft Quick Look**. Vale per
> **tutti gli agenti**: il nucleo, cioè ogni regola in una riga, vive in `AGENTS.md`, e questo file
> ne dà il perché. Nessun agente lo carica da sé: si legge per intero prima di lavorare su una cosa
> di cui parla. Le regole trasversali vivono nell'hub `Roccobot/roccobot.github.io` (`AGENTS.md` e
> `Rules.md`), quelle universali in `rules/Roccobot.md` di `Roccobot/tools`.

## 🧭 Che cos'è

- **Un'app per macOS 13 o successivi, su Mac Intel e Apple silicon**, che mostra nel Finder
  miniature e anteprime statiche dei progetti della suite ArtCraft, dei `.psd` e degli `.svg`. Da
  quale parte del file viene l'immagine di ogni formato lo dice la tabella del `README.md`.
- **Com'è fatta**: un'app ospite (`Sources/Host.swift`), due estensioni Quick Look
  (`Sources/QuickLookPreview.swift` e `Sources/QuickLookThumbnail.swift`) e un servizio XPC privato
  in sandbox (`Sources/RenderService.swift`) che avvia i renderer su una copia temporanea del
  progetto. I renderer sono le CLI universali di FigCraft, DesignCraft, VectorCraft, TextureCraft,
  SolidCraft, FilmCraft, MaterialCraft ed EffectCraft, che `scripts/prepare_renderers.py` scarica
  controllandone lo SHA-256; i file SVG li disegna la CLI di VectorCraft.
- **Repo principale dal 2026-11-22** (scelta `Elenco-01` dell'utente, card `Pescatore`); la sessione
  titolare è `CraftWorks`, quella che lavora con le applicazioni della suite ArtCraft.

## 🌿 Ramo e versione

- **Ramo principale `main`.**
- **Il repo si chiamava `artcraft-quick-look` fino al 2026-11-22**, quando l'utente l'ha rinominato
  `CraftLook`; l'app resta 'ArtCraft Quick Look'. GitHub reindirizza i link e i cloni col nome
  vecchio, e l'archivio della release 0.2.5 (`artcraft-quick-look-0.2.5-macos.zip`) lo conserva.
- **Versione SemVer**, con la fonte unica in `configure.py`: `CFBundleShortVersionString` è la
  versione mostrata, `CFBundleVersion` il numero di build, che sale di uno a ogni versione
  pubblicata. Al 2026-11-22 l'ultima pubblicata è `0.2.5` (`9`), e `configure.py` porta già `0.3.0`
  (`10`), la versione in preparazione.
- **Una versione pubblicata è una release di GitHub** di questo repo, con l'app costruita da
  `build.sh`, firmata ad hoc e non notarizzata da Apple (lo dice il README).

## 🧰 Build e prove

- **Solo su macOS, con gli strumenti di Xcode e Python 3**: i comandi sono nel README, sezione
  `Build e controlli` di `README.it.md`. Un contenitore Linux non compila il progetto.
- `build.sh <cartella di build> [cartella dei renderer]`: senza il secondo argomento costruisce la
  variante che legge solo le anteprime già contenute nei file.
- `Tests/check.py`, con l'eseguibile di `Tests/RenderCheck.swift`, prova la decodifica senza
  l'editor sulle fixture sintetiche: la scelta del composito e il rifiuto dei file corrotti, senza
  immagine o oltre i limiti, e il disegno della miniatura su tutto il contesto in pixel.
- `Tests/samples.py` scrive con le CLI dei renderer un piccolo progetto per ogni formato che solo un
  renderer sa mostrare (nessuno è nel repo), e `Tests/HeadlessCheck.swift` li fa disegnare.

## 🔗 Le dipendenze

- **I renderer sono le dipendenze del progetto**: la versione in uso e lo SHA-256 del loro
  archivio vivono in `RENDERERS` di `scripts/prepare_renderers.py`, il registro è
  `docs/Dependencies.json`, e il flusso `dependencies.yml` li confronta ogni lunedì con l'ultima
  release, aprendo la issue `Dipendenze da leggere` se ce n'è una nuova (`rules/Roccobot.md`
  § '🔗 Le dipendenze si seguono: ogni versione nuova si legge').
- **Un renderer nuovo entra con la sua versione e lo SHA-256 in `RENDERERS`**, la versione nei due
  README e una build provata sul Mac.

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
