import AppKit
#if canImport(Sparkle)
import Sparkle
#endif

/// The app itself: a small window that explains where CraftLook works, and, with Sparkle bundled,
/// the updates. Sparkle reads its settings from Info.plist (configure.py): a check a day while the
/// app runs, and a question before anything is installed.
final class Host: NSObject, NSApplicationDelegate {
    #if canImport(Sparkle)
    private let updates = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    #endif
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = menu()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 10), styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "CraftLook"
        window.contentView = content()
        window.setContentSize(window.contentView!.fittingSize)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func menu() -> NSMenu {
        let app = NSMenu()
        app.addItem(withTitle: "About CraftLook", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        #if canImport(Sparkle)
        let check = app.addItem(withTitle: "Check for Updates...", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
                                keyEquivalent: "")
        check.target = updates
        #endif
        app.addItem(.separator())
        app.addItem(withTitle: "Hide CraftLook", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Quit CraftLook", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let bar = NSMenu()
        bar.addItem(withTitle: "CraftLook", action: nil, keyEquivalent: "").submenu = app
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        bar.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = windowMenu
        return bar
    }

    private func content() -> NSView {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = "Version \(info["CFBundleShortVersionString"] as? String ?? "") (\(info["CFBundleVersion"] as? String ?? ""))"
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.widthAnchor.constraint(equalToConstant: 96).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 96).isActive = true
        let name = NSTextField(labelWithString: "CraftLook")
        name.font = .boldSystemFont(ofSize: 20)
        let numbers = NSTextField(labelWithString: version)
        numbers.textColor = .secondaryLabelColor
        let text = NSTextField(wrappingLabelWithString: "Select an ArtCraft project, a SoundCraft session or an SVG file in Finder and press Space to see what's inside. The thumbnail and preview extensions can be turned on or off in System Settings, under General, Login Items & Extensions, Quick Look.")
        text.preferredMaxLayoutWidth = 380
        var rows: [NSView] = [icon, name, numbers, text]
        #if canImport(Sparkle)
        let automatic = NSButton(checkboxWithTitle: "Check for updates automatically", target: nil, action: nil)
        automatic.bind(.value, to: updates.updater, withKeyPath: #keyPath(SPUUpdater.automaticallyChecksForUpdates))
        let check = NSButton(title: "Check for Updates...", target: updates, action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)))
        rows += [automatic, check]
        #endif
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(16, after: text)
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 40, bottom: 24, right: 40)
        return stack
    }
}

let app = NSApplication.shared
let host = Host()
app.delegate = host
app.setActivationPolicy(.regular)
app.run()
