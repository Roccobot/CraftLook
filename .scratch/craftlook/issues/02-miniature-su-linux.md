# Le miniature su Linux

Type: research
Status: open
Blocked by:

## Question

Come si dà una miniatura ai file ArtCraft in GNOME Files, Nemo, Thunar e Dolphin con un solo
thumbnailer, e con quali vincoli? Con fonte primaria e data, per ogni file manager nelle versioni
delle distribuzioni attuali (Ubuntu LTS e non LTS, Fedora, Debian stabile, openSUSE, Linux Mint,
Kubuntu o KDE neon, Xubuntu):
- il formato del file `.thumbnailer` (`TryExec`, `Exec` con `%i`, `%o`, `%s`, `%u`, `MimeType`),
  dove si installa (`/usr/share/thumbnailers`, `~/.local/share/thumbnailers`) e chi lo legge;
- le taglie chieste (`normal` 128, `large` 256, `x-large` 512, `xx-large` 1024), la cache
  (`~/.cache/thumbnails`) e come si invalida;
- la sandbox `bwrap` di GNOME Files (gnome-desktop): che cosa vede il thumbnailer, se può avviare
  un altro processo, i limiti di tempo e di memoria;
- Tumbler (Thunar), il plugin `desktop-thumbnailer` e le impostazioni `X-Tumbler Settings`
  (priorità, dimensione massima del file);
- Dolphin: da quale versione di KIO legge i `.thumbnailer`, come lo si attiva (Preview Settings),
  limiti di dimensione, timeout e taglie;
- Nemo (cinnamon-desktop) e Caja;
- i tipi MIME: le app ArtCraft installano `share/mime/packages/<id>.xml` nel loro pacchetto; come
  li registra CraftLook quando l'app non c'è, e senza conflitti quando c'è; i nomi MIME esatti di
  ogni formato (incluso `.scraft`, `.psd`, `.svg`).

Esito atteso: il thumbnailer unico consigliato, con i vincoli per file manager e i tipi MIME da
registrare.
