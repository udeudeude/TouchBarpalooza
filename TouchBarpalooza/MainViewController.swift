import AppKit

private extension NSTouchBar.CustomizationIdentifier {
    static let touchBarpalooza = NSTouchBar.CustomizationIdentifier("com.udeudeude.TouchBarpalooza")
}

private extension NSTouchBarItem.Identifier {
    static let home = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.home")
    static let lemmings = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.lemmings")
    static let meters = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.meters")
    static let clipboard = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.clipboard")
    static let notes = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.notes")
    static let about = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.about")
    static let canvas = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.canvas")
    static let placeholder = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.placeholder")
}

private final class TouchBarHostView: NSView {
    override var acceptsFirstResponder: Bool { true }
}

final class MainViewController: NSViewController, NSTouchBarDelegate {
    private enum Mode {
        case home
        case lemmings
        case placeholder(String)
    }

    private var mode: Mode = .home

    override func loadView() {
        let root = TouchBarHostView()
        root.wantsLayer = true

        let title = NSTextField(labelWithString: "TouchBarpalooza")
        title.font = .systemFont(ofSize: 26, weight: .semibold)
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = NSTextField(labelWithString: "The interesting part is on the Touch Bar.")
        subtitle.font = .systemFont(ofSize: 14)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(title)
        root.addSubview(subtitle)

        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: root.centerYAnchor, constant: -16),
            subtitle.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10)
        ])

        self.view = root
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        installTouchBar()
    }

    override func makeTouchBar() -> NSTouchBar? {
        buildTouchBar()
    }

    private func installTouchBar() {
        let bar = buildTouchBar()

        // Put the same bar on every responder that can plausibly win the
        // Touch Bar lookup. Most importantly, the root view explicitly
        // accepts first-responder status and owns this bar directly.
        touchBar = bar
        view.touchBar = bar
        view.window?.touchBar = bar
        view.window?.makeFirstResponder(view)

        print("TouchBarpalooza: first responder is host view = \(view.window?.firstResponder === view)")
    }

    private func buildTouchBar() -> NSTouchBar {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.customizationIdentifier = .touchBarpalooza

        switch mode {
        case .home:
            bar.defaultItemIdentifiers = [.lemmings, .meters, .clipboard, .notes, .about]
        case .lemmings:
            bar.escapeKeyReplacementItemIdentifier = .home
            bar.defaultItemIdentifiers = [.canvas]
            bar.principalItemIdentifier = .canvas
        case .placeholder:
            bar.escapeKeyReplacementItemIdentifier = .home
            bar.defaultItemIdentifiers = [.placeholder]
            bar.principalItemIdentifier = .placeholder
        }
        return bar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .home:
            return buttonItem(identifier: identifier, title: "⌂", action: #selector(showHome))
        case .lemmings:
            return buttonItem(identifier: identifier, title: "Lemmings", action: #selector(showLemmings))
        case .meters:
            return buttonItem(identifier: identifier, title: "Meters", action: #selector(showMeters))
        case .clipboard:
            return buttonItem(identifier: identifier, title: "Clipboard", action: #selector(showClipboard))
        case .notes:
            return buttonItem(identifier: identifier, title: "Notes", action: #selector(showNotes))
        case .about:
            return buttonItem(identifier: identifier, title: "About", action: #selector(showAbout))
        case .canvas:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let lemmings = LemmingsView(frame: NSRect(x: 0, y: 0, width: 700, height: 30))
            lemmings.translatesAutoresizingMaskIntoConstraints = false
            lemmings.widthAnchor.constraint(greaterThanOrEqualToConstant: 650).isActive = true
            lemmings.heightAnchor.constraint(equalToConstant: 30).isActive = true
            item.view = lemmings
            return item
        case .placeholder:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let label = NSTextField(labelWithString: placeholderText)
            label.alignment = .center
            label.font = .systemFont(ofSize: 14, weight: .medium)
            item.view = label
            return item
        default:
            return nil
        }
    }

    private var placeholderText: String {
        if case let .placeholder(name) = mode {
            return "\(name) is reserved for the next TouchBarpalooza experiment."
        }
        return ""
    }

    private func buttonItem(identifier: NSTouchBarItem.Identifier, title: String, action: Selector) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.view = NSButton(title: title, target: self, action: action)
        return item
    }

    @objc private func showHome() {
        mode = .home
        installTouchBar()
    }

    @objc private func showLemmings() {
        mode = .lemmings
        installTouchBar()
    }

    @objc private func showMeters() {
        mode = .placeholder("Meters")
        installTouchBar()
    }

    @objc private func showClipboard() {
        mode = .placeholder("Clipboard")
        installTouchBar()
    }

    @objc private func showNotes() {
        mode = .placeholder("Notes")
        installTouchBar()
    }

    @objc private func showAbout() {
        mode = .placeholder("TouchBarpalooza v0.1")
        installTouchBar()
    }
}
