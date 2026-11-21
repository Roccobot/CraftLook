import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let alert = NSAlert()
alert.messageText = "ArtCraft Quick Look"
alert.informativeText = "Seleziona un documento compatibile nel Finder e premi Spazio. Le estensioni di anteprima e miniatura si gestiscono nelle Impostazioni di Sistema."
alert.addButton(withTitle: "OK")
app.activate(ignoringOtherApps: true)
alert.runModal()
