import AppKit

func pokiSitelenAppIcon(size: NSSize) -> NSImage {
    if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
       let loaded = NSImage(contentsOf: url),
       let image = loaded.copy() as? NSImage {
        image.size = size
        image.isTemplate = false
        return image
    }

    // Fallback: draw the same roof-and-dot mark used by the application icon.
    let image = NSImage(size: size)
    image.lockFocus()

    let bounds = NSRect(origin: .zero, size: size)
    let background = NSBezierPath(
        roundedRect: bounds.insetBy(dx: size.width * 0.03, dy: size.height * 0.03),
        xRadius: size.width * 0.19,
        yRadius: size.height * 0.19
    )
    NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
    background.fill()

    let roof = NSBezierPath()
    roof.move(to: NSPoint(x: size.width * 0.18, y: size.height * 0.36))
    roof.line(to: NSPoint(x: size.width * 0.50, y: size.height * 0.69))
    roof.line(to: NSPoint(x: size.width * 0.82, y: size.height * 0.36))
    roof.lineCapStyle = .round
    roof.lineJoinStyle = .round
    roof.lineWidth = max(1.5, size.width * 0.065)
    NSColor.white.setStroke()
    roof.stroke()

    NSColor.white.setFill()
    NSBezierPath(
        ovalIn: NSRect(
            x: size.width * 0.415,
            y: size.height * 0.21,
            width: size.width * 0.17,
            height: size.height * 0.17
        )
    ).fill()

    image.unlockFocus()
    image.isTemplate = false
    return image
}

private extension NSTouchBarItem.Identifier {
    static let pokiSitelenTray = NSTouchBarItem.Identifier("com.udeudeude.PokiSitelen.tray")
    static let pokiSitelenForegroundClose = NSTouchBarItem.Identifier("com.udeudeude.PokiSitelen.foregroundClose")
    static let pokiSitelenClipboard = NSTouchBarItem.Identifier("com.udeudeude.PokiSitelen.clipboard")
    static let pokiSitelenToki = NSTouchBarItem.Identifier("com.udeudeude.PokiSitelen.toki")
    static let pokiSitelenContent = NSTouchBarItem.Identifier("com.udeudeude.PokiSitelen.content")
}

final class PokiSitelenTouchBarController: NSObject, NSTouchBarDelegate {
    private enum Mode {
        case toki
        case clipboard
    }

    private let clipboardStore = ClipboardHistoryStore()

    private var mode: Mode = .toki
    private var touchBar = NSTouchBar()
    private var trayItem: NSCustomTouchBarItem?
    private var isStarted = false
    private var activationObservers: [NSObjectProtocol] = []

    func start() {
        guard !isStarted else { return }
        isStarted = true

        DFRSystemModalShowsCloseBoxWhenFrontMost(true)

        let trayItem = NSCustomTouchBarItem(identifier: .pokiSitelenTray)
        let trayButton = NSButton(
            image: pokiSitelenAppIcon(size: NSSize(width: 22, height: 22)),
            target: self,
            action: #selector(presentCurrentBar)
        )
        trayButton.title = ""
        trayButton.imagePosition = .imageOnly
        trayButton.imageScaling = .scaleProportionallyDown
        trayButton.toolTip = "Show poki sitelen"
        trayItem.view = trayButton
        self.trayItem = trayItem

        NSTouchBarItem.addSystemTrayItem(trayItem)
        DFRElementSetControlStripPresenceForIdentifier(.pokiSitelenTray, true)

        let center = NotificationCenter.default
        activationObservers = [
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: NSApp,
                queue: .main
            ) { [weak self] _ in
                self?.rebuildAndPresent()
            },
            center.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: NSApp,
                queue: .main
            ) { [weak self] _ in
                self?.rebuildAndPresent()
            }
        ]

        rebuildAndPresent()
    }

    func showTouchBar() {
        presentCurrentBar()
    }

    func stop() {
        guard isStarted else { return }

        NSTouchBar.dismissSystemModalTouchBar(touchBar)
        DFRElementSetControlStripPresenceForIdentifier(.pokiSitelenTray, false)

        if let trayItem {
            NSTouchBarItem.removeSystemTrayItem(trayItem)
        }

        trayItem = nil

        for observer in activationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        activationObservers.removeAll()

        isStarted = false
    }

    private func rebuildAndPresent() {
        let bar = NSTouchBar()
        bar.delegate = self
        // macOS supplies the native system-modal X when another application
        // is frontmost. When poki sitelen itself is frontmost, use our own
        // compact dismiss control in the special left slot instead.
        bar.escapeKeyReplacementItemIdentifier = NSApp.isActive
            ? .pokiSitelenForegroundClose
            : nil

        switch mode {
        case .toki:
            bar.defaultItemIdentifiers = [.pokiSitelenClipboard, .pokiSitelenContent]
        case .clipboard:
            bar.defaultItemIdentifiers = [.pokiSitelenToki, .pokiSitelenContent]
        }

        // The private presenter stacks system-modal bars. Dismiss the current
        // layer before replacing it so repeated poki/toki navigation still
        // leaves exactly one dismissible bar.
        NSTouchBar.dismissSystemModalTouchBar(touchBar)
        touchBar = bar
        presentCurrentBar()
    }

    @objc private func presentCurrentBar() {
        guard isStarted else { return }

        // Re-presenting an already visible bar creates another modal layer.
        // Normalize to one layer for both navigation and Control Strip restores.
        NSTouchBar.dismissSystemModalTouchBar(touchBar)
        NSTouchBar.presentSystemModalTouchBar(
            touchBar,
            systemTrayItemIdentifier: .pokiSitelenTray
        )
        DFRElementSetControlStripPresenceForIdentifier(.pokiSitelenTray, true)
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        switch identifier {
        case .pokiSitelenForegroundClose:
            let item = compactButtonItem(
                identifier: identifier,
                title: "×",
                width: 34,
                action: #selector(dismissForRealEscape)
            )
            item.view.toolTip = "Close poki sitelen and reveal the normal Touch Bar"
            return item

        case .pokiSitelenClipboard:
            let item = compactButtonItem(
                identifier: identifier,
                title: "poki",
                width: 54,
                action: #selector(showClipboard)
            )
            item.view.toolTip = "Open clipboard history"
            return item

        case .pokiSitelenToki:
            let item = compactButtonItem(
                identifier: identifier,
                title: "toki",
                width: 54,
                action: #selector(showToki)
            )
            item.view.toolTip = "Return to Toki Pona"
            return item

        case .pokiSitelenContent:
            return contentItem(identifier: identifier)

        default:
            return nil
        }
    }

    private func contentItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let width: CGFloat = 620
        let frame = NSRect(x: 0, y: 0, width: width, height: 30)

        let content: NSView
        switch mode {
        case .toki:
            content = TokiPonaStudyView(frame: frame)
        case .clipboard:
            content = PokiSitelenClipboardView(frame: frame, store: clipboardStore)
        }

        item.view = FixedPokiSitelenView(content: content, width: width)
        item.visibilityPriority = .high
        return item
    }

    private func compactButtonItem(
        identifier: NSTouchBarItem.Identifier,
        title: String,
        width: CGFloat,
        action: Selector
    ) -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let host = FixedPokiSitelenButtonHost(width: width)
        let button = NSButton(title: title, target: self, action: action)

        button.frame = NSRect(x: 0, y: 1, width: width, height: 28)
        button.font = .systemFont(
            ofSize: identifier == .pokiSitelenForegroundClose ? 13 : 11
        )

        host.addSubview(button)
        item.view = host
        item.visibilityPriority = .high
        return item
    }

    @objc private func dismissForRealEscape() {
        NSTouchBar.dismissSystemModalTouchBar(touchBar)
        DFRElementSetControlStripPresenceForIdentifier(.pokiSitelenTray, true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard self?.isStarted == true else { return }
            DFRElementSetControlStripPresenceForIdentifier(.pokiSitelenTray, true)
        }
    }

    @objc private func showClipboard() {
        mode = .clipboard
        rebuildAndPresent()
    }

    @objc private func showToki() {
        mode = .toki
        rebuildAndPresent()
    }

}

private final class FixedPokiSitelenButtonHost: NSView {
    private let fixedSize: NSSize

    init(width: CGFloat) {
        fixedSize = NSSize(width: width, height: 30)
        super.init(frame: NSRect(origin: .zero, size: fixedSize))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        fixedSize
    }
}

private final class FixedPokiSitelenView: NSView {
    init(content: NSView, width: CGFloat) {
        let size = NSSize(width: width, height: 30)
        super.init(frame: NSRect(origin: .zero, size: size))

        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
