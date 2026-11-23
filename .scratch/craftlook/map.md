# Mappa: CraftLook su macOS, Windows e Linux

Label: wayfinder:map
Card: [CraftLook: verifica e anteprime per Windows e Linux](https://trello.com/c/jPIoBbaZ)

## Destination

Una specifica pronta per costruire (`.scratch/craftlook/spec.md`, con le decisioni difficili da
rovesciare in `docs/adr/`) e il piano a tappe (scelta `Meta-01`, 2026-11-23): prima la **0.5.1**
per macOS con le correzioni della verifica, poi la **0.6.0** con miniature e anteprime anche su
Windows e Linux e un nucleo Rust comune a tutte e tre le piattaforme, macOS compreso. Chi sviluppa,
dalla settimana del 2026-11-30, parte senza dubbi aperti.

## Notes

- **La richiesta di Rocco** (2026-11-23): verificare CraftLook, portato avanti da Grok Bot fino
  alla 0.5.0, migliorarlo, e portare nelle versioni nuove anteprime e miniature per Windows e Linux
  (Dolphin, GNOME Files, Nemo, Thunar). Prima la mappa, poi ci si ferma: lo sviluppo è la
  settimana dopo.
- **La verifica della 0.5.0** (2026-11-23): il rapporto intero è un commento della card; i dieci
  difetti e le migliorie sono la materia del ticket
  [Le correzioni della 0.5.1](issues/07-correzioni-della-0-5-1.md).
- **Già deciso nell'intervista di partenza** (2026-11-23):
  - nucleo comune in Rust per tutte e tre le piattaforme, e in questa mappa entra anche il
    passaggio di macOS al nucleo Rust (`Nucleo-01`, `MacRust-02`);
  - le correzioni escono prima, in una 0.5.1 per macOS (`Correzioni-01`), e la prima versione con
    Windows e Linux è la 0.6.0 (`Versione-01`);
  - Windows: miniature e riquadro di anteprima di Esplora file (`Windows-01`), installatore MSI
    per l'utente, senza amministratore (`Installa-01`), senza firma del codice per ora
    (`Firma-01`);
  - Linux: solo miniature, anche nelle taglie grandi, senza un visualizzatore (`Linux-01`), in
    pacchetti `.deb`, `.rpm` e `.tar.gz` (`Pacchetti-01`);
  - processori: Linux x86_64 e aarch64, Windows x64 e arm64 (`Processori-01`);
  - i renderer sono inclusi nei pacchetti, circa 400 MB per piattaforma (`Renderer-01`);
  - su Windows e Linux una finestra di informazioni nativa (`Finestra-02`): WinUI 3 su Windows
    (`UIWin-01`), GTK 4 con libadwaita su Linux (`UILinux-01`);
  - su Windows e Linux un avviso quando esce una versione nuova (`Aggiorna-02`); macOS resta su
    Sparkle;
  - prove su Windows e Linux solo con GitHub Actions (`Prove-02`).
- **Fatti già accertati** (2026-11-23):
  - le CLI dei renderer sono nei pacchetti Linux (`bin/<app>-cli` nel `.tar.gz`) e Windows
    (`<app>-cli.exe` nel portabile `.zip`) di ogni app ArtCraft, per x86_64, aarch64, x64 e arm64;
    la CLI separata esiste solo per macOS;
  - su Linux i file `.thumbnailer` della specifica freedesktop servono GNOME Files, Nemo, Thunar
    (Tumbler, plugin `desktop-thumbnailer`) e Dolphin (KIO, dal 2024); per le anteprime con lo
    Spazio non c'è un sistema di estensioni;
  - su Windows le miniature sono `IThumbnailProvider` e il riquadro di anteprima
    `IPreviewHandler`;
  - SolidCraft a monte è alla 0.47.0, CraftLook usa la 0.46.2.
- **Dominio**: il vocabolario va in `GLOSSARY.md` quando si fissa.
- **Skill da consultare**: `grilling` e `domain-modeling` per i ticket di conversazione,
  `prototype` per quelli di forma, `research` per quelli di ricerca. Le conversazioni sono in
  italiano, con le domande a scelta multipla e la proposta consigliata per prima. **Una voce a cui
  Rocco non risponde è approvata come proposta** (`rules/Roccobot.md` § '🧭 Un progetto nuovo
  grande o complesso: si propone `/wayfinder`').
- **Nessuna scelta di design senza Rocco**: forma, comportamento visibile e testi si propongono e
  si chiedono. La finestra di macOS, la firma di Rocco e il martin pescatore non si toccano
  (`Rules.md` § '🪟 La finestra' e § '⚖️ Licenze e illustrazione').
- ⚠️ **I risultati delle ricerche vivono in `.scratch/craftlook/research/`**, committati su
  `main`, come in Haul: così la mappa li cita con un collegamento che resta valido.

## Decisions so far

- La destinazione e le scelte dell'intervista di partenza: decise da Rocco il 2026-11-23 (Notes,
  sopra).

## Not yet specified

- **Le prove su Windows e Linux**: quali progetti di esempio, come si verifica in CI che Esplora
  file e i thumbnailer producano davvero un'immagine, senza un desktop vero. Dipende dalle
  ricerche sui renderer, su Linux e su Windows.
- **Il registro delle dipendenze su tre piattaforme**: versioni e SHA-256 dei renderer per ogni
  sistema e processore, e il controllo del lunedì che li segue tutti.
- **Licenze e avvisi nei pacchetti di Windows e Linux**: dove vanno `THIRD_PARTY.md` e le licenze
  dei renderer, e i caratteri che i renderer portano con sé.
- **I tipi di file su Linux e Windows**: come si registrano le estensioni delle app ArtCraft
  (tipi MIME su Linux, ProgID su Windows) quando l'app che li ha creati non è installata, senza
  litigare con lei quando lo è.
- **Il README e le pagine di download per tre piattaforme**, e le note delle release.
- **Il passaggio di macOS al nucleo Rust**: in che ordine si sostituiscono le parti Swift senza
  rompere le estensioni Quick Look, dopo che il ticket sui confini del nucleo è deciso.

## Out of scope

- La firma del codice su Windows (`Firma-01`: si aggiunge in una versione successiva).
- Un visualizzatore a tutta finestra su Linux (`Linux-01`).
- Flatpak, Snap e AUR (`Pacchetti-01`: Flatpak e Snap non possono installare miniature di sistema).
- L'installazione automatica degli aggiornamenti su Windows e Linux: la 0.6.0 avvisa soltanto
  (`Aggiorna-02`).
- Le prove a mano su un PC Windows o Linux (`Prove-02`).
