# Le correzioni della 0.5.1

Type: grilling
Status: resolved
Blocked by:

## Question

Che cosa entra nella 0.5.1 per macOS (`Correzioni-01`), e che cosa aspetta la 0.6.0? La materia è
la verifica della 0.5.0 (commento della card, 2026-11-23): il crash delle estensioni su un
`.scraft` malformato, la memoria delle richieste in coda, le risorse SVG che sovrascrivono la copia
di lavoro e quelle senza tetto, il doppio render di FigCraft e DesignCraft, la scala fissa di
VectorCraft, FigCraft e DesignCraft, la build solo-incorporate, i difetti minori, le prove che
passano col difetto, i documenti non allineati, i `.pcraft` in pacchetto e Sparkle in beta.

Da decidere con Rocco, per ogni voce: 0.5.1 o 0.6.0 (dove il nucleo Rust la riscrive comunque);
la prova che l'avrebbe fermata; se aggiornare insieme i renderer (SolidCraft 0.47.0) e passare a
uno Sparkle stabile; come si comporta la 0.5.1 con le copie Intel ferme alla 0.4.2.

Esito atteso: l'elenco della 0.5.1, con le prove, pronto per lo sviluppo.

## Answer

Decisa da Rocco il 2026-11-23 e pubblicata lo stesso giorno come [CraftLook 0.5.1](https://github.com/Roccobot/CraftLook/releases/tag/v0.5.1) (build 16, `3016a24`, notarizzata).

- `Ambito-01`: dentro tutte le correzioni tranne le due ristrutturazioni, che passano alla 0.6.0 col
  nucleo Rust: la memoria delle richieste in coda e la scala dei render secondo la taglia chiesta.
- `SolidCraft-01`: SolidCraft 0.47.0. `Scraft-01`: una sessione con valori impossibili si disegna
  coi valori riportati in un intervallo sensato. `Intel-01`: niente per le copie Intel, ferme alla
  0.4.2.
- Un punto della verifica si è rivelato falso: allo scadere del tempo anche il codice della 0.5.0
  fermava i processi avviati dal renderer. La prova `headlesscheck --timeout` ora lo sorveglia.
- Sparkle resta 2.11.0-beta.1, l'ultima versione a monte.
- Restano per la 0.6.0, oltre alle due ristrutturazioni: una copia del documento in meno nel
  servizio, il PNG passato com'è all'anteprima, la pulizia delle cartelle temporanee lasciate da un
  servizio chiuso, il caso `tcraft` esplicito nei renderer, la ricerca della cartella Helpers
  limitata all'app, e la notarizzazione da DMG.
