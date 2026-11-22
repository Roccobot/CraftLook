import AppKit
#if canImport(Sparkle)
import Sparkle
#endif

/// The app's only window: what CraftLook does, the updates, the way to the Quick Look extensions in
/// System Settings, and the author's credit. It is a view of its own, so that Tests/WindowSnapshot
/// can draw it offscreen with the same code.
///
/// The layout follows Liquid Glass (Apple HIG, Materials): the content sits on the window's
/// standard material, edge to edge under a transparent title bar, and only the controls float on
/// glass, grouped in panels with corners concentric to the buttons inside them. Before macOS 26 the
/// panels fall back to a standard material (NSVisualEffectView) with the same shape.
final class Intro: NSObject {
    /// The text column, and the margin that keeps every text and control off the window's edges.
    static let column: CGFloat = 400
    static let margin: CGFloat = 40
    /// The glass panels are wider than the text: inset from the window edges by `edge`, with the
    /// text and controls inside them still at `margin`.
    static let edge: CGFloat = 24
    static var padding: CGFloat { margin - edge }
    /// Concentric corners: a panel's radius is its padding plus the radius of the capsule buttons it
    /// holds (half the height of a regular push button).
    static let controlRadius: CGFloat = 12
    static var panelRadius: CGFloat { padding + controlRadius }
    /// Room for the transparent title bar, which the content runs under.
    static let titlebar: CGFloat = 28
    /// The Quick Look extensions: the Extensions pane up to macOS 14, and Login Items & Extensions,
    /// which answers to the same name (url_alias), from macOS 15.
    static let extensions = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!
    static let website = URL(string: "https://www.roccobot.me")!
    static let github = URL(string: "https://github.com/Roccobot")!
    static let telegram = URL(string: "https://t.me/roccobot")!
    /// The credit, with the heart Rocco asked for, also in the About panel.
    static let credit = "Made with \u{2665} by Rocco 'Roccobot' Casadei"
    /// The mark and the link: in the light theme the dark teal of the app icon's background
    /// (#03484F, sampled from docs/images/kingfisher.png); in the dark theme the mark in turquoise and
    /// the link in testo-accento, from the Roccobot design system (design/tokens.json of the hub).
    static let markColor = themed(light: 0x03484F, dark: 0x43B59E)
    static let linkColor = themed(light: 0x03484F, dark: 0x4FD9BE)

    private static func themed(light: Int, dark: Int) -> NSColor {
        func color(_ hex: Int) -> NSColor {
            NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? color(dark) : color(light)
        }
    }

    /// Sets a window up for this view: full-size content under a transparent title bar.
    static func style(_ window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
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

    /// A push button in the capsule shape of Liquid Glass, where the system has it.
    private func button(_ title: String, target: AnyObject?, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        if #available(macOS 26.0, *) { button.borderShape = .capsule }
        return button
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

    /// An icon button, plain: the HIG keeps glass for the most important controls, and these two are
    /// part of the credit.
    private func social(_ name: String, label: String, url: URL) -> NSButton {
        let button = NSButton(title: "", target: self, action: #selector(open(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(url.absoluteString)
        let image = NSImage(contentsOf: resources.appendingPathComponent("\(name).pdf")) ?? NSImage()
        image.isTemplate = true
        image.size = NSSize(width: 16, height: 16)
        button.image = image
        button.imagePosition = .imageOnly
        button.contentTintColor = .secondaryLabelColor
        button.isBordered = false
        button.toolTip = label
        button.setAccessibilityLabel(label)
        return button
    }

    /// A group of controls on a panel: Liquid Glass on macOS 26 and later, a standard material before.
    private func panel(_ rows: [NSView], spacing: CGFloat = 8) -> NSView {
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = spacing
        stack.edgeInsets = NSEdgeInsets(top: 14, left: Self.padding, bottom: 14, right: Self.padding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let width = Self.column + 2 * Self.padding
        stack.widthAnchor.constraint(equalToConstant: width).isActive = true
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = Self.panelRadius
            glass.contentView = stack
            return glass
        }
        let material = NSVisualEffectView()
        material.material = .popover
        material.blendingMode = .withinWindow
        material.state = .followsWindowActiveState
        material.wantsLayer = true
        material.layer?.cornerRadius = Self.panelRadius
        material.layer?.cornerCurve = .continuous
        material.layer?.masksToBounds = true
        material.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: material.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: material.trailingAnchor),
            stack.topAnchor.constraint(equalTo: material.topAnchor),
            stack.bottomAnchor.constraint(equalTo: material.bottomAnchor),
        ])
        return material
    }

    /// Several panels, merged by the system into one glass rendering where it can.
    private func group(_ panels: [NSView], spacing: CGFloat) -> NSView {
        let stack = NSStackView(views: panels)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = spacing
        if #available(macOS 26.0, *) {
            let container = NSGlassEffectContainerView()
            container.spacing = spacing
            container.contentView = stack
            return container
        }
        return stack
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
        image.widthAnchor.constraint(equalToConstant: 112).isActive = true
        image.heightAnchor.constraint(equalToConstant: 112).isActive = true
        let name = NSTextField(labelWithString: "CraftLook")
        name.font = .systemFont(ofSize: 26, weight: .bold)
        let version = NSTextField(labelWithString:
            "Version \(info["CFBundleShortVersionString"] as? String ?? "") (\(info["CFBundleVersion"] as? String ?? ""))")
        version.textColor = .secondaryLabelColor
        let text = paragraph("Select an ArtCraft project, a SoundCraft session or an SVG file in Finder and press Space to see what's inside.",
                             size: NSFont.systemFontSize, color: .labelColor)
        var panels: [NSView] = []
        #if canImport(Sparkle)
        if let updates {
            let automatic = NSButton(checkboxWithTitle: "Check for updates automatically", target: nil, action: nil)
            automatic.bind(.value, to: updates.updater, withKeyPath: #keyPath(SPUUpdater.automaticallyChecksForUpdates))
            let check = button("Check for Updates...", target: updates,
                               action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)))
            panels.append(panel([automatic, check], spacing: 10))
        }
        #endif
        let settings = button("Open System Preferences", target: self, action: #selector(openExtensions(_:)))
        let how = paragraph("Under Extensions, open Quick Look and turn CraftLook on.\nTurn it off to go back to the standard macOS previews.",
                            size: NSFont.smallSystemFontSize, color: .secondaryLabelColor)
        panels.append(panel([settings, how], spacing: 10))
        let controls = group(panels, spacing: 12)
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
        icons.spacing = 16
        let rows: [NSView] = [image, name, version, text, controls, credit, website, icons]
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.setCustomSpacing(14, after: image)
        stack.setCustomSpacing(2, after: name)
        stack.setCustomSpacing(16, after: version)
        stack.setCustomSpacing(24, after: text)
        stack.setCustomSpacing(36, after: controls)
        stack.setCustomSpacing(2, after: credit)
        stack.setCustomSpacing(12, after: website)
        stack.edgeInsets = NSEdgeInsets(top: Self.titlebar + 20, left: Self.edge, bottom: 28, right: Self.edge)
        stack.translatesAutoresizingMaskIntoConstraints = false
        // The content layer: the window's standard material, edge to edge, under the title bar.
        let background = NSVisualEffectView()
        background.material = .windowBackground
        background.blendingMode = .behindWindow
        background.state = .followsWindowActiveState
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            stack.widthAnchor.constraint(equalToConstant: Self.column + 2 * Self.margin),
        ])
        return background
    }

    /// The About panel, with the same credit as the window.
    func about(_ sender: Any?) {
        let credits = NSMutableAttributedString(string: Self.credit + "\n", attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.secondaryLabelColor,
        ])
        credits.append(NSAttributedString(string: "www.roccobot.me", attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), .link: Self.website,
            .foregroundColor: Self.linkColor,
        ]))
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centered, range: NSRange(location: 0, length: credits.length))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate(ignoringOtherApps: true)
    }
}
