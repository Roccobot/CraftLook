import AppKit
#if canImport(Sparkle)
import Sparkle
#endif

/// The app itself: the window of Sources/Intro.swift, the menu and, with Sparkle bundled, the
/// updates. Sparkle reads its settings from Info.plist (configure.py): a check a day while the
/// app runs, and a question before anything is installed.
final class Host: NSObject, NSApplicationDelegate {
    #if canImport(Sparkle)
    private let updates = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    #endif
    private var window: NSWindow?
    private lazy var intro: Intro = {
        let resources = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        #if canImport(Sparkle)
        return Intro(resources: resources, icon: NSApp.applicationIconImage, updates: updates)
        #else
        return Intro(resources: resources, icon: NSApp.applicationIconImage)
        #endif
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = menu()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: Intro.column + 2 * Intro.margin, height: 10), styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "CraftLook"
        window.contentView = intro.view()
        window.setContentSize(window.contentView!.fittingSize)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func menu() -> NSMenu {
        let app = NSMenu()
        app.addItem(withTitle: "About CraftLook", action: #selector(about(_:)), keyEquivalent: "").target = self
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

    @objc private func about(_ sender: Any?) { intro.about(sender) }
}

@main
enum Main {
    static func main() {
        let app = NSApplication.shared
        let host = Host()
        app.delegate = host
        app.setActivationPolicy(.regular)
        app.run()
    }
}
