# Rules.md: regole del progetto CraftLook (repo `Roccobot/CraftLook`)

> **Cos'è questo file.** Il testo completo delle regole di **CraftLook**. Vale per
> **tutti gli agenti**: il nucleo, cioè ogni regola in una riga, vive in `AGENTS.md`, e questo file
> ne dà il perché. Nessun agente lo carica da sé: si legge per intero prima di lavorare su una cosa
> di cui parla. Le regole trasversali vivono nell'hub `Roccobot/roccobot.github.io` (`AGENTS.md` e
> `Rules.md`), quelle universali in `rules/Roccobot.md` di `Roccobot/tools`.

## 🧭 Che cos'è

- **Un'app per macOS 13 o successivi, su Apple silicon (M1 o successivi)**, che mostra nel Finder
  miniature e anteprime statiche dei progetti della suite ArtCraft, dei `.psd` e degli `.svg`. Da
  quale parte del file viene l'immagine di ogni formato lo dice la tabella del `README.md`.
- **Com'è fatta**: un'app ospite (`Sources/Host.swift`), due estensioni Quick Look
  (`Sources/QuickLookPreview.swift` e `Sources/QuickLookThumbnail.swift`) e un servizio XPC privato
  in sandbox (`Sources/RenderService.swift`) che avvia i renderer su una copia temporanea del
  progetto. I renderer sono le CLI di FigCraft, DesignCraft, VectorCraft, TextureCraft,
  SolidCraft, FilmCraft, MaterialCraft ed EffectCraft, che `scripts/prepare_renderers.py` scarica
  (archivi universali a monte, di cui si tiene solo la parte arm64) controllandone lo SHA-256;
  i file SVG li disegna la CLI di VectorCraft, e la timeline delle
  sessioni di SoundCraft la disegna l'app stessa (`Sources/Timeline.swift`), su una scheda sempre
  quadrata (scelta dell'utente del 2026-11-22).
- **I renderer sono nell'app una volta sola**, in `Contents/Helpers`: le due estensioni Quick Look
  hanno ciascuna un servizio XPC sottile (`CraftRender.xpc`) che avvia quelle stesse CLI, con un
  collegamento fisico (`ln`) nella cartella Helpers del servizio, così la sandbox le esegue e su
  disco resta una sola copia. Un servizio XPC risponde solo al bundle che lo contiene, quindi ogni
  estensione ha il suo servizio, ma i renderer non si duplicano. Fino alla 0.4.2 i renderer stavano solo nel servizio delle
  miniature e l'anteprima (Spazio) chiedeva a Quick Look una miniatura grande
  (`QLThumbnailGenerator`); su un file SVG macOS serviva invece il generatore WebKit di sistema,
  con un riquadro fisso che ritagliava il disegno. Dalla 0.5.0 l'estensione delle anteprime chiama
  il proprio servizio, come quella delle miniature. Fino alla build `10` del 2026-11-22 ogni
  estensione aveva la sua copia completa dei renderer, e l'app pesava 3,1 GB.
- **Il servizio mette in coda le richieste**: due renderer alla volta per servizio, quindi fino a
  quattro con miniature e anteprime insieme, e chi aspetta resta in coda invece di essere respinto
  (il Finder chiede molte miniature insieme). Un render ha 12 secondi dalla richiesta, e una
  richiesta che trova posto con meno di 3 secondi rimasti rinuncia invece di avviare un renderer
  che verrebbe fermato subito (0.5.1). `Tests/service_check.sh` lo prova con richieste in parallelo.
- **Allo scadere il renderer si ferma con tutto quello che ha avviato**, e la fine di quello che ha
  scritto come errore va nel registro di sistema (0.5.1); `build/headlesscheck --timeout` lo prova
  con un renderer finto che lascia un processo figlio.
- **Un render fallito non si ripete**: FigCraft e DesignCraft, che in grande chiedono prima il
  renderer, ripiegano sull'immagine salvata senza un secondo tentativo (0.5.1).
- **Una sessione di SoundCraft con valori impossibili si disegna comunque** (scelta `Scraft-01`
  dell'utente del 2026-11-23): frequenza, tempo, misura, tempi e altezze delle note si riportano in
  un intervallo sensato, e una sessione più lunga di un giorno si disegna fino al suo primo giorno.
  Fino alla 0.5.0 un valore enorme faceva cadere le estensioni.
- **Un medium di FilmCraft che non si può leggere diventa un segnaposto**: un rettangolo arrotondato
  verde `#43B59E` della sua misura, al suo posto, ricollegato dalla CLI prima del render; se il
  render non riesce, il segnaposto copre il fotogramma (scelta dell'utente del 2026-11-22). Nella
  sandbox ogni file fuori dal progetto è illeggibile, anche se esiste.
- **Un'immagine SVG collegata nella stessa cartella entra nel disegno**, se l'estensione può leggerla:
  solo un nome di file nella stessa cartella (`href` e `xlink:href`, senza percorso, schema, `..`,
  query o frammento), copiato accanto alla copia temporanea del documento. Se non si può leggere,
  resta il segnaposto di VectorCraft. Al massimo 32 file e 64 MB in tutto, cercati nei primi 16 MB
  del disegno; i nomi che il servizio usa per sé (`craftlook-input.svg`,
  `craftlook-document.svg`, `craftlook-output.png`, in qualunque maiuscola) restano fuori, perché
  prenderebbero il posto della copia del documento o del disegno (0.5.1). Un `clip-path` CSS non è applicato; se il font chiesto non
  c'è, VectorCraft usa Source Sans 3 (scelta dell'utente del 2026-11-22, 0.5.0).
- **La variante senza renderer dichiara solo i formati che sa leggere da sola** (`configure.py
  --embedded-only`, che `build.sh` usa quando manca la cartella dei renderer): FigCraft,
  DesignCraft, VectorCraft, TextureCraft, PhotoCraft, SoundCraft e PSD. Gli SVG e i formati che
  vogliono un renderer restano alle anteprime di macOS (0.5.1).
- **Repo principale dal 2026-11-22** (scelta `Elenco-01` dell'utente, card `Pescatore`); la sessione
  titolare è `CraftWorks`, quella che lavora con le applicazioni della suite ArtCraft.

## 🌿 Ramo e versione

- **Ramo principale `main`.**
- **L'app si chiama CraftLook dalla 0.4.0**, la prima release col nome nuovo (scelta dell'utente del 2026-11-22): `CraftLook.app`,
  identificativi `com.roccobot.craftlook`, `.preview`, `.thumbnail` e `.thumbnail.render`, archivi
  `craftlook-<versione>-macos.tar.xz` (fino alla 0.4.2 era `-macos.zip`), `-source.zip` e `-SHA256.txt`. Fino alla 0.2.5 era 'ArtCraft
  Quick Look', con gli identificativi `org.artcraftquicklook.local` e il repo `artcraft-quick-look`,
  che GitHub reindirizza a `CraftLook`; l'archivio della release 0.2.5 tiene il nome vecchio. Con
  identificativi diversi le due app non si riconoscono: prima di installare CraftLook si cancella
  'ArtCraft Quick Look', perché le due non mostrino gli stessi file.
- **Versione SemVer**, con la fonte unica in `configure.py`: `CFBundleShortVersionString` è la
  versione mostrata, `CFBundleVersion` il numero di build, che sale di uno a ogni versione
  pubblicata, non a ogni build provata. Al 2026-11-23 l'ultima pubblicata è `0.5.1` (`16`), quella
  che porta `configure.py`, con le correzioni della verifica del 2026-11-23 (scelta `Ambito-01`). La `0.4.3` non è stata pubblicata: le sue correzioni SVG sono nella
  `0.5.0`, che è anche la prima solo per Apple silicon. La `0.3.0` (`10`) e la `0.3.1`
  (`11`) le ha provate solo l'utente sul suo Mac, e le loro novità sono nelle note della `0.4.0`.
  Le note sono una per versione pubblicata, in `docs/release-notes/`.
- **Una versione pubblicata è una release di GitHub** di questo repo, con l'app costruita da
  `scripts/release.sh`: `build.sh`, gli archivi con gli SHA-256 e l'appcast di Sparkle
  (§ '🔄 Aggiornamenti'); con l'identità Developer ID Application di `CRAFTLOOK_SIGN_ID` anche la
  notarizzazione col profilo `craftlook-notary` di `notarytool` e la graffetta (`stapler`). Senza
  identità firma ad hoc. La 0.4.0 è la prima release firmata Developer ID e notarizzata; una release
  ad hoc, se mai servisse, lo dice nel README e nelle note.
- **Ogni parte dell'app ha il runtime protetto** (`--options runtime`), firmata dall'interno verso
  l'esterno: renderer, servizio, estensioni, app. I renderer tengono gli entitlement della firma
  originale (`--preserve-metadata=entitlements`): solo SolidCraft ne ha uno,
  `com.apple.security.cs.allow-unsigned-executable-memory`, perché il suo wasmtime compila
  WebAssembly; servizio ed estensioni tengono la sandbox.

## 🪟 La finestra

- **Una finestra sola, di introduzione e impostazioni** (`Sources/Intro.swift`, in inglese): cosa fa
  CraftLook, gli aggiornamenti, il pulsante *Open System Settings* e la firma. Testi, pulsanti e
  immagini stanno a 40 punti dai bordi, in una colonna di testo di 400 (difetto segnalato
  dall'utente il 2026-11-22); `Tests/WindowSnapshot.swift` la disegna fuori dallo schermo, nei due
  temi, e fallisce se uno di loro oltrepassa i margini.
- **Composta secondo Liquid Glass** (richiesta dell'utente del 2026-11-22; guida di Apple, 'Materials'):
  il contenuto sta sul materiale della finestra, da bordo a bordo sotto una barra del titolo
  trasparente (`Intro.style`), e il vetro è solo dei controlli, raccolti in due pannelli
  (`NSGlassEffectView` dentro un `NSGlassEffectContainerView`, da macOS 26) a 24 punti dai bordi,
  con l'angolo concentrico ai pulsanti: 16 punti di margine interno più 12 di raggio del
  pulsante. Prima di macOS 26 i pannelli usano un materiale standard (`NSVisualEffectView`,
  `.popover`) con la stessa forma. Le icone di GitHub e Telegram restano semplici: la guida vuole
  il vetro solo sui controlli più importanti.
- **I pulsanti sono quelli standard di AppKit** (`NSButton` a pressione, forma e misura di serie):
  li disegna il sistema, col vetro da macOS 26 e come sempre prima (l'utente li ha trovati diversi da
  quelli di sistema con la forma a capsula forzata, 2026-11-22).
- **Lo snapshot fuori dallo schermo non ha uno sfondo dietro la finestra**, quindi il vetro vi appare
  senza rifrazione: la resa vera si vede solo con la finestra aperta.
- ***Open System Settings*** **apre le estensioni di Quick Look**:
  `x-apple.systempreferences:com.apple.ExtensionsPreferences`, il pannello Estensioni fino a macOS 14,
  e da macOS 15 Elementi login ed estensioni, che risponde allo stesso nome (`url_alias` del pannello,
  letto su macOS 27.2.1); se il nome non risponde più, si apre Impostazioni di Sistema.
- **I nomi delle app e dei pannelli di Apple sono quelli dei sistemi che CraftLook supporta**: da
  macOS 13 l'app è System Settings, in italiano Impostazioni di Sistema, e System Preferences era il
  nome di macOS 12. La 0.4.1 diceva ancora *Open System Preferences*, corretto nella 0.4.2 su
  richiesta dell'utente (2026-11-22): un nome superato va fatto notare all'utente, anche quando è lui
  a proporlo.
- **In calce la firma dell'utente** (sue richieste del 2026-11-22): *Made with* col cuore U+2665 *by
  Rocco 'Roccobot' Casadei* e il suo marchio, poi `www.roccobot.me` e le icone di GitHub e Telegram. Il
  marchio è `Resources/tian.svg`, copiato byte per byte da `design/assets/mark/tian-turchese.svg`
  dell'hub e mai modificato (`rules/Roccobot.md`, il kanji U+5929). Nel tema chiaro marchio e link
  hanno il verde petrolio scuro del fondo dell'icona dell'app, `#03484F` (scelta dell'utente, preso
  da `docs/images/kingfisher.png`); nel tema scuro il marchio è turchese e il link `testo-accento`
  del design system. Le PDF che
  l'app disegna le scrive `scripts/icons.py`, perché macOS 13 non legge le immagini SVG. La stessa
  firma è nel pannello Informazioni, e `NSHumanReadableCopyright` dice `© 2026 Rocco Casadei, a.k.a.
  Roccobot`.

## 🔄 Aggiornamenti

- **Sparkle 2, dalla 0.4.0** (scelta dell'utente del 2026-11-22): `Sparkle.framework` in
  `Contents/Frameworks` (dal pacchetto ufficiale, di cui si tiene solo la parte arm64), che
  `scripts/prepare_renderers.py` scarica con lo SHA-256, collegato dall'app (`Sources/Host.swift`);
  senza Sparkle la build non si aggiorna. Dalla 0.5.0 la voce nuova dell'appcast ha
  `sparkle:hardwareRequirements` `arm64`, così una copia Intel della 0.4.2 non riceve un
  aggiornamento che non potrebbe eseguire. L'archivio della release è un `tar.xz`, perché un
  ZIP non conserva i collegamenti fisici dei renderer e li triplicherebbe su disco.
- **L'app non è in sandbox**, quindi i servizi XPC di Sparkle (`Installer.xpc`,
  `Downloader.xpc`) restano fuori, come dice la guida di Sparkle, e servono solo `Autoupdate` e
  `Updater.app`, firmati da `build.sh` dall'interno verso l'esterno col runtime protetto.
- **Un controllo al giorno mentre l'app è aperta, e una domanda prima di installare**
  (`SUEnableAutomaticChecks`, `SUScheduledCheckInterval` 86400, `SUAutomaticallyUpdate` spento, in
  `configure.py`); la voce *Check for Updates...* del menu e la casella della finestra, in inglese.
- **L'appcast è un allegato di ogni release**: `SUFeedURL` è
  `https://github.com/Roccobot/CraftLook/releases/latest/download/appcast.xml`. Il repo è pubblico,
  e così l'appcast arriva insieme al suo archivio, senza commit su `main` né sull'hub; `scripts/appcast.py`
  lo riscrive a ogni release con la versione nuova in testa e le voci dell'appcast pubblicato. Se
  l'appcast pubblicato non si legge per una ragione diversa dalla sua assenza (un limite di
  richieste, un errore del server), lo script si ferma invece di pubblicarne uno senza le voci di
  prima (0.5.1, `Tests/scripts_check.py`).
  Una release segnata come pre-release non è `latest`, quindi non arriva agli aggiornamenti.
- ⚠️⚠️ **La chiave EdDSA è solo di CraftLook**: account `craftlook` del Portachiavi di Rocco, creata
  il 2026-11-22 con `generate_keys --account craftlook`; la metà pubblica è `SUPublicEDKey` in
  `configure.py`. La chiave privata non si legge, non si stampa, non si esporta e non entra mai nel
  repo né in chat; la chiave di Aomidori non si tocca. `release.sh` firma l'archivio con `sign_update
  --account craftlook`, e la prima volta macOS chiede a Rocco di lasciarglielo fare.
- **Ad hoc oggi, Developer ID domani**: Sparkle accetta un aggiornamento se la firma EdDSA è valida
  con la stessa chiave, anche quando cambia la firma del codice, quindi una copia ad hoc si aggiorna
  a una notarizzata. La chiave EdDSA invece non cambia mai, o le copie installate rifiutano gli
  aggiornamenti.

## 🧰 Build e prove

- **Solo su macOS, con gli strumenti di Xcode e Python 3**: i comandi sono nel README, sezione
  `Build e controlli` di `README.it.md`. Un contenitore Linux non compila il progetto.
- `build.sh <cartella di build> [cartella dei renderer]`: senza il secondo argomento costruisce la
  variante che legge solo le anteprime già contenute nei file.
- `Tests/check.py`, con l'eseguibile di `Tests/RenderCheck.swift`, prova la decodifica senza
  l'editor sulle fixture sintetiche: la scelta del composito, le sessioni di SoundCraft coi valori
  impossibili, il rifiuto dei file corrotti, senza immagine o oltre i limiti (con stato d'uscita 1:
  un crash non vale come rifiuto), i file collegati di un SVG, e il disegno della miniatura su tutto
  il contesto in pixel.
- `Tests/scripts_check.py` prova `scripts/appcast.py` senza rete.
- `Tests/samples.py` scrive con le CLI dei renderer un piccolo progetto per ogni formato che solo un
  renderer sa mostrare (nessuno è nel repo), e `Tests/HeadlessCheck.swift` li fa disegnare; il
  progetto FilmCraft col medium cancellato deve mostrare il segnaposto, e il file SVG alto con
  l'immagine collegata nella stessa cartella deve conservare il formato e mostrare quella immagine.
- `Tests/service_check.sh` manda gli stessi file al servizio dell'app costruita, sandbox compresa,
  tutti insieme, e vuole un'immagine per ognuno.
- `Tests/WindowSnapshot.swift` disegna la finestra dell'app fuori dallo schermo, nel tema chiaro e
  in quello scuro, in PNG, senza mostrarla né portare niente in primo piano, e fallisce se una riga
  oltrepassa i margini (§ '🪟 La finestra').

## 🔗 Le dipendenze

- **I renderer e Sparkle sono le dipendenze del progetto**: la versione in uso e lo SHA-256 del
  loro archivio vivono in `RENDERERS` e `SPARKLE` di `scripts/prepare_renderers.py`, il registro è
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
- **Il marchio di Roccobot** (`Resources/tian.svg` e `.pdf`) **è fuori da quella licenza** come il
  martin pescatore, e le icone di GitHub e Telegram sono quelle ufficiali disegnate da Simple Icons,
  CC0-1.0 (`ARTWORK.md`, `THIRD_PARTY.md`).
- **Il martin pescatore è fuori da quella licenza** (`ARTWORK.md`): `Resources/CraftLook.icns`
  e `docs/images/kingfisher.png` si usano così come sono, come ogni icona e immagine dell'utente
  (`rules/Roccobot.md` § '🧹 Bonifica e ottimizzazione degli asset').
- **I renderer tengono le licenze e gli avvisi dei progetti originali** (`THIRD_PARTY.md`), che
  `build.sh` copia nell'app.

## 📖 Il README in due lingue

- `README.md` è in inglese e `README.it.md` in italiano, con lo stesso contenuto: una modifica
  all'uno si porta all'altro nello stesso commit.
