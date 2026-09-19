import AppKit

final class ClipboardHistoryStore {
    static let capacity = 6

    private let defaultsKey = "PokiSitelen.ClipboardHistory"
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    private(set) var history: [String] = []

    init() {
        history = Self.cleanedHistory(
            UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        )
        saveHistory()
        capturePasteboard(force: true)
        startPolling()
    }

    deinit {
        timer?.invalidate()
    }

    func item(at index: Int) -> String? {
        guard history.indices.contains(index) else { return nil }
        return history[index]
    }

    func select(_ index: Int) {
        guard let text = item(at: index) else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard pasteboard.setString(text, forType: .string) else { return }
        lastChangeCount = pasteboard.changeCount
        promote(text)
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

        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            return
        }

        promote(text)
    }

    private func promote(_ text: String) {
        if history.first == text {
            return
        }

        history.removeAll { $0 == text }
        history.insert(text, at: 0)

        if history.count > Self.capacity {
            history.removeLast(history.count - Self.capacity)
        }

        saveHistory()
        NotificationCenter.default.post(name: .pokiSitelenClipboardHistoryChanged, object: self)
    }

    private func saveHistory() {
        UserDefaults.standard.set(history, forKey: defaultsKey)
    }

    private static func cleanedHistory(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for item in items where !item.isEmpty {
            guard seen.insert(item).inserted else { continue }
            result.append(item)
            if result.count == capacity {
                break
            }
        }

        return result
    }
}

extension Notification.Name {
    static let pokiSitelenClipboardHistoryChanged =
        Notification.Name("PokiSitelenClipboardHistoryChanged")
}

final class PokiSitelenClipboardView: NSView {
    private let store: ClipboardHistoryStore
    private var buttons: [NSButton] = []
    private var observer: NSObjectProtocol?

    override var intrinsicContentSize: NSSize {
        NSSize(width: 620, height: 30)
    }

    init(frame frameRect: NSRect, store: ClipboardHistoryStore) {
        self.store = store
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        for index in 0..<ClipboardHistoryStore.capacity {
            let button = NSButton(title: "—", target: self, action: #selector(choose(_:)))
            button.tag = index
            button.font = .systemFont(ofSize: 9)
            button.lineBreakMode = .byTruncatingTail
            button.autoresizingMask = [.height]
            buttons.append(button)
            addSubview(button)
        }

        observer = NotificationCenter.default.addObserver(
            forName: .pokiSitelenClipboardHistoryChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            self?.refreshButtons()
        }

        refreshButtons()
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

    private func refreshButtons() {
        for (index, button) in buttons.enumerated() {
            guard let text = store.item(at: index) else {
                button.title = "—"
                button.toolTip = nil
                button.isEnabled = false
                continue
            }

            let normalized = text.replacingOccurrences(of: "\n", with: " ↵ ")
            button.title = normalized.count > 22
                ? String(normalized.prefix(21)) + "…"
                : normalized
            button.toolTip = index == 0
                ? "Current clipboard: \(text)"
                : "Make this the current clipboard: \(text)"
            button.isEnabled = true
        }
    }

    @objc private func choose(_ sender: NSButton) {
        store.select(sender.tag)
        refreshButtons()
    }
}
