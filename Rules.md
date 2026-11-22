# Rules.md: regole del progetto CraftLook (repo `Roccobot/CraftLook`)

> **Cos'è questo file.** Il testo completo delle regole di **CraftLook**. Vale per
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
  controllandone lo SHA-256; i file SVG li disegna la CLI di VectorCraft, e la timeline delle
  sessioni di SoundCraft la disegna l'app stessa (`Sources/Timeline.swift`).
- **I renderer sono nell'app una volta sola, nel servizio dell'estensione delle miniature**: un
  servizio XPC risponde solo al bundle che lo contiene, quindi l'estensione delle anteprime chiede
  a Quick Look una miniatura grande (`QLThumbnailGenerator`), che disegna l'altra estensione. Fino
  alla build `10` del 2026-11-22 ogni estensione aveva la sua copia, e l'app pesava 3,1 GB.
- **Il servizio mette in coda le richieste**: due renderer alla volta, e chi aspetta resta in coda
  fino ai 12 secondi che un render ha comunque, invece di essere respinto (il Finder chiede molte
  miniature insieme). `Tests/service_check.sh` lo prova con richieste in parallelo.
- **Un medium di FilmCraft che non si può leggere diventa un segnaposto**: un rettangolo arrotondato
  verde `#43B59E` della sua misura, al suo posto, ricollegato dalla CLI prima del render; se il
  render non riesce, il segnaposto copre il fotogramma (scelta dell'utente del 2026-11-22). Nella
  sandbox ogni file fuori dal progetto è illeggibile, anche se esiste.
- **Repo principale dal 2026-11-22** (scelta `Elenco-01` dell'utente, card `Pescatore`); la sessione
  titolare è `CraftWorks`, quella che lavora con le applicazioni della suite ArtCraft.

## 🌿 Ramo e versione

- **Ramo principale `main`.**
- **L'app si chiama CraftLook dalla 0.3.0** (scelta dell'utente del 2026-11-22): `CraftLook.app`,
  identificativi `com.roccobot.craftlook`, `.preview`, `.thumbnail` e `.thumbnail.render`, archivi
  `craftlook-<versione>-macos.zip`, `-source.zip` e `-SHA256.txt`. Fino alla 0.2.5 era 'ArtCraft
  Quick Look', con gli identificativi `org.artcraftquicklook.local` e il repo `artcraft-quick-look`,
  che GitHub reindirizza a `CraftLook`; l'archivio della release 0.2.5 tiene il nome vecchio. Con
  identificativi diversi le due app non si riconoscono: prima di installare CraftLook si cancella
  'ArtCraft Quick Look', perché le due non mostrino gli stessi file.
- **Versione SemVer**, con la fonte unica in `configure.py`: `CFBundleShortVersionString` è la
  versione mostrata, `CFBundleVersion` il numero di build, che sale di uno a ogni versione
  pubblicata, non a ogni build provata. Al 2026-11-22 l'ultima pubblicata è `0.2.5` (`9`), e
  `configure.py` porta già `0.3.0` (`10`), la versione in preparazione.
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
  renderer sa mostrare (nessuno è nel repo), e `Tests/HeadlessCheck.swift` li fa disegnare; il
  progetto FilmCraft col medium cancellato deve mostrare il segnaposto.
- `Tests/service_check.sh` manda gli stessi file al servizio dell'app costruita, sandbox compresa,
  tutti insieme, e vuole un'immagine per ognuno.

## 🔗 Le dipendenze

- **I renderer sono le dipendenze del progetto**: la versione in uso e lo SHA-256 del loro
  archivio vivono in `RENDERERS` di `scripts/prepare_renderers.py`, il registro è
  `docs/Dependencies.json`, e il flusso `dependencies.yml` li confronta ogni lunedì con l'ultima
  release, aprendo la issue `Dipendenze da leggere` se ce n'è una nuova (`rules/Roccobot.md`
  § '🔗 Le dipendenze si seguono: ogni versione nuova si legge').
- **Ogni renderer si prende all'ultima versione, anche pre-release o beta** (scelta dell'utente del
  2026-11-22): i file salvati dalle app più nuove li legge solo la CLI più nuova. Le build notturne
  restano fuori. Nel registro ogni renderer ha `"channel": "any"`: il controllo dell'hub lo segue
  per le release di GitHub da quando ha `newest_release`, e prima di allora segnala solo le release
  stabili.
- **Un renderer nuovo entra con la sua versione e lo SHA-256 in `RENDERERS`**, la versione nei due
  README e una build provata sul Mac.

## ⚖️ Licenze e illustrazione

- **Il codice, gli script e le prove sono MIT** (`LICENSE`).
- **Il martin pescatore è fuori da quella licenza** (`ARTWORK.md`): `Resources/CraftLook.icns`
  e `docs/images/kingfisher.png` si usano così come sono, come ogni icona e immagine dell'utente
  (`rules/Roccobot.md` § '🧹 Bonifica e ottimizzazione degli asset').
- **I renderer tengono le licenze e gli avvisi dei progetti originali** (`THIRD_PARTY.md`), che
  `build.sh` copia nell'app.

## 📖 Il README in due lingue

- `README.md` è in inglese e `README.it.md` in italiano, con lo stesso contenuto: una modifica
  all'uno si porta all'altro nello stesso commit.
