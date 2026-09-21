import AppKit

final class MainViewController: NSViewController {
    private var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 340))
        root.wantsLayer = true

        let title = NSTextField(labelWithString: "TouchBarpalooza")
        title.font = .systemFont(ofSize: 28, weight: .semibold)
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = NSTextField(
            labelWithString: "Version \(shortVersion) is running on your Touch Bar."
        )
        subtitle.font = .systemFont(ofSize: 14)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let instructions = NSTextField(wrappingLabelWithString: """
        1. Use the buttons directly on the Touch Bar.
        2. Tap × to temporarily dismiss TouchBarpalooza and return to the normal Touch Bar.
        3. Tap ⌂ in the Control Strip, or the ⌂ menu-bar icon, to bring TouchBarpalooza back.

        """)
        instructions.font = .systemFont(ofSize: 13)
        instructions.alignment = .left
        instructions.translatesAutoresizingMaskIntoConstraints = false

        let note = NSTextField(
            wrappingLabelWithString: "Requires a physical Touch Bar. TouchBarpalooza uses private macOS Touch Bar interfaces, so behavior on other Mac models and macOS versions is not yet verified."
        )
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.alignment = .center
        note.translatesAutoresizingMaskIntoConstraints = false

        let closeHint = NSTextField(
            labelWithString: "You can close this window. TouchBarpalooza keeps running from the menu bar."
        )
        closeHint.font = .systemFont(ofSize: 11)
        closeHint.textColor = .tertiaryLabelColor
        closeHint.alignment = .center
        closeHint.translatesAutoresizingMaskIntoConstraints = false

        for subview in [title, subtitle, instructions, note, closeHint] {
            root.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 30),
            title.centerXAnchor.constraint(equalTo: root.centerXAnchor),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            subtitle.centerXAnchor.constraint(equalTo: root.centerXAnchor),

            instructions.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 24),
            instructions.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 54),
            instructions.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -54),

            note.topAnchor.constraint(equalTo: instructions.bottomAnchor, constant: 22),
            note.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 42),
            note.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -42),

            closeHint.topAnchor.constraint(equalTo: note.bottomAnchor, constant: 18),
            closeHint.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            closeHint.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -22)
        ])

        preferredContentSize = NSSize(width: 620, height: 340)
        view = root
    }

    override func makeTouchBar() -> NSTouchBar? {
        // The persistent system-modal controller is TouchBarpalooza's only
        // Touch Bar host. Returning nil prevents the obsolete prototype bar
        // from appearing after the system-modal bar is dismissed.
        nil
    }
}
