# Le finestre di informazioni e l'avviso di versione nuova

Type: research
Status: open
Blocked by:

## Question

Come si costruiscono la finestra di informazioni (`Finestra-02`) e l'avviso di versione nuova
(`Aggiorna-02`) su Windows e Linux, chiamando il nucleo Rust? Con fonte primaria e data:
- **Windows, WinUI 3** (`UIWin-01`): un'app C# col Windows App SDK non impacchettata (installata
  dall'MSI, senza MSIX), il runtime da includere o richiedere, il materiale Mica, x64 e arm64;
  come chiama il nucleo Rust (libreria C con `csbindgen`, UniFFI per C#, o P/Invoke a mano);
- **Linux, GTK 4 e libadwaita** (`UILinux-01`) con `gtk4-rs` e `libadwaita-rs`: versioni minime
  nelle distribuzioni attuali, tema chiaro e scuro, il file `.desktop` e l'icona;
- **l'avviso**: come si controlla una volta al giorno se esiste una release nuova di
  `Roccobot/CraftLook` senza un processo sempre acceso (Utilità di pianificazione su Windows,
  timer `systemd --user` su Linux), come si mostra la notifica (toast di Windows App SDK, libnotify
  o portale freedesktop), come si spegne, e che cosa apre il clic;
- quanto pesa ciascuna finestra, runtime compresi.

Esito atteso: la struttura consigliata per piattaforma, con il peso e i rischi.
