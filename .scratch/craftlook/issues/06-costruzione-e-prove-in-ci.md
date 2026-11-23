# Costruzione e prove su GitHub Actions

Type: research
Status: open
Blocked by:

## Question

Come si costruiscono e si provano i pacchetti di Windows e Linux solo con GitHub Actions
(`Prove-02`), e quanto costa? Con fonte primaria e data:
- i runner disponibili per un repo pubblico: Ubuntu x86_64 e arm64, Windows x64 e arm64, e il
  loro costo (zero per i repo pubblici?), con le quote e i limiti di durata;
- compilare il nucleo e le estensioni per ogni processore: sul runner nativo o in
  compilazione incrociata;
- costruire `.deb`, `.rpm` e `.tar.gz` (`cargo-deb`, `cargo-generate-rpm`, `nfpm` o altro) e l'MSI
  (WiX) dal runner;
- provare davvero le miniature senza un desktop: lanciare il thumbnailer come lo lancerebbe
  GNOME Files (anche dentro `bwrap`) e Dolphin, e su Windows chiamare `IThumbnailProvider` e
  `IPreviewHandler` registrate, o `IShellItemImageFactory`, da un programma di prova;
- scaricare i renderer da tutte le release a monte in CI con lo SHA-256, e quanto pesa la cache;
- pubblicare tutto in una release di GitHub insieme all'archivio di macOS, che si costruisce e si
  notarizza sul Mac di Rocco (`scripts/release.sh`).

Esito atteso: i flussi consigliati, con i minuti stimati per versione e i rischi.
