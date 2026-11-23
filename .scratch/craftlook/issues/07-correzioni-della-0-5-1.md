# Le correzioni della 0.5.1

Type: grilling
Status: open
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
