import AppKit
#if canImport(Sparkle)
import Sparkle
#endif

/// The app's only window: what CraftLook does, the updates, the way to the Quick Look extensions in
/// System Settings, and the author's credit. It is a view of its own, so that Tests/WindowSnapshot
/// can draw it offscreen with the same code.
final class Intro: NSObject {
    /// The text column, with the margins on both sides that keep every line off the window's edges.
    static let column: CGFloat = 400
    static let margin: CGFloat = 40
    /// The Quick Look extensions: the Extensions pane up to macOS 14, and Login Items & Extensions,
    /// which answers to the same name (url_alias), from macOS 15.
    static let extensions = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!
    static let website = URL(string: "https://www.roccobot.me")!
    static let github = URL(string: "https://github.com/Roccobot")!
    static let telegram = URL(string: "https://t.me/roccobot")!
    /// The credit, also in the About panel.
    static let credit = "Made with love by Rocco 'Roccobot' Casadei"
    /// Colors of the Roccobot design system (design/tokens.json of the roccobot.github.io hub): the
    /// mark in petrol on light and turquoise on dark, as its files are, since at this size turquoise
    /// doesn't read on light; links in testo-accento, the accent made for text.
    static let markColor = themed(light: 0x00727B, dark: 0x43B59E)
    static let linkColor = themed(light: 0x0B6B5B, dark: 0x4FD9BE)

    private static func themed(light: Int, dark: Int) -> NSColor {
        func color(_ hex: Int) -> NSColor {
            NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? color(dark) : color(light)
        }
    }

    private let resources: URL
    private let icon: NSImage
    #if canImport(Sparkle)
    private let updates: SPUStandardUpdaterController?
    init(resources: URL, icon: NSImage, updates: SPUStandardUpdaterController?) {
        self.resources = resources
        self.icon = icon
        self.updates = updates
    }
    #else
    init(resources: URL, icon: NSImage) {
        self.resources = resources
        self.icon = icon
    }
    #endif

    /// A vector mark from Resources (scripts/icons.py), drawn as a template in the given color.
    func mark(_ name: String, height: CGFloat, color: NSColor) -> NSImageView {
        let image = NSImage(contentsOf: resources.appendingPathComponent("\(name).pdf")) ?? NSImage()
        image.isTemplate = true
        let view = NSImageView(image: image)
        view.imageScaling = .scaleProportionallyUpOrDown
        view.contentTintColor = color
        let ratio = image.size.height > 0 ? image.size.width / image.size.height : 1
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        view.widthAnchor.constraint(equalToConstant: height * ratio).isActive = true
        return view
    }

    private func paragraph(_ text: String, size: CGFloat, color: NSColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: size)
        label.textColor = color
        label.alignment = .center
        label.preferredMaxLayoutWidth = Self.column
        label.widthAnchor.constraint(equalToConstant: Self.column).isActive = true
        return label
    }

    private func link(_ title: String, url: URL) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(open(_:)))
        button.isBordered = false
        button.identifier = NSUserInterfaceItemIdentifier(url.absoluteString)
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: Self.linkColor, .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
        ])
        button.toolTip = url.absoluteString
        return button
    }

    private func social(_ name: String, label: String, url: URL) -> NSButton {
        let button = NSButton(title: "", target: self, action: #selector(open(_:)))
        button.isBordered = false
        button.identifier = NSUserInterfaceItemIdentifier(url.absoluteString)
        let image = NSImage(contentsOf: resources.appendingPathComponent("\(name).pdf")) ?? NSImage()
        image.isTemplate = true
        image.size = NSSize(width: 16, height: 16)
        button.image = image
        button.imagePosition = .imageOnly
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = label
        button.setAccessibilityLabel(label)
        return button
    }

    @objc private func open(_ sender: NSButton) {
        if let address = sender.identifier?.rawValue, let url = URL(string: address) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openExtensions(_ sender: Any?) {
        // If the pane's name ever stops answering, System Settings opens on its first page.
        if !NSWorkspace.shared.open(Self.extensions) {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    func view() -> NSView {
        let info = Bundle.main.infoDictionary ?? [:]
        let image = NSImageView(image: icon)
        image.widthAnchor.constraint(equalToConstant: 96).isActive = true
        image.heightAnchor.constraint(equalToConstant: 96).isActive = true
        let name = NSTextField(labelWithString: "CraftLook")
        name.font = .boldSystemFont(ofSize: 20)
        let version = NSTextField(labelWithString:
            "Version \(info["CFBundleShortVersionString"] as? String ?? "") (\(info["CFBundleVersion"] as? String ?? ""))")
        version.textColor = .secondaryLabelColor
        let text = paragraph("Select an ArtCraft project, a SoundCraft session or an SVG file in Finder and press Space to see what's inside.",
                             size: NSFont.systemFontSize, color: .labelColor)
        var rows: [NSView] = [image, name, version, text]
        #if canImport(Sparkle)
        if let updates {
            let automatic = NSButton(checkboxWithTitle: "Check for updates automatically", target: nil, action: nil)
            automatic.bind(.value, to: updates.updater, withKeyPath: #keyPath(SPUUpdater.automaticallyChecksForUpdates))
            let check = NSButton(title: "Check for Updates...", target: updates,
                                 action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)))
            rows += [automatic, check]
        }
        #endif
        let settings = NSButton(title: "Open System Preferences", target: self, action: #selector(openExtensions(_:)))
        let how = paragraph("Under Extensions, open Quick Look and turn CraftLook on.\nTurn it off to go back to the standard macOS previews.",
                            size: NSFont.smallSystemFontSize, color: .secondaryLabelColor)
        rows += [settings, how]
        let signature = NSTextField(labelWithString: Self.credit)
        signature.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        signature.textColor = .secondaryLabelColor
        let credit = NSStackView(views: [signature, mark("tian", height: 16, color: Self.markColor)])
        credit.orientation = .horizontal
        credit.alignment = .centerY
        credit.spacing = 5
        let website = link("www.roccobot.me", url: Self.website)
        let icons = NSStackView(views: [social("github", label: "GitHub", url: Self.github),
                                        social("telegram", label: "Telegram", url: Self.telegram)])
        icons.orientation = .horizontal
        icons.spacing = 14
        rows += [credit, website, icons]
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(16, after: text)
        stack.setCustomSpacing(18, after: rows[rows.firstIndex(of: settings)! - 1])
        stack.setCustomSpacing(6, after: settings)
        stack.setCustomSpacing(36, after: how)
        stack.setCustomSpacing(2, after: credit)
        stack.setCustomSpacing(10, after: website)
        stack.edgeInsets = NSEdgeInsets(top: 24, left: Self.margin, bottom: 24, right: Self.margin)
        stack.widthAnchor.constraint(equalToConstant: Self.column + 2 * Self.margin).isActive = true
        return stack
    }

    /// The About panel, with the same credit as the window.
    func about(_ sender: Any?) {
        let credits = NSMutableAttributedString(string: Self.credit + "\n", attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.secondaryLabelColor,
        ])
        credits.append(NSAttributedString(string: "www.roccobot.me", attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), .link: Self.website,
        ]))
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centered, range: NSRange(location: 0, length: credits.length))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate(ignoringOtherApps: true)
    }
}
