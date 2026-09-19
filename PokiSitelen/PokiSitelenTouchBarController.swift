import AppKit

private extension NSTouchBarItem.Identifier {
    static let pokiSitelenTray = NSTouchBarItem.Identifier("com.udeudeude.PokiSitelen.tray")
    static let pokiSitelenQuit = NSTouchBarItem.Identifier("com.udeudeude.PokiSitelen.quit")
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

    func start() {
        guard !isStarted else { return }
        isStarted = true

        DFRSystemModalShowsCloseBoxWhenFrontMost(false)

        let trayItem = NSCustomTouchBarItem(identifier: .pokiSitelenTray)
        let trayButton = NSButton(title: "poki", target: self, action: #selector(presentCurrentBar))
        trayButton.toolTip = "Show poki sitelen"
        trayItem.view = trayButton
        self.trayItem = trayItem

        NSTouchBarItem.addSystemTrayItem(trayItem)
        DFRElementSetControlStripPresenceForIdentifier(.pokiSitelenTray, true)

        rebuildAndPresent()
    }

    func stop() {
        guard isStarted else { return }

        NSTouchBar.dismissSystemModalTouchBar(touchBar)
        DFRElementSetControlStripPresenceForIdentifier(.pokiSitelenTray, false)

        if let trayItem {
            NSTouchBarItem.removeSystemTrayItem(trayItem)
        }

        trayItem = nil
        isStarted = false
    }

    private func rebuildAndPresent() {
        let bar = NSTouchBar()
        bar.delegate = self
        // Leave this nil so macOS supplies the real system Escape key.
        bar.escapeKeyReplacementItemIdentifier = nil

        switch mode {
        case .toki:
            bar.defaultItemIdentifiers = [.pokiSitelenQuit, .pokiSitelenClipboard, .pokiSitelenContent]
        case .clipboard:
            bar.defaultItemIdentifiers = [.pokiSitelenQuit, .pokiSitelenToki, .pokiSitelenContent]
        }

        touchBar = bar
        presentCurrentBar()
    }

    @objc private func presentCurrentBar() {
        guard isStarted else { return }

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
        case .pokiSitelenQuit:
            let item = compactButtonItem(
                identifier: identifier,
                title: "ⓧ",
                width: 28,
                action: #selector(quitPokiSitelen)
            )
            item.view.toolTip = "Quit poki sitelen"
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
        button.font = .systemFont(ofSize: identifier == .pokiSitelenQuit ? 13 : 11)

        host.addSubview(button)
        item.view = host
        item.visibilityPriority = .high
        return item
    }

    @objc private func showClipboard() {
        mode = .clipboard
        rebuildAndPresent()
    }

    @objc private func showToki() {
        mode = .toki
        rebuildAndPresent()
    }

    @objc private func quitPokiSitelen() {
        stop()
        NSApp.terminate(nil)
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
