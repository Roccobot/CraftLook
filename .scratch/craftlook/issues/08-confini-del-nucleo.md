# I confini del nucleo Rust

Type: grilling
Status: open
Blocked by: 01, 05

## Question

Che cosa decide il nucleo Rust e che cosa resta a ogni piattaforma (`Nucleo-01`, `MacRust-02`)?
Da decidere con Rocco, sulle ricerche dei renderer e delle librerie:
- la sequenza unica che sceglie l'immagine di un file (incorporata, renderer, timeline), oggi in
  `RenderXPC.picture`, con i limiti di tempo, di grandezza e la coda;
- che cosa riceve e che cosa restituisce il nucleo (percorso o byte, PNG o pixel, taglia chiesta);
- l'eseguibile unico `craftlook-render` che usano il thumbnailer Linux e le estensioni Windows, e
  come lo usano le estensioni Quick Look nella sandbox;
- la struttura del repo (cartelle, `Cargo` workspace accanto a `Sources/`), e la prova automatica
  che il nucleo non importi nessuna interfaccia;
- che cosa cambia su macOS nella 0.6.0: quali file Swift spariscono, e come si prova che miniature
  e anteprime restano uguali.

Esito atteso: i confini e l'interfaccia del nucleo, con un ADR.
