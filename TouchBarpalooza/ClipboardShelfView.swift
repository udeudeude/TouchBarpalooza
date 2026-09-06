import AppKit

final class ClipboardShelfView: NSView {
    private static let defaultsKey = "TouchBarpalooza.ClipboardHistory"
    private static let maximumHistoryCount = 12

    private var history: [String] = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
    private var buttons: [NSButton] = []
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
        refreshButtons()
        capturePasteboard()
        startPolling()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
        refreshButtons()
        capturePasteboard()
        startPolling()
    }

    deinit { timer?.invalidate() }

    private func buildUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 5
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        for index in 0..<6 {
            let button = NSButton(title: "—", target: self, action: #selector(choose(_:)))
            button.tag = index
            button.font = .systemFont(ofSize: 10)
            button.lineBreakMode = .byTruncatingTail
            buttons.append(button)
            stack.addArrangedSubview(button)
        }
    }

    private func startPolling() {
        let newTimer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.capturePasteboard() }
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }

    private func capturePasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount || history.isEmpty else { return }
        lastChangeCount = pasteboard.changeCount
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }

        if history.first != text {
            history.removeAll(where: { $0 == text })
            history.insert(text, at: 0)
            if history.count > Self.maximumHistoryCount {
                history.removeLast(history.count - Self.maximumHistoryCount)
            }
            saveHistory()
        }
        refreshButtons()
    }

    private func saveHistory() {
        UserDefaults.standard.set(history, forKey: Self.defaultsKey)
    }

    private func refreshButtons() {
        for (index, button) in buttons.enumerated() {
            if index < history.count {
                let normalized = history[index].replacingOccurrences(of: "\n", with: " ↵ ")
                button.title = normalized.count > 26 ? String(normalized.prefix(25)) + "…" : normalized
                button.toolTip = history[index]
                button.isEnabled = true
            } else {
                button.title = "—"
                button.toolTip = nil
                button.isEnabled = false
            }
        }
    }

    @objc private func choose(_ sender: NSButton) {
        guard sender.tag < history.count else { return }
        let chosen = history[sender.tag]

        history.remove(at: sender.tag)
        history.insert(chosen, at: 0)
        saveHistory()
        refreshButtons()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(chosen, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }
}
