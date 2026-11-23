# I renderer su Linux e Windows, senza schermo

Type: research
Status: open
Blocked by:

## Question

Le CLI dei renderer ArtCraft per Linux (`bin/<app>-cli` nei `.tar.gz`, x86_64 e aarch64) e per
Windows (`<app>-cli.exe` nei portabili `.zip`, x64 e arm64) funzionano come quelle per macOS che
CraftLook usa oggi (`Sources/HeadlessRenderer.swift`, argomenti per ogni app)?

Per ognuna delle otto app (FigCraft, DesignCraft, VectorCraft, TextureCraft, SolidCraft,
FilmCraft, MaterialCraft, EffectCraft), con fonte primaria e data:
- gli stessi comandi e gli stessi argomenti di render, e la stessa immagine in uscita;
- se partono senza display né GPU: senza X11 o Wayland, dentro la sandbox `bwrap` di GNOME Files
  (niente rete, `/usr` in sola lettura, solo il file da leggere e la cartella d'uscita), e su
  Windows dentro il processo surrogato di Esplora file (`dllhost.exe`), senza finestra; quali
  librerie di sistema servono su Linux (EGL, Mesa, fontconfig) e se c'è un ripiego software;
- tempo di avvio e di render su file piccoli, e memoria;
- la licenza e gli avvisi che i pacchetti portano, e i caratteri inclusi;
- dimensione delle sole CLI e dei file che servono loro, per piattaforma e processore.

Esito atteso: per ogni app e piattaforma, funziona o no, con che cosa intorno; i rischi che
cambiano il piano.
