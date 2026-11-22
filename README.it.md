# ArtCraft Quick Look

[English README](README.md) · [Scarica la release per macOS](https://github.com/Roccobot/CraftLook/releases/latest)

Il codice, gli script e i test sono distribuiti con [licenza MIT](LICENSE). Per il martin pescatore valgono [condizioni separate](ARTWORK.md). I renderer mantengono le [licenze e gli avvisi dei progetti originali](THIRD_PARTY.md).

ArtCraft Quick Look 0.2.5 (build 9) aggiunge l'icona del martin pescatore in undici risoluzioni macOS, incluse le varianti Retina. L'app mostra miniature e anteprime statiche nel Finder su macOS 13 o successivi, su Mac Intel e Apple silicon.

Estrai l'app, spostala in Applicazioni, aprila una volta, quindi seleziona un progetto nel Finder e premi Spazio. Se occorre, abilita le due estensioni Quick Look nelle Impostazioni di Sistema. Questa build di anteprima ha una firma ad hoc e non è notarizzata da Apple. Su un altro Mac Gatekeeper può chiedere un'autorizzazione all'apertura. [Guida Apple](https://support.apple.com/it-it/102445)

| File | Sorgente dell'immagine |
| --- | --- |
| `.figcraft` | `thumbnail.png` |
| `.designcraft` | `preview.png` |
| `.vectorcraft` | Prima tavola del PDF incorporato, oppure immagine incorporata. Include i documenti gzip |
| `.tcraft` | `thumbnail.png` |
| `.pcraft` | Composito a piena risoluzione, composito di anteprima o miniatura |
| `.psd` | Immagine composita tramite ImageIO |

Le anteprime a schermo di FigCraft e DesignCraft usano prima il renderer per ottenere più dettaglio. VectorCraft e TextureCraft possono usare il renderer se il file non contiene un'immagine utilizzabile. Un servizio XPC privato e in sandbox avvia i renderer su una copia temporanea dei progetti fino a 256 MiB. Ogni processo ha un limite di 12 secondi. Le risorse collegate al di fuori del documento possono mancare. Il PDF opzionale di VectorCraft continua a funzionare come sorgente autonoma. Per PSD la lettura dipende da ImageIO. I pacchetti ZIP64 e i JSON VectorCraft oltre il limite di lettura richiedono un renderer o restano senza anteprima.

SolidCraft ha un comando CLI in grado di produrre un PNG da un file `.sc`, verificato da terminale. FilmCraft e MaterialCraft documentano comandi corrispondenti. Gli adattatori per richiamarli dal Finder restano da implementare e collaudare. Per i formati senza una fonte visiva accertata non viene dichiarata un'associazione.

## Build e controlli

Lo script di preparazione scarica le quattro CLI universali, controlla ogni SHA-256 e organizza i file di licenza. Il [progetto dimostrativo River Study](examples/river-study.vectorcraft) è pronto da provare nel Finder.

```sh
python3 scripts/prepare_renderers.py "$PWD/engines"
./build.sh "$PWD/build" "$PWD/engines"
xcrun swiftc Sources/Archive.swift Sources/DocumentImage.swift Tests/RenderCheck.swift -o /tmp/artcraft-rendercheck
python3 Tests/check.py /tmp/artcraft-rendercheck
```

Per ricompilare l'app servono gli strumenti di Xcode e Python 3. La versione distribuita include le CLI universali di [FigCraft 0.18.1](https://github.com/storytold/figcraft/releases/tag/v0.18.1), [DesignCraft 0.20.1](https://github.com/storytold/designcraft/releases/tag/v0.20.1), [VectorCraft 0.24.1](https://github.com/storytold/vectorcraft/releases/tag/v0.24.1) e [TextureCraft 0.6.1](https://github.com/storytold/texturecraft/releases/tag/v0.6.1).

Per ciascuna release, estrai il pacchetto `nome-cli-versione-macos-universal.zip` in una cartella temporanea. Prepara una sottocartella `engines/nome/` con il relativo eseguibile `nome-cli`. Copia tutti gli altri file del pacchetto in `engines/nome/Notices/`, comprese le sottocartelle. Passa `engines` come secondo argomento di `build.sh`. Ometti il secondo argomento e usa una cartella di build vuota per ottenere la variante che legge solo le anteprime incorporate.

Sul Mac di collaudo, macOS ha generato miniature dei quattro formati con i renderer e il Finder ha mostrato le sei anteprime tramite la barra spaziatrice.

Le fixture sintetiche verificano la decodifica senza l'editor, la selezione del composito e il rifiuto di file corrotti, senza immagine o fuori limite.

## Fonti dei formati

- [FigCraft](https://github.com/storytold/figcraft/blob/main/crates/format/src/lib.rs)
- [DesignCraft](https://github.com/storytold/craft-libs/blob/main/crates/designcraft-format/src/lib.rs)
- [VectorCraft](https://github.com/storytold/vectorcraft/blob/main/crates/format/src/lib.rs)
- [TextureCraft](https://github.com/storytold/texturecraft/blob/main/crates/formats/src/project_file/mod.rs)
- [PhotoCraft](https://github.com/storytold/photocraft/blob/main/book/src/formats/pcraft.md)
- [Apple Quick Look UI](https://developer.apple.com/documentation/quicklookui/qlpreviewprovider) e [Quick Look Thumbnailing](https://developer.apple.com/documentation/quicklookthumbnailing/qlthumbnailprovider)
