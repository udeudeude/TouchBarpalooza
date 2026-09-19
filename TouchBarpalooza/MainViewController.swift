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

    private var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    override func loadView() {
        let root = TouchBarHostView()
        root.wantsLayer = true

        let title = NSTextField(labelWithString: "TouchBarpalooza")
        title.font = .systemFont(ofSize: 26, weight: .semibold)
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = NSTextField(
            labelWithString: "Version \(shortVersion). The interesting part is on the Touch Bar."
        )
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

    override func makeTouchBar() -> NSTouchBar? {
        // The persistent system-modal controller owns TouchBarpalooza's UI.
        // Do not leave a second responder-chain Touch Bar underneath it, or
        // dismissing the modal bar reveals the obsolete prototype launcher.
        nil
    }


}
