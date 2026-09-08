import AppKit
import CoreGraphics
import ApplicationServices

private extension NSTouchBarItem.Identifier {
    static let tbp2Tray = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.v2.tray")
    static let tbp2Esc = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.v2.esc")
    static let tbp2Quit = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.v2.quit")
    static let tbp2Home = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.v2.home")
    static let tbp2Launcher = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.v2.launcher")
    static let tbp2LemmingsPlay = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.v2.lemmings.play")
    static let tbp2LemmingsDemo = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.v2.lemmings.demo")
    static let tbp2LemmingsControls = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.v2.lemmings.controls")
    static let tbp2Games = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.v2.games")
    static let tbp2Content = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.v2.content")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var controller: MainViewController?
    private let globalTouchBarController = TBPGlobalTouchBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestInputPermissionsIfNeeded()

        let controller = MainViewController()
        self.controller = controller

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 220),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TouchBarpalooza"
        window.center()
        window.contentViewController = controller
        window.makeKeyAndOrderFront(nil)
        self.window = window

        globalTouchBarController.start()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func requestInputPermissionsIfNeeded() {
        if !CGPreflightListenEventAccess() { _ = CGRequestListenEventAccess() }
        if !CGPreflightPostEventAccess() { _ = CGRequestPostEventAccess() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalTouchBarController.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}

private final class TBPGlobalTouchBarController: NSObject, NSTouchBarDelegate {
    private enum Mode {
        case home, lemmingsMenu, lemmingsPlay, lemmingsDemo, clipboard, spectrum, midi
        case gamesMenu, life, pong, adventure, breakout, snake, pitfall, et
        case kitt, tokiPona, pond
    }

    private var mode: Mode = .home
    private var touchBar = NSTouchBar()
    private var trayItem: NSCustomTouchBarItem?
    private var isStarted = false
    private weak var currentLemmingsView: LemmingsView?
    private var skillButtons: [NSButton] = []

    func start() {
        guard !isStarted else { return }
        isStarted = true
        DFRSystemModalShowsCloseBoxWhenFrontMost(false)

        let trayItem = NSCustomTouchBarItem(identifier: .tbp2Tray)
        let trayButton = NSButton(title: "TP", target: self, action: #selector(presentCurrentBar))
        trayButton.toolTip = "Show TouchBarpalooza"
        trayItem.view = trayButton
        self.trayItem = trayItem
        NSTouchBarItem.addSystemTrayItem(trayItem)
        DFRElementSetControlStripPresenceForIdentifier(.tbp2Tray, true)
        rebuildAndPresent()
    }

    func stop() {
        guard isStarted else { return }
        NSTouchBar.dismissSystemModalTouchBar(touchBar)
        DFRElementSetControlStripPresenceForIdentifier(.tbp2Tray, false)
        if let trayItem { NSTouchBarItem.removeSystemTrayItem(trayItem) }
        trayItem = nil
        isStarted = false
    }

    private func rebuildAndPresent() {
        currentLemmingsView = nil
        skillButtons.removeAll()
        let bar = NSTouchBar()
        bar.delegate = self
        // On a Touch Bar Mac there is no physical Escape key, so always reserve
        // the real Escape-key slot for our explicit ESC item.
        bar.escapeKeyReplacementItemIdentifier = .tbp2Esc

        switch mode {
        case .home:
            bar.defaultItemIdentifiers = [.tbp2Quit, .tbp2Launcher]
        case .lemmingsMenu:
            bar.defaultItemIdentifiers = [.tbp2Home, .tbp2LemmingsPlay, .tbp2LemmingsDemo]
        case .lemmingsPlay:
            bar.defaultItemIdentifiers = [.tbp2Home, .tbp2LemmingsControls, .tbp2Content]
        case .lemmingsDemo:
            bar.defaultItemIdentifiers = [.tbp2Home, .tbp2Content]
        case .gamesMenu:
            bar.defaultItemIdentifiers = [.tbp2Home, .tbp2Games]
        default:
            bar.defaultItemIdentifiers = [.tbp2Home, .tbp2Content]
        }

        touchBar = bar
        presentCurrentBar()
    }

    @objc private func presentCurrentBar() {
        guard isStarted else { return }
        NSTouchBar.presentSystemModalTouchBar(touchBar, systemTrayItemIdentifier: .tbp2Tray)
        DFRElementSetControlStripPresenceForIdentifier(.tbp2Tray, true)
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .tbp2Esc:
            let item = buttonItem(identifier, title: "esc", action: #selector(sendEscape))
            item.visibilityPriority = .high
            return item
        case .tbp2Quit:
            let item = buttonItem(identifier, title: "ⓧ", action: #selector(quitApp))
            item.visibilityPriority = .high
            return item
        case .tbp2Home:
            let item = buttonItem(identifier, title: "⌂", action: #selector(showHome))
            item.visibilityPriority = .high
            return item
        case .tbp2Launcher:
            return launcherItem(identifier)
        case .tbp2LemmingsPlay:
            return buttonItem(identifier, title: "PLAY", action: #selector(startLemmingsPlay))
        case .tbp2LemmingsDemo:
            return buttonItem(identifier, title: "DEMO", action: #selector(startLemmingsDemo))
        case .tbp2LemmingsControls:
            return lemmingsControls(identifier)
        case .tbp2Games:
            return gamesItem(identifier)
        case .tbp2Content:
            return contentItem(identifier)
        default:
            return nil
        }
    }

    private func launcherItem(_ identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let view = TBPFixedView(size: NSSize(width: 622, height: 30))
        let specs: [(String, Selector, CGFloat)] = [
            ("Lemmings", #selector(showLemmingsMenu), 78),
            ("Clips", #selector(showClipboard), 58),
            ("Spectrum", #selector(showSpectrum), 78),
            ("MIDI", #selector(showMIDI), 52),
            ("Games", #selector(showGames), 62),
            ("KITT", #selector(showKITT), 52),
            ("Toki", #selector(showTokiPona), 52),
            ("Pond", #selector(showPond), 58)
        ]
        var x: CGFloat = 0
        for (title, action, width) in specs {
            let button = NSButton(title: title, target: self, action: action)
            button.font = .systemFont(ofSize: 8)
            button.frame = NSRect(x: x, y: 2, width: width, height: 26)
            view.addSubview(button)
            x += width + 2
        }
        item.view = view
        item.visibilityPriority = .high
        return item
    }

    private func gamesItem(_ identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let view = TBPFixedView(size: NSSize(width: 535, height: 30))
        // Chronological first release: Life 1970, Pong 1972, Adventure 1976,
        // Breakout 1976, Blockade/Snake 1976, Pitfall! 1982, E.T. 1982.
        let specs: [(String, Selector, CGFloat)] = [
            ("Life", #selector(showLife), 66),
            ("Pong", #selector(showPong), 66),
            ("Cave", #selector(showAdventure), 66),
            ("Break", #selector(showBreakout), 70),
            ("Snake", #selector(showSnake), 70),
            ("Pit", #selector(showPitfall), 62),
            ("E.T.", #selector(showET), 62)
        ]
        var x: CGFloat = 0
        for (title, action, width) in specs {
            let button = NSButton(title: title, target: self, action: action)
            button.font = .systemFont(ofSize: 8)
            button.frame = NSRect(x: x, y: 2, width: width, height: 26)
            view.addSubview(button)
            x += width + 2
        }
        item.view = view
        return item
    }

    private func lemmingsControls(_ identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let view = TBPFixedView(size: NSSize(width: 230, height: 30))
        skillButtons.removeAll()
        var x: CGFloat = 0
        for skill in LemmingsView.Skill.allCases {
            let button = NSButton(frame: NSRect(x: x, y: 2, width: 25, height: 26))
            button.target = self
            button.action = #selector(skillPressed(_:))
            button.tag = skill.rawValue
            button.image = skillIcon(skill)
            button.imagePosition = .imageOnly
            button.toolTip = skill.shortName
            button.setButtonType(.toggle)
            button.state = skill == .builder ? .on : .off
            view.addSubview(button)
            skillButtons.append(button)
            x += 26
        }
        let nuke = NSButton(title: "☠", target: self, action: #selector(nukeLemmings))
        nuke.font = .systemFont(ofSize: 11)
        nuke.frame = NSRect(x: x + 1, y: 2, width: 22, height: 26)
        nuke.toolTip = "Nuke"
        view.addSubview(nuke)
        item.view = view
        item.visibilityPriority = .high
        return item
    }

    private func skillIcon(_ skill: LemmingsView.Skill) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        return NSImage(size: size, flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .none
            let hair = NSColor(calibratedRed: 0.18, green: 0.98, blue: 0.18, alpha: 1)
            let skin = NSColor(calibratedRed: 0.98, green: 0.76, blue: 0.58, alpha: 1)
            let blue = NSColor(calibratedRed: 0.10, green: 0.35, blue: 0.98, alpha: 1)
            let tool = NSColor(calibratedWhite: 0.92, alpha: 1)
            hair.setFill(); NSRect(x: 8, y: 15, width: 7, height: 4).fill()
            skin.setFill(); NSRect(x: 9, y: 12, width: 5, height: 4).fill()
            blue.setFill(); NSRect(x: 8, y: 7, width: 7, height: 6).fill()
            skin.setFill(); NSRect(x: 7, y: 2, width: 3, height: 6).fill(); NSRect(x: 13, y: 2, width: 3, height: 6).fill()
            tool.setStroke(); tool.setFill()
            switch skill {
            case .climber:
                NSRect(x: 18, y: 2, width: 2, height: 18).fill()
                NSRect(x: 14, y: 12, width: 5, height: 2).fill()
            case .floater:
                let p = NSBezierPath(); p.move(to: NSPoint(x: 3, y: 18)); p.curve(to: NSPoint(x: 20, y: 18), controlPoint1: NSPoint(x: 7, y: 23), controlPoint2: NSPoint(x: 16, y: 23)); p.lineWidth = 1.5; p.stroke()
                NSRect(x: 11, y: 13, width: 1.5, height: 6).fill()
            case .bomber:
                NSColor(calibratedRed: 0.95, green: 0.2, blue: 0.08, alpha: 1).setFill(); NSBezierPath(ovalIn: NSRect(x: 15, y: 8, width: 6, height: 6)).fill(); NSRect(x: 18, y: 14, width: 1, height: 3).fill()
            case .blocker:
                skin.setFill(); NSRect(x: 2, y: 10, width: 7, height: 2).fill(); NSRect(x: 14, y: 10, width: 7, height: 2).fill()
            case .builder:
                NSColor(calibratedRed: 0.9, green: 0.64, blue: 0.18, alpha: 1).setFill(); NSRect(x: 15, y: 7, width: 6, height: 2).fill(); NSRect(x: 17, y: 9, width: 5, height: 2).fill(); NSRect(x: 19, y: 11, width: 3, height: 2).fill()
            case .basher:
                NSRect(x: 15, y: 11, width: 7, height: 2).fill(); NSRect(x: 20, y: 7, width: 2, height: 10).fill()
            case .miner:
                let p = NSBezierPath(); p.move(to: NSPoint(x: 14, y: 12)); p.line(to: NSPoint(x: 20, y: 4)); p.lineWidth = 1.8; p.stroke(); NSRect(x: 16, y: 12, width: 5, height: 1.5).fill()
            case .digger:
                NSRect(x: 11, y: 0, width: 2, height: 7).fill(); NSRect(x: 8, y: 0, width: 8, height: 2).fill()
            }
            return true
        }
    }

    private func contentItem(_ identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let width: CGFloat = mode == .lemmingsPlay ? 350 : 700
        let frame = NSRect(x: 0, y: 0, width: width, height: 30)
        let content: NSView
        switch mode {
        case .lemmingsPlay:
            let view = LemmingsView(frame: frame, mode: .interactive)
            currentLemmingsView = view
            content = view
        case .lemmingsDemo:
            content = LemmingsDemoView2(frame: frame)
        case .clipboard:
            content = ClipboardShelfView2(frame: frame)
        case .spectrum:
            content = AudioVisualizerView(frame: frame)
        case .midi:
            content = MIDIControlView(frame: frame)
        case .life:
            content = LifeGameView4(frame: frame)
        case .pong:
            content = MiniGameView(frame: frame, game: .pong)
        case .adventure:
            content = AdventureTerminalView2(frame: frame)
        case .breakout:
            content = MiniGameView(frame: frame, game: .breakout)
        case .snake:
            content = MiniGameView(frame: frame, game: .snake)
        case .pitfall:
            content = PitfallGameView2(frame: frame)
        case .et:
            content = ExactETView(frame: frame)
        case .kitt:
            content = KITTScannerView(frame: frame)
        case .tokiPona:
            content = TokiPonaStudyView(frame: frame)
        case .pond:
            content = KoiPondView(frame: frame)
        default:
            content = NSView(frame: frame)
        }
        item.view = TBPContentHost(content: content, width: width)
        item.visibilityPriority = mode == .lemmingsPlay ? .normal : .high
        return item
    }

    private func buttonItem(_ identifier: NSTouchBarItem.Identifier, title: String, action: Selector) -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.view = NSButton(title: title, target: self, action: action)
        return item
    }

    @objc private func skillPressed(_ sender: NSButton) {
        guard let skill = LemmingsView.Skill(rawValue: sender.tag) else { return }
        for button in skillButtons { button.state = button === sender ? .on : .off }
        currentLemmingsView?.selectSkill(skill)
    }
    @objc private func nukeLemmings() { currentLemmingsView?.nuke() }

    @objc private func sendEscape() {
        let myPID = ProcessInfo.processInfo.processIdentifier
        if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != myPID {
            let ax = AXUIElementCreateApplication(app.processIdentifier)
            let down = AXUIElementPostKeyboardEvent(ax, 0, 53, true)
            let up = AXUIElementPostKeyboardEvent(ax, 0, 53, false)
            if down == .success && up == .success { return }
        }
        if let down = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true),
           let up = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false) {
            down.post(tap: .cgAnnotatedSessionEventTap)
            up.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    @objc private func quitApp() {
        stop()
        NSApp.terminate(nil)
    }

    @objc private func showHome() { mode = .home; rebuildAndPresent() }
    @objc private func showLemmingsMenu() { mode = .lemmingsMenu; rebuildAndPresent() }
    @objc private func startLemmingsPlay() { mode = .lemmingsPlay; rebuildAndPresent() }
    @objc private func startLemmingsDemo() { mode = .lemmingsDemo; rebuildAndPresent() }
    @objc private func showClipboard() { mode = .clipboard; rebuildAndPresent() }
    @objc private func showSpectrum() { mode = .spectrum; rebuildAndPresent() }
    @objc private func showMIDI() { mode = .midi; rebuildAndPresent() }
    @objc private func showGames() { mode = .gamesMenu; rebuildAndPresent() }
    @objc private func showLife() { mode = .life; rebuildAndPresent() }
    @objc private func showPong() { mode = .pong; rebuildAndPresent() }
    @objc private func showAdventure() { mode = .adventure; rebuildAndPresent() }
    @objc private func showBreakout() { mode = .breakout; rebuildAndPresent() }
    @objc private func showSnake() { mode = .snake; rebuildAndPresent() }
    @objc private func showPitfall() { mode = .pitfall; rebuildAndPresent() }
    @objc private func showET() { mode = .et; rebuildAndPresent() }
    @objc private func showKITT() { mode = .kitt; rebuildAndPresent() }
    @objc private func showTokiPona() { mode = .tokiPona; rebuildAndPresent() }
    @objc private func showPond() { mode = .pond; rebuildAndPresent() }
}

private final class TBPFixedView: NSView {
    private let fixedSize: NSSize
    init(size: NSSize) { fixedSize = size; super.init(frame: NSRect(origin: .zero, size: size)) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var intrinsicContentSize: NSSize { fixedSize }
}

private final class TBPContentHost: NSView {
    init(content: NSView, width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 30))
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: Clipboard shelf

private final class ClipboardShelfView2: NSView {
    private static let defaultsKey = "TouchBarpalooza.ClipboardHistory"
    private var history = UserDefaults.standard.stringArray(forKey: "TouchBarpalooza.ClipboardHistory") ?? []
    private var buttons: [NSButton] = []
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var lastExternalPID: pid_t?

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        trackTarget(); buildButtons(); capture(); startPolling()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func buildButtons() {
        for index in 0..<6 {
            let b = NSButton(title: "—", target: self, action: #selector(chosen(_:)))
            b.tag = index; b.font = .systemFont(ofSize: 9); b.lineBreakMode = .byTruncatingTail
            buttons.append(b); addSubview(b)
        }
    }

    override func layout() {
        super.layout()
        let gap: CGFloat = 3
        let w = (bounds.width - gap * 5) / 6
        for (i, b) in buttons.enumerated() { b.frame = NSRect(x: CGFloat(i) * (w + gap), y: 2, width: w, height: 26) }
    }

    private func startPolling() {
        let t = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in self?.trackTarget(); self?.capture() }
        timer = t; RunLoop.main.add(t, forMode: .common)
    }

    private func trackTarget() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        if app.processIdentifier != ProcessInfo.processInfo.processIdentifier { lastExternalPID = app.processIdentifier }
    }

    private func capture() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount || history.isEmpty else { return }
        lastChangeCount = pb.changeCount
        guard let text = pb.string(forType: .string), !text.isEmpty else { return }
        history.removeAll { $0 == text }; history.insert(text, at: 0)
        if history.count > 12 { history.removeLast(history.count - 12) }
        UserDefaults.standard.set(history, forKey: Self.defaultsKey)
        refresh()
    }

    private func refresh() {
        for (i, b) in buttons.enumerated() {
            guard i < history.count else { b.title = "—"; b.isEnabled = false; continue }
            let s = history[i].replacingOccurrences(of: "\n", with: " ↵ ")
            b.title = s.count > 22 ? String(s.prefix(21)) + "…" : s
            b.isEnabled = true
        }
    }

    @objc private func chosen(_ sender: NSButton) {
        guard sender.tag < history.count else { return }
        let text = history[sender.tag]
        history.remove(at: sender.tag); history.insert(text, at: 0)
        UserDefaults.standard.set(history, forKey: Self.defaultsKey); refresh()
        let pb = NSPasteboard.general; pb.clearContents(); pb.setString(text, forType: .string); lastChangeCount = pb.changeCount
        pasteToTarget()
    }

    private func pasteToTarget() {
        guard let pid = lastExternalPID else { return }
        NSRunningApplication(processIdentifier: pid)?.activate(options: [.activateIgnoringOtherApps])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            let ax = AXUIElementCreateApplication(pid)
            let a = AXUIElementPostKeyboardEvent(ax, 0, 55, true)
            let b = AXUIElementPostKeyboardEvent(ax, 0, 9, true)
            let c = AXUIElementPostKeyboardEvent(ax, 0, 9, false)
            let d = AXUIElementPostKeyboardEvent(ax, 0, 55, false)
            if a == .success && b == .success && c == .success && d == .success { return }
            if let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
               let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) {
                down.flags = .maskCommand; up.flags = .maskCommand
                down.post(tap: .cgAnnotatedSessionEventTap); up.post(tap: .cgAnnotatedSessionEventTap)
            }
        }
    }
}

// MARK: Life

private final class LifeStrokeSurface4: NSView {
    var handler: ((CGFloat) -> Void)?
    var ended: (() -> Void)?
    override init(frame frameRect: NSRect) { super.init(frame: frameRect); acceptsTouchEvents = true; allowedTouchTypes = [.direct]; wantsRestingTouches = true }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { handler?(convert(event.locationInWindow, from: nil).x) }
    override func mouseDragged(with event: NSEvent) { handler?(convert(event.locationInWindow, from: nil).x) }
    override func mouseUp(with event: NSEvent) { ended?() }
    override func touchesBegan(with event: NSEvent) { emit(event, .began) }
    override func touchesMoved(with event: NSEvent) { emit(event, .moved) }
    override func touchesEnded(with event: NSEvent) { emit(event, .ended); ended?() }
    override func touchesCancelled(with event: NSEvent) { ended?() }
    private func emit(_ event: NSEvent, _ phase: NSTouch.Phase) { for t in event.touches(matching: phase, in: self) { handler?(t.location(in: self).x) } }
}

private final class LifeGameView4: NSView {
    private let columns = 96, rows = 7
    private var cells = Array(repeating: Array(repeating: false, count: 7), count: 96)
    private var history: [[[Bool]]] = []
    private var running = false, drawMode = false
    private var selectedRow = 6
    private var paintValue: Bool?
    private var timer: Timer?, lastTick = ProcessInfo.processInfo.systemUptime, accumulator: TimeInterval = 0
    private var controls: [NSView] = []
    private weak var runButton: NSButton?, stroke: LifeStrokeSurface4?
    private var controlsWidth: CGFloat { drawMode ? 184 : 146 }

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect); wantsLayer = true; layer?.backgroundColor = NSColor.black.cgColor
        seed(); rebuildControls()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }; timer = t; RunLoop.main.add(t, forMode: .common)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }
    override func layout() { super.layout(); stroke?.frame = NSRect(x: controlsWidth, y: 0, width: max(1, bounds.width - controlsWidth), height: bounds.height) }

    private func naked(_ title: String, _ action: Selector, x: CGFloat, width: CGFloat = 27, size: CGFloat = 16) -> NSButton {
        let b = NSButton(title: title, target: self, action: action); b.isBordered = false; b.focusRingType = .none; b.font = .systemFont(ofSize: size); b.frame = NSRect(x: x, y: 1, width: width, height: 28); return b
    }

    private func rebuildControls() {
        controls.forEach { $0.removeFromSuperview() }; controls.removeAll(); runButton = nil; stroke = nil
        if drawMode {
            var x: CGFloat = 1
            let close = naked("✕", #selector(closeDraw), x: x, width: 27); add(close); x += 27
            for n in 1...7 {
                let b = naked("\(n)", #selector(selectRow(_:)), x: x, width: 22, size: 13)
                b.tag = n; b.state = selectedRow == 7 - n ? .on : .off; add(b); x += 22
            }
        } else {
            var x: CGFloat = 1
            let run = naked(running ? "Ⅱ" : "▶︎", #selector(toggleRun), x: x); add(run); runButton = run; x += 28
            add(naked("←", #selector(back), x: x)); x += 28
            add(naked("→", #selector(forward), x: x)); x += 28
            add(naked("🎲", #selector(randomize), x: x, size: 15)); x += 30
            add(naked("🖊️", #selector(openDraw), x: x, size: 14))
        }
        let s = LifeStrokeSurface4(frame: NSRect(x: controlsWidth, y: 0, width: max(1, bounds.width - controlsWidth), height: bounds.height))
        s.autoresizingMask = [.width, .height]; s.handler = { [weak self] x in self?.paint(x) }; s.ended = { [weak self] in self?.paintValue = nil }
        addSubview(s); stroke = s
    }

    private func add(_ v: NSView) { addSubview(v); controls.append(v) }
    @objc private func toggleRun() { running.toggle(); runButton?.title = running ? "Ⅱ" : "▶︎" }
    @objc private func back() { running = false; if let old = history.popLast() { cells = old; needsDisplay = true }; runButton?.title = "▶︎" }
    @objc private func forward() { step(record: true) }
    @objc private func randomize() { push(); for x in 0..<columns { for y in 0..<rows { cells[x][y] = Int.random(in: 0..<5) == 0 } }; needsDisplay = true }
    @objc private func openDraw() { drawMode = true; running = false; rebuildControls(); needsDisplay = true }
    @objc private func closeDraw() { drawMode = false; paintValue = nil; rebuildControls(); needsDisplay = true }
    @objc private func selectRow(_ sender: NSButton) { selectedRow = max(0, min(6, 7 - sender.tag)); paintValue = nil; rebuildControls(); needsDisplay = true }

    private func paint(_ xPos: CGFloat) {
        guard drawMode, let stroke else { return }
        let x = max(0, min(columns - 1, Int((xPos / max(1, stroke.bounds.width)) * CGFloat(columns))))
        if paintValue == nil { push(); paintValue = !cells[x][selectedRow] }
        cells[x][selectedRow] = paintValue ?? true; needsDisplay = true
    }
    private func push() { history.append(cells); if history.count > 64 { history.removeFirst() } }
    private func seed() { for x in stride(from: 8, to: columns - 8, by: 16) { cells[x][2] = true; cells[x+1][3] = true; cells[x+2][1] = true; cells[x+2][2] = true; cells[x+2][3] = true } }
    private func step(record: Bool) {
        if record { push() }; var next = cells
        for x in 0..<columns { for y in 0..<rows { var n = 0; for dx in -1...1 { for dy in -1...1 where !(dx == 0 && dy == 0) { if cells[(x+dx+columns)%columns][(y+dy+rows)%rows] { n += 1 } } }; next[x][y] = n == 3 || (cells[x][y] && n == 2) } }
        cells = next; needsDisplay = true
    }
    private func tick() { let now = ProcessInfo.processInfo.systemUptime; let dt = min(0.1, now-lastTick); lastTick = now; guard running else { return }; accumulator += dt; if accumulator >= 0.16 { accumulator -= 0.16; step(record: true) } }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); dirtyRect.fill(); let gw = max(1, bounds.width-controlsWidth), cw = gw/CGFloat(columns), ch = bounds.height/CGFloat(rows)
        if drawMode { NSColor(calibratedWhite: 0.16, alpha: 1).setFill(); NSRect(x: controlsWidth, y: CGFloat(selectedRow)*ch, width: gw, height: ch).fill() }
        NSColor(calibratedRed: 0.15, green: 0.86, blue: 0.95, alpha: 1).setFill()
        for x in 0..<columns { for y in 0..<rows where cells[x][y] { NSRect(x: controlsWidth+CGFloat(x)*cw, y: CGFloat(y)*ch, width: max(1,cw-0.35), height: max(1,ch-0.35)).fill() } }
    }
}

// MARK: Pitfall

private final class TBPKeyMonitor2 {
    private var tokens: [Any] = []
    var handler: ((NSEvent, Bool) -> Void)?
    init() {
        if let t = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp], handler: { [weak self] e in self?.handler?(e, e.type == .keyDown) }) { tokens.append(t) }
        if let t = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp], handler: { [weak self] e in self?.handler?(e, e.type == .keyDown); return e }) { tokens.append(t) }
    }
    deinit { tokens.forEach(NSEvent.removeMonitor) }
}

private final class PitfallGameView2: NSView {
    private let monitor = TBPKeyMonitor2(); private var pressed = Set<UInt16>()
    private var timer: Timer?, lastTick = ProcessInfo.processInfo.systemUptime, animation: TimeInterval = 0
    private var worldX: CGFloat = 0, heroY: CGFloat = 0, vy: CGFloat = 0
    private var score = 2000, lives = 3, treasures = 0, time: TimeInterval = 1200
    private var deadFor: TimeInterval = 0, respawnFor: TimeInterval = 0, collisionCooldown: TimeInterval = 0, deathSegment = 0
    private var collected = Set<Int>()
    private let controlsRight: CGFloat = 160, heroScreenX: CGFloat = 202
    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect); wantsLayer = true
        monitor.handler = { [weak self] e, down in self?.key(e, down) }; buildControls()
        let t = Timer(timeInterval: 1.0/60.0, repeats: true) { [weak self] _ in self?.tick() }; timer = t; RunLoop.main.add(t, forMode: .common)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }
    private var alive: Bool { deadFor <= 0 && respawnFor <= 0 }

    private func buildControls() {
        let specs: [(String, Selector, NSRect)] = [("◀", #selector(leftTap), NSRect(x:2,y:2,width:28,height:26)), ("JUMP", #selector(jumpTap), NSRect(x:32,y:2,width:46,height:26)), ("▶", #selector(rightTap), NSRect(x:80,y:2,width:28,height:26)), ("KEYS", #selector(keys), NSRect(x:110,y:2,width:48,height:26))]
        for (title, action, frame) in specs { let b = NSButton(title:title,target:self,action:action); b.font = .systemFont(ofSize:7); b.frame = frame; addSubview(b) }
    }
    @objc private func keys() { NSApp.activate(ignoringOtherApps: true); NSApp.windows.first?.makeKeyAndOrderFront(nil) }
    @objc private func leftTap() { if alive { worldX -= 14; needsDisplay = true } }
    @objc private func rightTap() { if alive { worldX += 14; needsDisplay = true } }
    @objc private func jumpTap() { jump() }
    private func key(_ e: NSEvent, _ down: Bool) {
        if down { pressed.insert(e.keyCode) } else { pressed.remove(e.keyCode) }
        if down && [126,13,49].contains(e.keyCode) { jump() }
    }
    private func jump() { if alive && heroY < 0.2 { vy = 108 } }
    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime, dt = min(0.1, now-lastTick); lastTick = now; animation += dt; time = max(0,time-dt); collisionCooldown = max(0,collisionCooldown-dt)
        if deadFor > 0 { deadFor -= dt; if deadFor <= 0 { respawnFor = 0.72; worldX = CGFloat(deathSegment*105+8); heroY=0; vy=0 }; needsDisplay=true; return }
        if respawnFor > 0 { respawnFor -= dt; needsDisplay=true; return }
        var d: CGFloat = 0; if pressed.contains(123)||pressed.contains(0){d = -1}; if pressed.contains(124)||pressed.contains(2){d = 1}; worldX += d*76*CGFloat(dt)
        vy -= 245*CGFloat(dt); heroY=max(0,heroY+vy*CGFloat(dt)); if heroY==0 && vy<0{vy=0}; detect(); needsDisplay=true
    }
    private func detect() {
        guard collisionCooldown<=0 else{return}; let segment=Int(floor(worldX/105)); let local=worldX-CGFloat(segment)*105; let p=((segment%4)+4)%4
        if p==0 && heroY<4 && local>40 && local<64 { score=max(0,score-12); collisionCooldown=0.12 }
        else if p==1 && heroY<4 && local>34 && local<76 { die(segment) }
        else if p==2 && heroY<4 && local>47 && local<69 { die(segment) }
        else if p==3 && heroY < 2.2 && local>48 && local<67 && !collected.contains(segment) { collected.insert(segment); treasures+=1; score+=2000; collisionCooldown=0.35 }
    }
    private func die(_ segment:Int){ guard alive else{return}; lives-=1; deathSegment=segment; deadFor=0.48; collisionCooldown=1.2; vy=0; if lives<=0 { lives=3; score=2000; treasures=0; time=1200; collected.removeAll() } }
    override func draw(_ dirtyRect:NSRect){
        let canopy=NSColor(calibratedRed:0.10,green:0.34,blue:0.06,alpha:1), jungle=NSColor(calibratedRed:0.32,green:0.62,blue:0.23,alpha:1), ground=NSColor(calibratedRed:0.76,green:0.68,blue:0.24,alpha:1)
        canopy.setFill(); dirtyRect.fill(); jungle.setFill(); NSRect(x:controlsRight,y:6,width:max(0,bounds.width-controlsRight),height:17).fill(); ground.setFill(); NSRect(x:controlsRight,y:4,width:max(0,bounds.width-controlsRight),height:3).fill(); NSColor.black.setFill(); NSRect(x:controlsRight,y:0,width:max(0,bounds.width-controlsRight),height:4).fill()
        let first=Int(floor(worldX/105))-2; for o in 0..<10 { let s=first+o, x=heroScreenX+CGFloat(s)*105-worldX; scene(s,x) }
        if respawnFor>0 { let q=CGFloat(1-max(0,respawnFor)/0.72); harry(controlsRight+18,23-q*16) } else if deadFor<=0 { harry(heroScreenX,7+heroY) }
        let m=Int(time)/60, s=Int(time)%60; String(format:"%05d  L%d  T%d  %02d:%02d",score,lives,treasures,m,s).draw(at:NSPoint(x:controlsRight+4,y:22),withAttributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:6,weight:.bold),.foregroundColor:NSColor.white])
    }
    private func scene(_ segment:Int,_ x:CGFloat){
        let p=((segment%4)+4)%4; NSColor(calibratedRed:0.38,green:0.22,blue:0.03,alpha:1).setFill(); NSRect(x:x+8,y:7,width:4,height:16).fill(); NSRect(x:x+92,y:7,width:4,height:16).fill()
        if p==0 { let roll=CGFloat(animation.truncatingRemainder(dividingBy:1))*18; NSColor(calibratedRed:0.48,green:0.25,blue:0.03,alpha:1).setFill(); NSRect(x:x+55-roll,y:7,width:18,height:4).fill() }
        else if p==1 { NSColor(calibratedRed:0.13,green:0.45,blue:0.66,alpha:1).setFill(); NSRect(x:x+34,y:4,width:42,height:4).fill(); NSColor(calibratedRed:0.03,green:0.27,blue:0.06,alpha:1).setFill(); let open=sin(animation*5)>0; for gx in stride(from:x+38,through:x+68,by:14){NSRect(x:gx,y:6,width:10,height:2).fill();NSRect(x:gx+2,y:open ? 9:8,width:5,height:1).fill()}; let r=NSBezierPath();r.move(to:NSPoint(x:x+55,y:23));r.line(to:NSPoint(x:x+47+sin(animation*2)*5,y:11));NSColor(calibratedRed:0.42,green:0.27,blue:0.05,alpha:1).setStroke();r.lineWidth=1;r.stroke() }
        else if p==2 { NSColor.black.setFill();NSRect(x:x+47,y:3,width:22,height:6).fill();NSColor.white.setFill();let sx=x+52+sin(animation*2.5)*5;NSRect(x:sx,y:1,width:8,height:2).fill();NSRect(x:sx+7,y:2,width:4,height:1).fill() }
        else if !collected.contains(segment) { NSColor(calibratedRed:0.95,green:0.75,blue:0.12,alpha:1).setFill();NSRect(x:x+52,y:9,width:10,height:3).fill();NSColor(calibratedRed:1,green:0.9,blue:0.35,alpha:1).setFill();NSRect(x:x+54,y:12,width:6,height:1).fill() }
    }
    private func harry(_ x:CGFloat,_ y:CGFloat){NSColor(calibratedRed:0.95,green:0.55,blue:0.48,alpha:1).setFill();NSRect(x:x+2,y:y+8,width:4,height:4).fill();NSColor(calibratedRed:0.12,green:0.42,blue:0.16,alpha:1).setFill();NSRect(x:x+1,y:y+3,width:6,height:6).fill();NSColor(calibratedRed:0.08,green:0.15,blue:0.04,alpha:1).setFill();NSRect(x:x,y:y,width:3,height:4).fill();NSRect(x:x+5,y:y,width:3,height:4).fill()}
}

// MARK: Exact E.T. pixel sprite

private final class ExactETView: NSView {
    private var playerX:CGFloat=184; private var pieces=[CGPoint(x:300,y:13),CGPoint(x:470,y:12),CGPoint(x:620,y:15)]; private var collected=Set<Int>(); private var score=8975
    // Exact 16x15 non-transparent pixel mask from the user's ET(2).bmp.
    private let sprite=["..##############","############..##","################","################","####........####","####............","########........","##########......","################","############..##","############....","############....","####..##..##....","####......####..","######....######"]
    override var intrinsicContentSize:NSSize{NSSize(width:700,height:30)}
    override init(frame:NSRect){super.init(frame:frame);wantsLayer=true;build()}
    required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
    private func build(){for (t,a,f) in [("◀",#selector(left),NSRect(x:2,y:2,width:28,height:26)),("TAKE",#selector(take),NSRect(x:32,y:2,width:46,height:26)),("▶",#selector(right),NSRect(x:80,y:2,width:28,height:26))] as [(String,Selector,NSRect)]{let b=NSButton(title:t,target:self,action:a);b.font=.systemFont(ofSize:7);b.frame=f;addSubview(b)}}
    @objc private func left(){playerX=max(122,playerX-16);needsDisplay=true};@objc private func right(){playerX=min(bounds.width-24,playerX+16);needsDisplay=true};@objc private func take(){for i in pieces.indices where !collected.contains(i){if abs(pieces[i].x-playerX)<25{collected.insert(i);score+=25}};needsDisplay=true}
    override func draw(_ dirtyRect:NSRect){let field=NSColor(calibratedRed:0.31,green:0.47,blue:0.23,alpha:1);field.setFill();dirtyRect.fill();NSColor(calibratedRed:0.03,green:0.22,blue:0.04,alpha:1).setFill();for r in [CGRect(x:250,y:9,width:58,height:5),CGRect(x:405,y:18,width:70,height:5),CGRect(x:555,y:8,width:68,height:5)]{r.fill()};for i in pieces.indices where !collected.contains(i){NSColor(calibratedRed:0.95,green:0.78,blue:0.20,alpha:1).setFill();NSRect(x:pieces[i].x,y:pieces[i].y,width:5,height:3).fill()};drawET(NSPoint(x:playerX,y:7));let hud=collected.count==pieces.count ? "CALL HOME" : String(format:"%04d  PHONE %d/3",score,collected.count);hud.draw(at:NSPoint(x:120,y:1),withAttributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:6,weight:.bold),.foregroundColor:NSColor(calibratedRed:0.04,green:0.20,blue:0.04,alpha:1)])}
    private func drawET(_ o:NSPoint){let c=NSColor(calibratedRed:149/255,green:206/255,blue:117/255,alpha:1);c.setFill();for (row,line) in sprite.enumerated(){for (col,ch) in line.enumerated() where ch=="#"{NSRect(x:o.x+CGFloat(col),y:o.y+CGFloat(sprite.count-1-row),width:1.05,height:1.05).fill()}}}
}

// MARK: Adventure

private final class AdventureTerminalView2:NSView{
    private struct Room{let description:String;let exits:[String:String]}
    private let rooms:[String:Room]=[
        "mouth":Room(description:"You stand at the mouth of a limestone cave. Cool air drifts from a narrow passage leading north, and daylight remains behind you, but there is no path south through the steep brush and broken rock.",exits:["N":"hall"]),
        "hall":Room(description:"The passage opens into a low echoing hall. Water ticks from the ceiling into shallow pools. The cave continues east; the entrance lies south.",exits:["S":"mouth","E":"chamber"]),
        "chamber":Room(description:"This rounded stone chamber smells faintly of wet iron. A battered brass lamp rests on a ledge. Passages lead west and north.",exits:["W":"hall","N":"bridge"]),
        "bridge":Room(description:"A narrow natural bridge crosses a black fissure. Pebbles vanish soundlessly into the depth below. The chamber is south; a faint mineral glimmer shows east.",exits:["S":"chamber","E":"vault"]),
        "vault":Room(description:"You enter a quiet mineral vault veined with pale crystal. In a pocket of dry stone, a small treasure gleams. The bridge is west.",exits:["W":"bridge"])]
    private var room="mouth",inventory=Set<String>(),lines=["WELCOME TO VERY SMALL CAVE ADVENTURE.","Tap > TYPE, then enter a command. Try LOOK, N, S, E, W, TAKE, INV, or HELP."],command="",editing=false;private var monitor:Any?
    override var acceptsFirstResponder:Bool{true};override var intrinsicContentSize:NSSize{NSSize(width:700,height:30)}
    override init(frame:NSRect){super.init(frame:frame);wantsLayer=true;layer?.backgroundColor=NSColor.black.cgColor;let b=NSButton(title:"> TYPE",target:self,action:#selector(begin));b.font=.monospacedSystemFont(ofSize:7,weight:.bold);b.frame=NSRect(x:2,y:2,width:58,height:26);addSubview(b);monitor=NSEvent.addLocalMonitorForEvents(matching:.keyDown){[weak self]e in guard let self,self.editing else{return e};self.consume(e);return nil}}
    required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")};deinit{if let monitor{NSEvent.removeMonitor(monitor)}}
    @objc private func begin(){editing=true;NSApp.activate(ignoringOtherApps:true);NSApp.windows.first?.makeKeyAndOrderFront(nil);needsDisplay=true}
    override func keyDown(with e:NSEvent){consume(e)}
    private func consume(_ e:NSEvent){if e.keyCode==36||e.keyCode==76{submit();return};if e.keyCode==51||e.keyCode==117{if !command.isEmpty{command.removeLast()};needsDisplay=true;return};guard let chars=e.charactersIgnoringModifiers else{return};for s in chars.unicodeScalars where s.value>=32&&s.value<127{if command.count<80{command.append(Character(String(s)))}};needsDisplay=true}
    private func submit(){let raw=command.trimmingCharacters(in:.whitespacesAndNewlines);command="";guard !raw.isEmpty else{return};append("> "+raw.uppercased());process(raw.uppercased());needsDisplay=true}
    private func append(_ text:String){var line="";for w in text.split(separator:" ").map(String.init){let c=line.isEmpty ? w : line+" "+w;if c.count>100{if !line.isEmpty{lines.append(line)};line=w}else{line=c}};if !line.isEmpty{lines.append(line)};while lines.count>12{lines.removeFirst()}}
    private func process(_ input:String){var n=input;let aliases=["NORTH":"N","SOUTH":"S","EAST":"E","WEST":"W"];if n.hasPrefix("GO "){n=String(n.dropFirst(3))};n=aliases[n] ?? n;if ["N","S","E","W"].contains(n){if let d=rooms[room]?.exits[n]{room=d;append(rooms[room]?.description ?? "Darkness presses close around you.")}else{append("You can't go that way.")};return};switch n{case "LOOK","L":append(rooms[room]?.description ?? "Darkness presses close around you.");case "TAKE LAMP","GET LAMP","TAKE":if room=="chamber"&&!inventory.contains("LAMP"){inventory.insert("LAMP");append("You take the battered brass lamp. It is heavier than it looks, but still seems usable.")}else if room=="vault"&&!inventory.contains("TREASURE"){inventory.insert("TREASURE");append("You lift the small treasure from its stone pocket.")}else{append("There is nothing obvious here that you can take.")};case "TAKE TREASURE","GET TREASURE":if room=="vault"&&!inventory.contains("TREASURE"){inventory.insert("TREASURE");append("You lift the small treasure from its stone pocket.")}else{append("You see no treasure here to take.")};case "I","INV","INVENTORY":append(inventory.isEmpty ? "You are carrying nothing." : "You are carrying: "+inventory.sorted().joined(separator:", ")+".");case "HELP":append("Commands include N, S, E, W, LOOK, TAKE LAMP, TAKE TREASURE, INV, and HELP.");default:append("I don't understand that command.")}}
    override func draw(_ dirtyRect:NSRect){NSColor.black.setFill();dirtyRect.fill();let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.monospacedSystemFont(ofSize:4.9,weight:.regular),.foregroundColor:NSColor(calibratedRed:0.2,green:1,blue:0.38,alpha:1)];let lh:CGFloat=5.7;var y=bounds.height-lh;for l in lines.suffix(4){l.draw(at:NSPoint(x:64,y:y),withAttributes:attrs);y-=lh};("> "+command+(editing ? "_":"▮")).draw(at:NSPoint(x:64,y:1),withAttributes:attrs)}
}

// MARK: Pond

private final class KoiPondView:NSView{
    private struct Fish{var x:CGFloat;var y:CGFloat;var speed:CGFloat;var direction:CGFloat;var phase:CGFloat;var warm:Bool}
    private let samples=180;private var h=[CGFloat](repeating:0,count:180),v=[CGFloat](repeating:0,count:180);private var fish=[Fish(x:90,y:9,speed:20,direction:1,phase:0,warm:true),Fish(x:270,y:19,speed:14,direction:-1,phase:1.3,warm:false),Fish(x:470,y:12,speed:18,direction:1,phase:2.1,warm:true),Fish(x:620,y:21,speed:12,direction:-1,phase:3.4,warm:false)];private var timer:Timer?,last=ProcessInfo.processInfo.systemUptime
    override var intrinsicContentSize:NSSize{NSSize(width:700,height:30)}
    override init(frame:NSRect){super.init(frame:frame);wantsLayer=true;acceptsTouchEvents=true;allowedTouchTypes=[.direct];wantsRestingTouches=true;let t=Timer(timeInterval:1/60,repeats:true){[weak self]_ in self?.tick()};timer=t;RunLoop.main.add(t,forMode:.common)}
    required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")};deinit{timer?.invalidate()};override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
    override func mouseDown(with e:NSEvent){splash(convert(e.locationInWindow,from:nil).x)};override func mouseDragged(with e:NSEvent){splash(convert(e.locationInWindow,from:nil).x,0.45)};override func touchesBegan(with e:NSEvent){touch(e,.began)};override func touchesMoved(with e:NSEvent){touch(e,.moved)}
    private func touch(_ e:NSEvent,_ p:NSTouch.Phase){for t in e.touches(matching:p,in:self){splash(t.location(in:self).x,p == .began ? 1:0.35)}}
    private func splash(_ x:CGFloat,_ power:CGFloat=1){let i=max(2,min(samples-3,Int((x/max(1,bounds.width))*CGFloat(samples))));v[i]+=5.5*power;v[i-1]+=2.6*power;v[i+1]+=2.6*power;for j in fish.indices where abs(fish[j].x-x)<85{fish[j].direction = fish[j].x < x ? -1:1;fish[j].speed=min(30,fish[j].speed+5)}}
    private func tick(){let now=ProcessInfo.processInfo.systemUptime,dt=min(0.05,now-last);last=now;var nv=v;for i in 1..<(samples-1){let lap=h[i-1]+h[i+1]-2*h[i];nv[i]=(v[i]+lap*0.24)*0.985};v=nv;for i in 1..<(samples-1){h[i]=(h[i]+v[i])*0.995};for i in fish.indices{fish[i].phase+=CGFloat(dt)*5;fish[i].x+=fish[i].direction*fish[i].speed*CGFloat(dt);fish[i].speed=max(10,fish[i].speed*0.999);if fish[i].x < -20{fish[i].x=bounds.width+20}else if fish[i].x > bounds.width+20{fish[i].x = -20}};needsDisplay=true}
    override func draw(_ dirtyRect:NSRect){NSColor(calibratedRed:0.015,green:0.12,blue:0.16,alpha:1).setFill();dirtyRect.fill();for f in fish{drawFish(f)};let dx=bounds.width/CGFloat(samples-1);for i in 1..<(samples-1){let slope=h[i+1]-h[i-1],amp=min(1,abs(slope)*0.22+abs(h[i])*0.035);if amp>0.03{NSColor(calibratedRed:0.18,green:0.75,blue:0.82,alpha:0.18+amp*0.42).setFill();let y=bounds.midY+h[i]*0.28;NSRect(x:CGFloat(i)*dx,y:y,width:max(1,dx+0.3),height:1+amp*2.5).fill()}};NSColor(calibratedRed:0.06,green:0.35,blue:0.36,alpha:0.32).setStroke();for offset in [-7.0,7.0] as [CGFloat]{let p=NSBezierPath();for i in 0..<samples{let pt=NSPoint(x:CGFloat(i)*dx,y:bounds.midY+offset+h[i]*0.12);i==0 ? p.move(to:pt):p.line(to:pt)};p.lineWidth=0.7;p.stroke()}}
    private func drawFish(_ f:Fish){NSGraphicsContext.saveGraphicsState();let t=NSAffineTransform();t.translateX(by:f.x,yBy:f.y);if f.direction<0{t.scaleX(by:-1,yBy:1)};t.concat();let body=f.warm ? NSColor(calibratedRed:0.95,green:0.45,blue:0.10,alpha:0.82):NSColor(calibratedWhite:0.92,alpha:0.76);body.setFill();NSBezierPath(ovalIn:NSRect(x:-7,y:-2.5,width:14,height:5)).fill();let tail=NSBezierPath();tail.move(to:NSPoint(x:-6,y:0));tail.line(to:NSPoint(x:-11,y:4+sin(f.phase)));tail.line(to:NSPoint(x:-11,y:-4+sin(f.phase)));tail.close();tail.fill();NSColor(calibratedWhite:0.1,alpha:0.8).setFill();NSBezierPath(ovalIn:NSRect(x:4.2,y:0.6,width:1.1,height:1.1)).fill();NSGraphicsContext.restoreGraphicsState()}
}

// MARK: Autonomous Lemmings demo

private final class LemmingsDemoView2:NSView{
    private enum State{case falling,walking,building,bashing,entering,ohNo,exploding,dead,saved}
    private struct Lem{var x:CGFloat;var y:CGFloat;var dir:CGFloat=1;var state:State=.falling;var dist:CGFloat=0;var stateTime:TimeInterval=0;var fall:CGFloat=0;var nukeDelay:TimeInterval?;var bomb:TimeInterval?}
    private let frames:[[String]]=[["........","..GGGG..",".GGSSS..","..SS....","..BBS...",".SBBB...","..BBB...","..BB....",".SS..S..","..S..SS."],["........","..GGGG..",".GGSSS..","..SSS...","..BBB...",".SBBB.S.","..BBB...","..BB....",".S...SS.","SS......"],["........","..GGGG..",".GGSSS..","..SSS...","..BBB...","..BBBS..",".SBBB...","..B.....",".S..SS..","SS...S.."],["........","..GGGG..",".GGSSS..","..SS....","..BBB...","..BBBS..",".SBBB...","...B....",".SS..S..",".....SS."],["........","..GGGG..",".GGSSS..","..SS....","..BBS...","..BBB...",".SBBB...","...BB...","..S..SS.",".SS..S.."],["........","..GGGG..",".GGSSS..","..SSS...","..BBB...",".SBBB...","..BBBS..","...BB...","SS...S..",".S..SS.."],["........","..GGGG..",".GGSSS..","..SSS...","..BBB...","S.BBB...","..BBBS..","....B...","SS..S...",".S...SS."],["........","..GGGG..",".GGSSS..","..SS....",".SBBB...","..BBB...","..BBBS..","...BB...",".SS..S..","..S..SS."]]
    private let pixel:CGFloat=1.45,walk:CGFloat=25,fallSpeed:CGFloat=44,spawnEvery:TimeInterval=0.80,brickTime:TimeInterval=0.10
    private var lems:[Lem]=[],timer:Timer?,last=ProcessInfo.processInfo.systemUptime,elapsed:TimeInterval=0,nextSpawn:TimeInterval=0.6;private var spawned=0,saved=0,dead=0,bridge=0;private var wallClear:CGFloat=0;private var gapFailed=false,builderAssigned=false,wallFailed=false,basherAssigned=false,nuked=false
    private var ground:CGFloat{bounds.height-3};private var sw:CGFloat{8*pixel};private var sh:CGFloat{10*pixel};private var gapA:CGFloat{max(175,bounds.width*0.29)},gapB:CGFloat{gapA+54},stepW:CGFloat{(gapB-gapA)/12};private var wallA:CGFloat{max(gapB+90,bounds.width*0.62)},wallB:CGFloat{wallA+21},exitX:CGFloat{max(wallB+80,bounds.width-58)},door:NSRect{NSRect(x:exitX+14,y:ground-15,width:12,height:15)}
    override var isFlipped:Bool{true};override var intrinsicContentSize:NSSize{NSSize(width:700,height:30)}
    override init(frame:NSRect){super.init(frame:frame);wantsLayer=true;layer?.backgroundColor=NSColor.black.cgColor;acceptsTouchEvents=true;allowedTouchTypes=[.direct];let t=Timer(timeInterval:1/30,repeats:true){[weak self]_ in self?.tick()};timer=t;RunLoop.main.add(t,forMode:.common)}
    required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")};deinit{timer?.invalidate()};override func acceptsFirstMouse(for event:NSEvent?)->Bool{true};override func mouseDown(with event:NSEvent){nuke()};override func touchesBegan(with event:NSEvent){nuke()}
    private func surface(_ x:CGFloat)->CGFloat{if x>=gapA&&x<=gapB{let s=max(0,min(11,Int((x-gapA)/max(0.1,stepW))));return s<bridge ? ground-CGFloat(s+1)*0.72 : bounds.height+30};let cleared=wallA+(wallB-wallA)*wallClear;if x>=cleared&&x<=wallB&&wallClear<1{return ground-11};return ground}
    private func tick(){let now=ProcessInfo.processInfo.systemUptime,dt=min(0.1,now-last);last=now;elapsed+=dt;if !nuked&&spawned<12&&elapsed>=nextSpawn{lems.append(Lem(x:31,y:5));spawned+=1;nextSpawn+=spawnEvery};for i in lems.indices{if var d=lems[i].nukeDelay{d-=dt;if d<=0{lems[i].nukeDelay=nil;lems[i].bomb=5}else{lems[i].nukeDelay=d}};if var b=lems[i].bomb{b-=dt;if b<=0{lems[i].bomb=nil;lems[i].state=.ohNo;lems[i].stateTime=0}else{lems[i].bomb=b}};update(i,dt)};if !nuked{ai()};needsDisplay=true}
    private func update(_ i:Int,_ dt:TimeInterval){switch lems[i].state{case .falling:let dy=fallSpeed*CGFloat(dt);lems[i].y+=dy;lems[i].fall+=dy;if lems[i].y>bounds.height+5{lems[i].state=.dead;dead+=1;if lems[i].x>=gapA-8&&lems[i].x<=gapB+8{gapFailed=true};return};let s=surface(lems[i].x+sw/2);if s<=bounds.height+2&&lems[i].y+sh>=s{lems[i].y=s-sh;lems[i].state=.walking;lems[i].fall=0}
        case .walking:let dx=lems[i].dir*walk*CGFloat(dt),nx=lems[i].x+dx,cs=surface(lems[i].x+sw/2),ns=surface(nx+sw/2);if ns<cs-6{if nx+sw/2>=wallA-4&&nx+sw/2<=wallB+4{wallFailed=true};lems[i].dir *= -1;return};lems[i].x=nx;lems[i].dist+=abs(dx);if ns>cs+5{lems[i].state=.falling;lems[i].fall=0;return};lems[i].y=ns-sh;if lems[i].dir>0&&lems[i].x+sw*0.55>=door.minX{lems[i].state=.entering;lems[i].stateTime=0};if lems[i].x<2{lems[i].dir=1}
        case .building:lems[i].stateTime+=dt;let done=min(12,Int(lems[i].stateTime/brickTime));bridge=max(bridge,done);lems[i].x=gapA-sw*0.4+CGFloat(done)*stepW;lems[i].y=ground-sh-CGFloat(done)*0.72;lems[i].dist+=walk*0.25*CGFloat(dt);if done>=12{lems[i].state=.walking;lems[i].stateTime=0;lems[i].x=gapB+1;lems[i].y=ground-sh-12*0.72}
        case .bashing:lems[i].stateTime+=dt;wallClear=min(1,CGFloat(lems[i].stateTime/1.15));lems[i].x=wallA-sw*0.35+(wallB-wallA)*wallClear;lems[i].y=ground-sh;lems[i].dist+=walk*CGFloat(dt);if wallClear>=1{lems[i].x=wallB+1;lems[i].state=.walking;lems[i].stateTime=0}
        case .entering:lems[i].stateTime+=dt;lems[i].x+=walk*0.35*CGFloat(dt);if lems[i].stateTime>0.45{lems[i].state=.saved;saved+=1}
        case .ohNo:lems[i].stateTime+=dt;if lems[i].stateTime>0.65{lems[i].state=.exploding;lems[i].stateTime=0}
        case .exploding:lems[i].stateTime+=dt;if lems[i].stateTime>0.48{lems[i].state=.dead;dead+=1}
        case .dead,.saved:break}}
    private func ai(){if gapFailed&&!builderAssigned,let i=lems.indices.first(where:{lems[$0].state == .walking&&lems[$0].dir>0&&lems[$0].x>gapA-34}){lems[i].state=.building;lems[i].stateTime=0;builderAssigned=true};if bridge>=12&&wallFailed&&!basherAssigned,let i=lems.indices.first(where:{lems[$0].state == .walking&&lems[$0].dir>0&&lems[$0].x+sw/2>wallA-42}){lems[i].state=.bashing;lems[i].stateTime=0;basherAssigned=true}}
    private func nuke(){guard !nuked else{return};nuked=true;var d:TimeInterval=0;for i in lems.indices where ![State.dead,.saved,.exploding].contains(lems[i].state){lems[i].nukeDelay=d;d+=0.12}}
    override func draw(_ dirtyRect:NSRect){NSColor(calibratedRed:0.005,green:0.01,blue:0.11,alpha:1).setFill();dirtyRect.fill();terrain();entrance();exitBack();for l in lems where l.state != .dead&&l.state != .saved{if l.state == .exploding{explosion(l)}else if l.state == .entering{NSGraphicsContext.saveGraphicsState();NSBezierPath(rect:door).addClip();lemming(l);NSGraphicsContext.restoreGraphicsState()}else{lemming(l)}};exitFront();let hud="OUT \(max(0,spawned-saved-dead))  IN \(saved)";hud.draw(at:NSPoint(x:75,y:1),withAttributes:[.font:NSFont.monospacedSystemFont(ofSize:5.8,weight:.medium),.foregroundColor:NSColor(calibratedWhite:0.8,alpha:1)])}
    private func terrain(){let dirt=NSColor(calibratedRed:0.55,green:0.22,blue:0.05,alpha:1),grass=NSColor(calibratedRed:0.1,green:0.64,blue:0.1,alpha:1);for x in stride(from:CGFloat(0),through:bounds.width,by:2){let y=surface(x);if y<=bounds.height{dirt.setFill();NSRect(x:x,y:y,width:2,height:bounds.height-y).fill();grass.setFill();NSRect(x:x,y:y-1,width:2,height:1).fill()}};let wood=NSColor(calibratedRed:0.88,green:0.63,blue:0.2,alpha:1);for s in 0..<bridge{wood.setFill();let x=gapA+CGFloat(s)*stepW,y=ground-CGFloat(s+1)*0.72;NSRect(x:x,y:y-1.5,width:stepW+0.7,height:2.2).fill()};if wallClear<1{let a=wallA+(wallB-wallA)*wallClear;NSColor(calibratedRed:0.55,green:0.22,blue:0.05,alpha:1).setFill();NSRect(x:a,y:ground-11,width:wallB-a,height:11).fill()}}
    private func entrance(){NSColor(calibratedRed:0.58,green:0.18,blue:0.07,alpha:1).setFill();NSRect(x:7,y:4,width:5,height:10).fill();NSRect(x:38,y:4,width:5,height:10).fill();NSColor(calibratedRed:0.18,green:0.24,blue:0.68,alpha:1).setFill();NSRect(x:14,y:5,width:22,height:4).fill();NSColor.black.setFill();NSRect(x:21,y:8,width:8,height:5).fill()}
    private func exitBack(){NSColor(calibratedRed:0.04,green:0.06,blue:0.24,alpha:1).setFill();door.fill();NSColor(calibratedRed:0.35,green:0.37,blue:0.4,alpha:1).setFill();NSRect(x:exitX+8,y:ground-15,width:6,height:15).fill()}
    private func exitFront(){NSColor(calibratedRed:0.35,green:0.37,blue:0.4,alpha:1).setFill();NSRect(x:exitX+9,y:ground-19,width:21,height:4).fill();NSRect(x:exitX+26,y:ground-15,width:6,height:15).fill();torch(exitX+4,0);torch(exitX+35,.pi)}
    private func torch(_ x:CGFloat,_ phase:CGFloat){let p=sin(CGFloat(elapsed)*17+phase),hh:CGFloat=p>0.3 ? 6:(p < -0.3 ? 4:5);NSColor(calibratedRed:0.95,green:0.1,blue:0.02,alpha:1).setFill();NSRect(x:x-1,y:ground-11-hh,width:4,height:hh).fill();NSColor(calibratedRed:1,green:0.74,blue:0.05,alpha:1).setFill();NSRect(x:x,y:ground-10-hh,width:2,height:max(2,hh-2)).fill()}
    private func lemming(_ l:Lem){if l.state == .ohNo{ohNo(l);return};let f=frames[min(7,Int(floor(l.dist/2.3))%8)],hair=NSColor(calibratedRed:0.18,green:0.98,blue:0.18,alpha:1),skin=NSColor(calibratedRed:0.98,green:0.76,blue:0.58,alpha:1),blue=NSColor(calibratedRed:0.1,green:0.35,blue:0.98,alpha:1);for (r,line) in f.enumerated(){for (c,ch) in line.enumerated(){let color: NSColor? = ch=="G" ? hair:(ch=="S" ? skin:(ch=="B" ? blue:nil));if let color{color.setFill();let sx=l.dir>0 ? c:7-c;NSRect(x:floor(l.x)+CGFloat(sx)*pixel,y:floor(l.y)+CGFloat(r)*pixel,width:pixel+0.15,height:pixel+0.15).fill()}}};if l.state == .building{let phase=l.stateTime.truncatingRemainder(dividingBy:brickTime)/brickTime;NSColor(calibratedRed:0.9,green:0.66,blue:0.22,alpha:1).setFill();let bx=phase<0.45 ? l.x-3:l.x+sw-1;NSRect(x:bx,y:l.y+8,width:6,height:1.4).fill()};if let b=l.bomb{String(Int(ceil(b))).draw(at:NSPoint(x:l.x+2,y:max(0,l.y-7)),withAttributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:6,weight:.bold),.foregroundColor:NSColor.white])}}
    private func ohNo(_ l:Lem){let hair=NSColor(calibratedRed:0.18,green:0.98,blue:0.18,alpha:1),skin=NSColor(calibratedRed:0.98,green:0.76,blue:0.58,alpha:1),blue=NSColor(calibratedRed:0.1,green:0.35,blue:0.98,alpha:1),bob=sin(CGFloat(l.stateTime)*20)>0 ? CGFloat(1):0;hair.setFill();NSRect(x:l.x+3,y:l.y+1-bob,width:7,height:4).fill();skin.setFill();NSRect(x:l.x+4,y:l.y+5-bob,width:5,height:4).fill();NSRect(x:l.x+1,y:l.y+4-bob,width:3,height:5).fill();NSRect(x:l.x+9,y:l.y+4-bob,width:3,height:5).fill();blue.setFill();NSRect(x:l.x+3,y:l.y+9-bob,width:7,height:6).fill()}
    private func explosion(_ l:Lem){let t=CGFloat(min(1,l.stateTime/0.48)),r=3+t*11,c=NSPoint(x:l.x+sw/2,y:l.y+sh/2);NSColor(calibratedRed:1,green:0.78,blue:0.08,alpha:1-t*0.5).setFill();NSBezierPath(ovalIn:NSRect(x:c.x-r*0.45,y:c.y-r*0.45,width:r*0.9,height:r*0.9)).fill();let cols=[NSColor.red,NSColor.orange,NSColor.yellow,NSColor.white];for k in 0..<12{cols[k%cols.count].setFill();let a=CGFloat(k)*(.pi*2/12)+t,rr=r*(0.55+CGFloat(k%3)*0.18);NSRect(x:c.x+cos(a)*rr,y:c.y+sin(a)*rr,width:1.4,height:1.4).fill()}}
}
