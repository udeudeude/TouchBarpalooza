import AppKit
import CoreGraphics

final class ClipboardShelfView: NSView {
    private static let defaultsKey = "TouchBarpalooza.ClipboardHistory"
    private static let maximumHistoryCount = 12

    private var history: [String] = UserDefaults.standard.stringArray(forKey: ClipboardShelfView.defaultsKey) ?? []
    private var buttons: [NSButton] = []
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var lastExternalPID: pid_t?

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

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        trackFrontmostApplication()
        buildButtons()
        refreshButtons()
        capturePasteboard()
        startPolling()
    }

    deinit { timer?.invalidate() }

    private func buildButtons() {
        for index in 0..<6 {
            let button = NSButton(title: "—", target: self, action: #selector(choose(_:)))
            button.tag = index
            button.font = .systemFont(ofSize: 9)
            button.lineBreakMode = .byTruncatingTail
            button.autoresizingMask = [.height]
            button.toolTip = "Paste this clipping"
            buttons.append(button)
            addSubview(button)
        }
    }

    override func layout() {
        super.layout()
        guard !buttons.isEmpty else { return }
        let gap: CGFloat = 4
        let width = max(30, (bounds.width - gap * CGFloat(buttons.count - 1)) / CGFloat(buttons.count))
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
        let t = Timer(timeInterval: 0.45, repeats: true) { [weak self] _ in
            self?.trackFrontmostApplication()
            self?.capturePasteboard()
        }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    private func trackFrontmostApplication() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let myPID = ProcessInfo.processInfo.processIdentifier
        if app.processIdentifier != myPID {
            lastExternalPID = app.processIdentifier
        }
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
                button.title = normalized.count > 22 ? String(normalized.prefix(21)) + "…" : normalized
                button.toolTip = "Paste: " + history[index]
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

        trackFrontmostApplication()
        let targetPID = lastExternalPID
        let chosen = history[sender.tag]

        history.remove(at: sender.tag)
        history.insert(chosen, at: 0)
        saveHistory()
        refreshButtons()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(chosen, forType: .string)
        lastChangeCount = pasteboard.changeCount

        pasteIntoTarget(pid: targetPID)
    }

    private func pasteIntoTarget(pid: pid_t?) {
        // Do not gate this on CGPreflightPostEventAccess(). On Xcode-launched
        // builds macOS can report a stale preflight result even while the current
        // TouchBarpalooza entry is enabled in Accessibility. Posting the event is
        // harmless when permission is absent and actually works when TCC allows it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard let source = CGEventSource(stateID: .combinedSessionState),
                  let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return }

            down.flags = .maskCommand
            up.flags = .maskCommand

            if let pid {
                down.postToPid(pid)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
                    up.postToPid(pid)
                }
            } else {
                down.post(tap: .cghidEventTap)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
                    up.post(tap: .cghidEventTap)
                }
            }
        }
    }
}
