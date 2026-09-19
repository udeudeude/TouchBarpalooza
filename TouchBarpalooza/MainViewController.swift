import AppKit

final class MainViewController: NSViewController {
    private var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    override func loadView() {
        let root = NSView()
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

        view = root
    }

    override func makeTouchBar() -> NSTouchBar? {
        // The persistent system-modal controller is TouchBarpalooza's only
        // Touch Bar host. Returning nil prevents the obsolete prototype bar
        // from appearing after the system-modal bar is dismissed.
        nil
    }
}
