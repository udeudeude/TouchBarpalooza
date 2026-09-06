import AppKit

private extension NSTouchBarItem.Identifier {
    static let touchBarpaloozaTray = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.tray")
    static let touchBarpaloozaHome = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.home")
    static let touchBarpaloozaLemmings = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.lemmings")
    static let touchBarpaloozaMeters = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.meters")
    static let touchBarpaloozaClipboard = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.clipboard")
    static let touchBarpaloozaNotes = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.notes")
    static let touchBarpaloozaAbout = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.about")
    static let touchBarpaloozaCanvas = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.canvas")
    static let touchBarpaloozaPlaceholder = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.placeholder")
}

final class GlobalTouchBarController: NSObject, NSTouchBarDelegate {
    private enum Mode {
        case home
        case lemmings
        case placeholder(String)
    }

    private var mode: Mode = .home
    private var touchBar = NSTouchBar()
    private var trayItem: NSCustomTouchBarItem?
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true

        DFRSystemModalShowsCloseBoxWhenFrontMost(false)

        let trayItem = NSCustomTouchBarItem(identifier: .touchBarpaloozaTray)
        let trayButton = NSButton(title: "TP", target: self, action: #selector(presentCurrentBar))
        trayButton.toolTip = "Show TouchBarpalooza"
        trayItem.view = trayButton
        self.trayItem = trayItem

        NSTouchBarItem.addSystemTrayItem(trayItem)
        DFRElementSetControlStripPresenceForIdentifier(.touchBarpaloozaTray, true)

        rebuildAndPresent()
    }

    func stop() {
        guard isStarted else { return }

        NSTouchBar.dismissSystemModalTouchBar(touchBar)
        DFRElementSetControlStripPresenceForIdentifier(.touchBarpaloozaTray, false)

        if let trayItem {
            NSTouchBarItem.removeSystemTrayItem(trayItem)
        }

        trayItem = nil
        isStarted = false
    }

    private func rebuildAndPresent() {
        let bar = NSTouchBar()
        bar.delegate = self

        switch mode {
        case .home:
            bar.defaultItemIdentifiers = [
                .touchBarpaloozaLemmings,
                .touchBarpaloozaMeters,
                .touchBarpaloozaClipboard,
                .touchBarpaloozaNotes,
                .touchBarpaloozaAbout
            ]

        case .lemmings:
            // Put Home in the escape-key slot so the animation can own the
            // full normal Touch Bar region. System-modal bars are fussier
            // about sizing custom items than foreground responder-chain bars.
            bar.escapeKeyReplacementItemIdentifier = .touchBarpaloozaHome
            bar.defaultItemIdentifiers = [.touchBarpaloozaCanvas]
            bar.principalItemIdentifier = .touchBarpaloozaCanvas

        case .placeholder:
            bar.escapeKeyReplacementItemIdentifier = .touchBarpaloozaHome
            bar.defaultItemIdentifiers = [.touchBarpaloozaPlaceholder]
            bar.principalItemIdentifier = .touchBarpaloozaPlaceholder
        }

        touchBar = bar
        presentCurrentBar()
    }

    @objc private func presentCurrentBar() {
        guard isStarted else { return }
        NSTouchBar.presentSystemModalTouchBar(
            touchBar,
            systemTrayItemIdentifier: .touchBarpaloozaTray
        )
        DFRElementSetControlStripPresenceForIdentifier(.touchBarpaloozaTray, true)
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        switch identifier {
        case .touchBarpaloozaHome:
            return buttonItem(identifier: identifier, title: "⌂", action: #selector(showHome))

        case .touchBarpaloozaLemmings:
            return buttonItem(identifier: identifier, title: "Lemmings", action: #selector(showLemmings))

        case .touchBarpaloozaMeters:
            return buttonItem(identifier: identifier, title: "Meters", action: #selector(showMeters))

        case .touchBarpaloozaClipboard:
            return buttonItem(identifier: identifier, title: "Clipboard", action: #selector(showClipboard))

        case .touchBarpaloozaNotes:
            return buttonItem(identifier: identifier, title: "Notes", action: #selector(showNotes))

        case .touchBarpaloozaAbout:
            return buttonItem(identifier: identifier, title: "About", action: #selector(showAbout))

        case .touchBarpaloozaCanvas:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let view = LemmingsView(frame: NSRect(x: 0, y: 0, width: 700, height: 30))
            view.autoresizingMask = [.width, .height]
            item.view = view
            return item

        case .touchBarpaloozaPlaceholder:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let label = NSTextField(labelWithString: placeholderText)
            label.alignment = .center
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.frame = NSRect(x: 0, y: 0, width: 500, height: 30)
            item.view = label
            return item

        default:
            return nil
        }
    }

    private func buttonItem(
        identifier: NSTouchBarItem.Identifier,
        title: String,
        action: Selector
    ) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.view = NSButton(title: title, target: self, action: action)
        return item
    }

    private var placeholderText: String {
        if case let .placeholder(name) = mode {
            return "\(name) is reserved for a future TouchBarpalooza module."
        }
        return ""
    }

    @objc private func showHome() {
        mode = .home
        rebuildAndPresent()
    }

    @objc private func showLemmings() {
        mode = .lemmings
        rebuildAndPresent()
    }

    @objc private func showMeters() {
        mode = .placeholder("Meters")
        rebuildAndPresent()
    }

    @objc private func showClipboard() {
        mode = .placeholder("Clipboard")
        rebuildAndPresent()
    }

    @objc private func showNotes() {
        mode = .placeholder("Notes")
        rebuildAndPresent()
    }

    @objc private func showAbout() {
        mode = .placeholder("TouchBarpalooza standalone host")
        rebuildAndPresent()
    }
}
