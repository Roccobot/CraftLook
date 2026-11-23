# Le estensioni di Esplora file

Type: research
Status: open
Blocked by:

## Question

Come si scrivono in Rust le due estensioni di Esplora file, miniature (`IThumbnailProvider`) e
riquadro di anteprima (`IPreviewHandler`), e come si installano con un MSI per l'utente, senza
amministratore (`Windows-01`, `Installa-01`)? Con fonte primaria e data:
- il crate consigliato (`windows`, `windows-core`, `windows-implement`) e un esempio funzionante di
  server COM in-process in Rust per ciascuna interfaccia, con `IInitializeWithStream` o
  `IInitializeWithFile`;
- la registrazione sotto `HKCU\Software\Classes` (CLSID, `ShellEx`, `{e357fccd-...}` per le
  miniature, `PreviewHandlers`), se vale senza amministratore su Windows 10 e 11, e l'isolamento
  (`DisableProcessIsolation`, surrogato `prevhost.exe` per il riquadro);
- se l'estensione può avviare un processo esterno (la CLI del renderer), con quali limiti di tempo
  di Esplora file, e se il riquadro può mostrare un'immagine che arriva dopo qualche secondo;
- x64 e arm64 (e arm64EC), compilazione da GitHub Actions;
- l'MSI per l'utente con WiX 4 o 5 (`Scope="perUser"`), le chiavi di registro, la cartella in
  `%LOCALAPPDATA%\Programs`, la disinstallazione pulita e la cache delle miniature
  (`thumbcache_*.db`) da svuotare;
- SmartScreen e Smart App Control per un MSI non firmato (`Firma-01`): che cosa vede chi scarica,
  e se Smart App Control blocca del tutto un'estensione non firmata.

Esito atteso: la struttura consigliata delle due estensioni e dell'MSI, con i rischi.
