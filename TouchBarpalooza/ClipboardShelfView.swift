import AppKit

final class ClipboardShelfView: NSView {
    private static let defaultsKey = "TouchBarpalooza.ClipboardHistory"
    private static let maximumHistoryCount = 12
    private static let visibleItemCount = 6

    private var history: [String] = []
    private var buttons: [NSButton] = []
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    override var intrinsicContentSize: NSSize { NSSize(width: 690, height: 30) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        timer?.invalidate()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        history = Self.cleanedHistory(
            UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
        )

        buildButtons()
        capturePasteboard(force: true)
        refreshButtons()
        startPolling()
    }

    private static func cleanedHistory(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for item in items where !item.isEmpty {
            guard seen.insert(item).inserted else { continue }
            result.append(item)
            if result.count == maximumHistoryCount { break }
        }

        return result
    }

    private func buildButtons() {
        for index in 0..<Self.visibleItemCount {
            let button = NSButton(title: "—", target: self, action: #selector(choose(_:)))
            button.tag = index
            button.font = .systemFont(ofSize: 9)
            button.lineBreakMode = .byTruncatingTail
            button.autoresizingMask = [.height]
            buttons.append(button)
            addSubview(button)
        }
    }

    override func layout() {
        super.layout()
        guard !buttons.isEmpty else { return }

        let gap: CGFloat = 4
        let totalGap = gap * CGFloat(buttons.count - 1)
        let width = max(30, (bounds.width - totalGap) / CGFloat(buttons.count))

        for (index, button) in buttons.enumerated() {
            button.frame = NSRect(
                x: CGFloat(index) * (width + gap),
                y: 1,
                width: width,
                height: max(26, bounds.height - 2)
            )
        }
    }

    private func startPolling() {
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.capturePasteboard()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func capturePasteboard(force: Bool = false) {
        let pasteboard = NSPasteboard.general
        guard force || pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }
        promote(text)
    }

    private func promote(_ text: String) {
        if history.first == text { return }

        history.removeAll { $0 == text }
        history.insert(text, at: 0)

        if history.count > Self.maximumHistoryCount {
            history.removeLast(history.count - Self.maximumHistoryCount)
        }

        saveHistory()
        refreshButtons()
    }

    private func saveHistory() {
        UserDefaults.standard.set(history, forKey: Self.defaultsKey)
    }

    private func refreshButtons() {
        for (index, button) in buttons.enumerated() {
            guard index < history.count else {
                button.title = "—"
                button.toolTip = nil
                button.isEnabled = false
                continue
            }

            let text = history[index]
            let normalized = text.replacingOccurrences(of: "\n", with: " ↵ ")
            button.title = normalized.count > 22 ? String(normalized.prefix(21)) + "…" : normalized
            button.toolTip = index == 0
                ? "Current clipboard: \(text)"
                : "Make this the current clipboard: \(text)"
            button.isEnabled = true
        }
    }

    @objc private func choose(_ sender: NSButton) {
        guard history.indices.contains(sender.tag) else { return }

        let text = history[sender.tag]
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard pasteboard.setString(text, forType: .string) else { return }
        lastChangeCount = pasteboard.changeCount
        promote(text)
    }
}
