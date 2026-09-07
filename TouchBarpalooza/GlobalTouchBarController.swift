import AppKit

private extension NSTouchBarItem.Identifier {
    static let touchBarpaloozaTray = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.tray")
    static let touchBarpaloozaHome = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.home")

    static let touchBarpaloozaLemmings = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.lemmings")
    static let touchBarpaloozaClipboard = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.clipboard")
    static let touchBarpaloozaAudio = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.audio")
    static let touchBarpaloozaMIDI = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.midi")
    static let touchBarpaloozaGames = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.games")
    static let touchBarpaloozaKITT = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.kitt")
    static let touchBarpaloozaTokiPona = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.tokipona")

    static let lemmingsPlay = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.lemmings.play")
    static let lemmingsDemo = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.lemmings.demo")
    static let lemmingsControls = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.lemmings.controls")

    static let gamesCompact = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.games.compact")
    static let content = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.content")
}

final class GlobalTouchBarController: NSObject, NSTouchBarDelegate {
    private enum Mode {
        case home, lemmingsMenu, lemmingsPlay, lemmingsDemo
        case clipboard, audio, midi, gamesMenu
        case pong, snake, breakout, life, pitfall, et, adventure
        case kitt, tokiPona
    }

    private var mode: Mode = .home
    private var touchBar = NSTouchBar()
    private var trayItem: NSCustomTouchBarItem?
    private var isStarted = false
    private weak var currentLemmingsView: LemmingsView?
    private var lemmingsSkillButtons: [NSButton] = []

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
        if let item = trayItem { NSTouchBarItem.removeSystemTrayItem(item) }
        trayItem = nil
        isStarted = false
    }

    private func rebuildAndPresent() {
        currentLemmingsView = nil
        lemmingsSkillButtons.removeAll()

        let bar = NSTouchBar()
        bar.delegate = self
        bar.escapeKeyReplacementItemIdentifier = nil

        switch mode {
        case .home:
            bar.defaultItemIdentifiers = [
                .touchBarpaloozaLemmings, .touchBarpaloozaClipboard,
                .touchBarpaloozaAudio, .touchBarpaloozaMIDI,
                .touchBarpaloozaGames, .touchBarpaloozaKITT,
                .touchBarpaloozaTokiPona
            ]
        case .lemmingsMenu:
            bar.defaultItemIdentifiers = [.touchBarpaloozaHome, .lemmingsPlay, .lemmingsDemo]
        case .lemmingsPlay:
            bar.defaultItemIdentifiers = [.touchBarpaloozaHome, .lemmingsControls, .content]
        case .lemmingsDemo:
            bar.defaultItemIdentifiers = [.touchBarpaloozaHome, .content]
        case .gamesMenu:
            bar.defaultItemIdentifiers = [.touchBarpaloozaHome, .gamesCompact]
        case .clipboard, .audio, .midi, .pong, .snake, .breakout, .life,
             .pitfall, .et, .adventure, .kitt, .tokiPona:
            bar.defaultItemIdentifiers = [.touchBarpaloozaHome, .content]
        }

        touchBar = bar
        presentCurrentBar()
    }

    @objc private func presentCurrentBar() {
        guard isStarted else { return }
        NSTouchBar.presentSystemModalTouchBar(touchBar, systemTrayItemIdentifier: .touchBarpaloozaTray)
        DFRElementSetControlStripPresenceForIdentifier(.touchBarpaloozaTray, true)
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .touchBarpaloozaHome:
            let item = buttonItem(identifier: identifier, title: "⌂", action: #selector(showHome))
            item.visibilityPriority = .high
            return item
        case .touchBarpaloozaLemmings:
            return buttonItem(identifier: identifier, title: "Lemmings", action: #selector(showLemmingsMenu))
        case .touchBarpaloozaClipboard:
            return buttonItem(identifier: identifier, title: "Clipboard", action: #selector(showClipboard))
        case .touchBarpaloozaAudio:
            return buttonItem(identifier: identifier, title: "Spectrum", action: #selector(showAudio))
        case .touchBarpaloozaMIDI:
            return buttonItem(identifier: identifier, title: "MIDI", action: #selector(showMIDI))
        case .touchBarpaloozaGames:
            return buttonItem(identifier: identifier, title: "Games", action: #selector(showGames))
        case .touchBarpaloozaKITT:
            return buttonItem(identifier: identifier, title: "KITT", action: #selector(showKITT))
        case .touchBarpaloozaTokiPona:
            return buttonItem(identifier: identifier, title: "Toki Pona", action: #selector(showTokiPona))
        case .lemmingsPlay:
            return buttonItem(identifier: identifier, title: "PLAY", action: #selector(startLemmingsPlay))
        case .lemmingsDemo:
            return buttonItem(identifier: identifier, title: "DEMO", action: #selector(startLemmingsDemo))
        case .lemmingsControls:
            return lemmingsControlItem(identifier: identifier)
        case .gamesCompact:
            return gamesMenuItem(identifier: identifier)
        case .content:
            return contentItem(identifier: identifier)
        default:
            return nil
        }
    }

    private func preferredContentWidth() -> CGFloat {
        switch mode {
        case .lemmingsPlay: return 350
        case .clipboard, .midi: return 690
        default: return 700
        }
    }

    private func contentItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let width = preferredContentWidth()
        let frame = NSRect(x: 0, y: 0, width: width, height: 30)
        let content: NSView

        switch mode {
        case .lemmingsPlay:
            let view = LemmingsView(frame: frame, mode: .interactive)
            currentLemmingsView = view
            content = view
        case .lemmingsDemo:
            let view = LemmingsView(frame: frame, mode: .demo)
            currentLemmingsView = view
            content = view
        case .clipboard: content = ClipboardShelfView(frame: frame)
        case .audio: content = AudioVisualizerView(frame: frame)
        case .midi: content = MIDIControlView(frame: frame)
        case .pong: content = MiniGameView(frame: frame, game: .pong)
        case .snake: content = MiniGameView(frame: frame, game: .snake)
        case .breakout: content = MiniGameView(frame: frame, game: .breakout)
        case .life: content = LifeGameViewV3(frame: frame)
        case .pitfall: content = PitfallGameViewV2(frame: frame)
        case .et: content = ETPixelGameViewV2(frame: frame)
        case .adventure: content = AdventureTerminalView(frame: frame)
        case .kitt: content = KITTScannerView(frame: frame)
        case .tokiPona: content = TokiPonaStudyView(frame: frame)
        default: content = NSView(frame: frame)
        }

        item.view = TouchBarContentHostView(content: content, preferredWidth: width)
        item.visibilityPriority = mode == .lemmingsPlay ? .normal : .high
        return item
    }

    private func lemmingsControlItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let view = FixedTouchBarView(size: NSSize(width: 240, height: 30))
        let abbreviations = ["CL", "FL", "BO", "BL", "BU", "BA", "MI", "DI"]
        let fullNames = LemmingsView.Skill.allCases.map(\.shortName)
        var x: CGFloat = 0
        lemmingsSkillButtons.removeAll()

        for index in abbreviations.indices {
            let button = NSButton(title: abbreviations[index], target: self, action: #selector(skillButtonPressed(_:)))
            button.tag = index
            button.font = .monospacedSystemFont(ofSize: 5.5, weight: .bold)
            button.frame = NSRect(x: x, y: 2, width: 18, height: 26)
            button.toolTip = fullNames[index]
            button.setButtonType(.toggle)
            button.state = index == LemmingsView.Skill.builder.rawValue ? .on : .off
            view.addSubview(button)
            lemmingsSkillButtons.append(button)
            x += 19
        }

        x += 2
        let actions: [(String, Selector, CGFloat)] = [
            ("⏸", #selector(toggleLemmingsPause), 22),
            ("−", #selector(releaseSlower), 20),
            ("+", #selector(releaseFaster), 20),
            ("☠", #selector(nukeLemmings), 22)
        ]
        for (title, action, width) in actions {
            let button = NSButton(title: title, target: self, action: action)
            button.font = .systemFont(ofSize: 7.5)
            button.frame = NSRect(x: x, y: 2, width: width, height: 26)
            view.addSubview(button)
            x += width + 1
        }

        item.view = view
        item.visibilityPriority = .high
        return item
    }

    private func gamesMenuItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 545, height: 30))
        stack.orientation = .horizontal
        stack.spacing = 2
        stack.distribution = .fillEqually

        let specs: [(String, Selector)] = [
            ("Life", #selector(showLife)),
            ("Pong", #selector(showPong)),
            ("Cave", #selector(showAdventure)),
            ("Break", #selector(showBreakout)),
            ("Snake", #selector(showSnake)),
            ("Pit", #selector(showPitfall)),
            ("E.T.", #selector(showET))
        ]
        for (title, action) in specs {
            let button = NSButton(title: title, target: self, action: action)
            button.font = .systemFont(ofSize: 8)
            stack.addArrangedSubview(button)
        }
        item.view = stack
        return item
    }

    private func buttonItem(identifier: NSTouchBarItem.Identifier, title: String, action: Selector) -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.view = NSButton(title: title, target: self, action: action)
        return item
    }

    @objc private func skillButtonPressed(_ sender: NSButton) {
        guard let skill = LemmingsView.Skill(rawValue: sender.tag) else { return }
        for button in lemmingsSkillButtons { button.state = button === sender ? .on : .off }
        currentLemmingsView?.selectSkill(skill)
    }

    @objc private func toggleLemmingsPause() { currentLemmingsView?.togglePause() }
    @objc private func releaseSlower() { currentLemmingsView?.adjustReleaseRate(by: -10) }
    @objc private func releaseFaster() { currentLemmingsView?.adjustReleaseRate(by: 10) }
    @objc private func nukeLemmings() { currentLemmingsView?.nuke() }

    @objc private func showHome() { mode = .home; rebuildAndPresent() }
    @objc private func showLemmingsMenu() { mode = .lemmingsMenu; rebuildAndPresent() }
    @objc private func startLemmingsPlay() { mode = .lemmingsPlay; rebuildAndPresent() }
    @objc private func startLemmingsDemo() { mode = .lemmingsDemo; rebuildAndPresent() }
    @objc private func showClipboard() { mode = .clipboard; rebuildAndPresent() }
    @objc private func showAudio() { mode = .audio; rebuildAndPresent() }
    @objc private func showMIDI() { mode = .midi; rebuildAndPresent() }
    @objc private func showGames() { mode = .gamesMenu; rebuildAndPresent() }
    @objc private func showPong() { mode = .pong; rebuildAndPresent() }
    @objc private func showSnake() { mode = .snake; rebuildAndPresent() }
    @objc private func showBreakout() { mode = .breakout; rebuildAndPresent() }
    @objc private func showLife() { mode = .life; rebuildAndPresent() }
    @objc private func showPitfall() { mode = .pitfall; rebuildAndPresent() }
    @objc private func showET() { mode = .et; rebuildAndPresent() }
    @objc private func showAdventure() { mode = .adventure; rebuildAndPresent() }
    @objc private func showKITT() { mode = .kitt; rebuildAndPresent() }
    @objc private func showTokiPona() { mode = .tokiPona; rebuildAndPresent() }
}

private final class TouchBarContentHostView: NSView {
    init(content: NSView, preferredWidth: CGFloat) {
        let size = NSSize(width: preferredWidth, height: 30)
        super.init(frame: NSRect(origin: .zero, size: size))
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class FixedTouchBarView: NSView {
    private let fixedSize: NSSize
    init(size: NSSize) {
        fixedSize = size
        super.init(frame: NSRect(origin: .zero, size: size))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var intrinsicContentSize: NSSize { fixedSize }
}

private final class LifeStrokeViewV3: NSView {
    var xHandler: ((CGFloat) -> Void)?
    var endHandler: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        acceptsTouchEvents = true
        allowedTouchTypes = [.direct]
        wantsRestingTouches = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) { xHandler?(convert(event.locationInWindow, from: nil).x) }
    override func mouseDragged(with event: NSEvent) { xHandler?(convert(event.locationInWindow, from: nil).x) }
    override func mouseUp(with event: NSEvent) { endHandler?() }
    override func touchesBegan(with event: NSEvent) { emit(event, phase: .began) }
    override func touchesMoved(with event: NSEvent) { emit(event, phase: .moved) }
    override func touchesEnded(with event: NSEvent) { emit(event, phase: .ended); endHandler?() }
    override func touchesCancelled(with event: NSEvent) { endHandler?() }

    private func emit(_ event: NSEvent, phase: NSTouch.Phase) {
        for touch in event.touches(matching: phase, in: self) {
            xHandler?(touch.location(in: self).x)
        }
    }
}

final class LifeGameViewV3: NSView {
    private let columns = 88
    private let rows = 7
    private var cells: [[Bool]]
    private var history: [[[Bool]]] = []
    private var running = false
    private var drawingMode = false
    private var selectedRow = 3
    private var paintValue: Bool?
    private var accumulator: TimeInterval = 0
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var controlViews: [NSView] = []
    private weak var runButton: NSButton?
    private weak var strokeView: LifeStrokeViewV3?

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }
    private var controlsWidth: CGFloat { drawingMode ? 274 : 206 }

    override init(frame frameRect: NSRect) {
        cells = Array(repeating: Array(repeating: false, count: rows), count: columns)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        seed()
        rebuildControls()
        startTimer()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    override func layout() {
        super.layout()
        strokeView?.frame = NSRect(x: controlsWidth, y: 0, width: max(1, bounds.width - controlsWidth), height: bounds.height)
    }

    private func symbolButton(_ title: String, action: Selector, frame: NSRect, fontSize: CGFloat = 15) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.focusRingType = .none
        button.font = .systemFont(ofSize: fontSize)
        button.frame = frame
        return button
    }

    private func rebuildControls() {
        for view in controlViews { view.removeFromSuperview() }
        controlViews.removeAll()
        runButton = nil

        if drawingMode {
            let close = symbolButton("✕", action: #selector(closeDraw), frame: NSRect(x: 0, y: 0, width: 34, height: 30), fontSize: 16)
            addControl(close)
            for row in 0..<rows {
                let button = symbolButton("\(row + 1)", action: #selector(selectDrawRow(_:)), frame: NSRect(x: 34 + CGFloat(row) * 34, y: 0, width: 34, height: 30), fontSize: 13)
                button.tag = row
                button.font = .monospacedDigitSystemFont(ofSize: row == selectedRow ? 15 : 12, weight: row == selectedRow ? .bold : .regular)
                addControl(button)
            }
        } else {
            let specs: [(String, Selector, CGFloat)] = [
                (running ? "⏸️" : "▶️", #selector(toggleRun), 0),
                ("⬅️", #selector(back), 40),
                ("➡️", #selector(stepButton), 80),
                ("🎲", #selector(randomize), 120),
                ("🖊️", #selector(openDraw), 160)
            ]
            for (title, action, x) in specs {
                let button = symbolButton(title, action: action, frame: NSRect(x: x, y: 0, width: 40, height: 30))
                if x == 0 { runButton = button }
                addControl(button)
            }
        }

        if strokeView == nil {
            let stroke = LifeStrokeViewV3(frame: .zero)
            stroke.xHandler = { [weak self] x in self?.paint(atX: x) }
            stroke.endHandler = { [weak self] in self?.paintValue = nil }
            addSubview(stroke)
            strokeView = stroke
        }
        needsLayout = true
        needsDisplay = true
    }

    private func addControl(_ view: NSView) {
        addSubview(view)
        controlViews.append(view)
    }

    private func startTimer() {
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick)
        lastTick = now
        guard running else { return }
        accumulator += dt
        guard accumulator >= 0.16 else { return }
        accumulator -= 0.16
        step(recordHistory: true)
    }

    private func pushHistory() {
        history.append(cells)
        if history.count > 96 { history.removeFirst() }
    }

    @objc private func toggleRun() {
        running.toggle()
        runButton?.title = running ? "⏸️" : "▶️"
    }
    @objc private func back() {
        running = false
        runButton?.title = "▶️"
        guard let previous = history.popLast() else { return }
        cells = previous
        needsDisplay = true
    }
    @objc private func stepButton() {
        running = false
        runButton?.title = "▶️"
        step(recordHistory: true)
    }
    @objc private func randomize() {
        pushHistory()
        running = false
        runButton?.title = "▶️"
        for x in 0..<columns {
            for y in 0..<rows { cells[x][y] = Int.random(in: 0..<5) == 0 }
        }
        needsDisplay = true
    }
    @objc private func openDraw() {
        drawingMode = true
        running = false
        paintValue = nil
        rebuildControls()
    }
    @objc private func closeDraw() {
        drawingMode = false
        paintValue = nil
        rebuildControls()
    }
    @objc private func selectDrawRow(_ sender: NSButton) {
        selectedRow = max(0, min(rows - 1, sender.tag))
        paintValue = nil
        rebuildControls()
    }

    private func paint(atX xPosition: CGFloat) {
        guard drawingMode, let strokeView else { return }
        let x = max(0, min(columns - 1, Int((xPosition / max(1, strokeView.bounds.width)) * CGFloat(columns))))
        if paintValue == nil {
            pushHistory()
            paintValue = !cells[x][selectedRow]
        }
        cells[x][selectedRow] = paintValue ?? true
        needsDisplay = true
    }

    private func seed() {
        for x in stride(from: 7, to: columns - 7, by: 14) {
            cells[x][2] = true
            cells[x + 1][3] = true
            cells[x + 2][1] = true
            cells[x + 2][2] = true
            cells[x + 2][3] = true
        }
    }

    private func step(recordHistory: Bool) {
        if recordHistory { pushHistory() }
        var next = cells
        for x in 0..<columns {
            for y in 0..<rows {
                var neighbors = 0
                for dx in -1...1 {
                    for dy in -1...1 where !(dx == 0 && dy == 0) {
                        let nx = (x + dx + columns) % columns
                        let ny = (y + dy + rows) % rows
                        if cells[nx][ny] { neighbors += 1 }
                    }
                }
                next[x][y] = neighbors == 3 || (cells[x][y] && neighbors == 2)
            }
        }
        cells = next
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); dirtyRect.fill()
        let gridWidth = max(1, bounds.width - controlsWidth)
        let cellWidth = gridWidth / CGFloat(columns)
        let cellHeight = bounds.height / CGFloat(rows)

        if drawingMode {
            NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
            NSRect(x: controlsWidth, y: CGFloat(selectedRow) * cellHeight, width: gridWidth, height: cellHeight).fill()
        }

        NSColor(calibratedRed: 0.15, green: 0.86, blue: 0.95, alpha: 1).setFill()
        for x in 0..<columns {
            for y in 0..<rows where cells[x][y] {
                NSRect(x: controlsWidth + CGFloat(x) * cellWidth,
                       y: CGFloat(y) * cellHeight,
                       width: max(1, cellWidth - 0.35),
                       height: max(1, cellHeight - 0.35)).fill()
            }
        }
    }
}

private final class TouchBarGameKeyMonitor {
    private var tokens: [Any] = []
    var handler: ((NSEvent, Bool) -> Void)?
    init() {
        if let t = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in self?.handler?(e, true) }) { tokens.append(t) }
        if let t = NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: { [weak self] e in self?.handler?(e, false) }) { tokens.append(t) }
        if let t = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp], handler: { [weak self] e in
            self?.handler?(e, e.type == .keyDown)
            return e
        }) { tokens.append(t) }
    }
    deinit { for token in tokens { NSEvent.removeMonitor(token) } }
}

final class PitfallGameViewV2: NSView {
    private let keyMonitor = TouchBarGameKeyMonitor()
    private var pressed = Set<UInt16>()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var worldX: CGFloat = 0
    private var heroY: CGFloat = 0
    private var verticalVelocity: CGFloat = 0
    private var score = 2000
    private var lives = 3
    private var treasures = 0
    private var timeRemaining: TimeInterval = 20 * 60
    private var collisionCooldown: TimeInterval = 0
    private var animationTime: TimeInterval = 0
    private var deathPause: TimeInterval = 0
    private var respawnDrop: TimeInterval = 0
    private var deathSegment = 0
    private var collectedTreasureScenes = Set<Int>()
    private let controlsRight: CGFloat = 160
    private let heroScreenX: CGFloat = 194

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        keyMonitor.handler = { [weak self] event, down in
            guard let self else { return }
            if down { self.pressed.insert(event.keyCode) } else { self.pressed.remove(event.keyCode) }
            if down && (event.keyCode == 126 || event.keyCode == 13 || event.keyCode == 49) { self.jump() }
        }
        buildControls()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func buildControls() {
        let specs: [(String, Selector, NSRect)] = [
            ("◀", #selector(stepLeft), NSRect(x: 2, y: 2, width: 28, height: 26)),
            ("JUMP", #selector(jumpPressed), NSRect(x: 32, y: 2, width: 46, height: 26)),
            ("▶", #selector(stepRight), NSRect(x: 80, y: 2, width: 28, height: 26)),
            ("KEYS", #selector(focusKeyboard), NSRect(x: 110, y: 2, width: 48, height: 26))
        ]
        for (title, action, frame) in specs {
            let button = NSButton(title: title, target: self, action: action)
            button.font = .systemFont(ofSize: title == "KEYS" ? 7 : 8)
            button.frame = frame
            addSubview(button)
        }
    }

    @objc private func focusKeyboard() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
    @objc private func stepLeft() { if isAlive { worldX -= 15; needsDisplay = true } }
    @objc private func stepRight() { if isAlive { worldX += 15; needsDisplay = true } }
    @objc private func jumpPressed() { jump() }
    private var isAlive: Bool { deathPause <= 0 && respawnDrop <= 0 }
    private func jump() { if isAlive && heroY <= 0.1 { verticalVelocity = 108 } }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick)
        lastTick = now
        animationTime += dt
        timeRemaining = max(0, timeRemaining - dt)
        collisionCooldown = max(0, collisionCooldown - dt)

        if deathPause > 0 {
            deathPause -= dt
            if deathPause <= 0 {
                if lives <= 0 {
                    lives = 3; score = 2000; treasures = 0; timeRemaining = 20 * 60
                    collectedTreasureScenes.removeAll(); deathSegment = 0
                }
                respawnDrop = 0.72
                worldX = CGFloat(deathSegment * 105 + 8)
                heroY = 0
                verticalVelocity = 0
            }
            needsDisplay = true
            return
        }
        if respawnDrop > 0 {
            respawnDrop -= dt
            needsDisplay = true
            return
        }

        var direction: CGFloat = 0
        if pressed.contains(123) || pressed.contains(0) { direction = -1 }
        if pressed.contains(124) || pressed.contains(2) { direction = 1 }
        worldX += direction * 76 * CGFloat(dt)
        verticalVelocity -= 245 * CGFloat(dt)
        heroY = max(0, heroY + verticalVelocity * CGFloat(dt))
        if heroY == 0 && verticalVelocity < 0 { verticalVelocity = 0 }
        detectSceneInteraction()
        needsDisplay = true
    }

    private func detectSceneInteraction() {
        guard collisionCooldown <= 0 else { return }
        let heroWorld = worldX
        let segment = Int(floor(heroWorld / 105))
        let local = heroWorld - CGFloat(segment) * 105
        let pattern = ((segment % 4) + 4) % 4

        if pattern == 0 && heroY < 4 && local > 40 && local < 64 {
            score = max(0, score - 12)
            collisionCooldown = 0.12
        } else if pattern == 1 && heroY < 4 && local > 34 && local < 76 {
            beginDeath(in: segment)
        } else if pattern == 2 && heroY < 4 && local > 47 && local < 69 {
            beginDeath(in: segment)
        } else if pattern == 3 && heroY < 4 && local > 48 && local < 67 && !collectedTreasureScenes.contains(segment) {
            collectedTreasureScenes.insert(segment)
            treasures += 1
            score += 2000
            collisionCooldown = 0.35
        }
    }

    private func beginDeath(in segment: Int) {
        guard isAlive else { return }
        lives -= 1
        deathSegment = segment
        deathPause = 0.42
        collisionCooldown = 1.2
        verticalVelocity = 0
    }

    override func draw(_ dirtyRect: NSRect) {
        let canopy = NSColor(calibratedRed: 0.10, green: 0.34, blue: 0.06, alpha: 1)
        let jungle = NSColor(calibratedRed: 0.32, green: 0.62, blue: 0.23, alpha: 1)
        let ground = NSColor(calibratedRed: 0.76, green: 0.68, blue: 0.24, alpha: 1)
        canopy.setFill(); dirtyRect.fill()
        jungle.setFill(); NSRect(x: controlsRight, y: 6, width: max(0, bounds.width - controlsRight), height: 17).fill()
        ground.setFill(); NSRect(x: controlsRight, y: 4, width: max(0, bounds.width - controlsRight), height: 3).fill()
        NSColor.black.setFill(); NSRect(x: controlsRight, y: 0, width: max(0, bounds.width - controlsRight), height: 4).fill()

        let firstSegment = Int(floor(worldX / 105)) - 2
        for offset in 0..<10 {
            let segment = firstSegment + offset
            let x = heroScreenX + CGFloat(segment) * 105 - worldX
            drawScene(segment: segment, x: x)
        }

        if respawnDrop > 0 {
            let progress = CGFloat(1 - max(0, respawnDrop) / 0.72)
            drawHarry(x: controlsRight + 18, y: 23 - progress * 16)
        } else if deathPause <= 0 {
            drawHarry(x: heroScreenX, y: 7 + heroY)
        }

        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        String(format: "%05d  L%d  T%d  %02d:%02d", score, lives, treasures, minutes, seconds).draw(
            at: NSPoint(x: controlsRight + 4, y: 22),
            withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .bold), .foregroundColor: NSColor.white]
        )
    }

    private func drawScene(segment: Int, x: CGFloat) {
        let pattern = ((segment % 4) + 4) % 4
        NSColor(calibratedRed: 0.38, green: 0.22, blue: 0.03, alpha: 1).setFill()
        NSRect(x: x + 8, y: 7, width: 4, height: 16).fill()
        NSRect(x: x + 92, y: 7, width: 4, height: 16).fill()
        if pattern == 0 {
            let roll = CGFloat(animationTime.truncatingRemainder(dividingBy: 1.0)) * 18
            NSColor(calibratedRed: 0.48, green: 0.25, blue: 0.03, alpha: 1).setFill()
            NSRect(x: x + 55 - roll, y: 7, width: 18, height: 4).fill()
        } else if pattern == 1 {
            NSColor(calibratedRed: 0.13, green: 0.45, blue: 0.66, alpha: 1).setFill()
            NSRect(x: x + 34, y: 4, width: 42, height: 4).fill()
            let jawsOpen = sin(animationTime * 5) > 0
            NSColor(calibratedRed: 0.03, green: 0.27, blue: 0.06, alpha: 1).setFill()
            for gx in stride(from: x + 38, through: x + 68, by: 14) {
                NSRect(x: gx, y: 6, width: 10, height: 2).fill()
                NSRect(x: gx + 2, y: jawsOpen ? 9 : 8, width: 5, height: 1).fill()
            }
            let rope = NSBezierPath()
            rope.move(to: NSPoint(x: x + 55, y: 23))
            rope.line(to: NSPoint(x: x + 47 + sin(animationTime * 2) * 5, y: 11))
            NSColor(calibratedRed: 0.42, green: 0.27, blue: 0.05, alpha: 1).setStroke()
            rope.lineWidth = 1; rope.stroke()
        } else if pattern == 2 {
            NSColor.black.setFill(); NSRect(x: x + 47, y: 3, width: 22, height: 6).fill()
            NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
            let sx = x + 52 + sin(animationTime * 2.5) * 5
            NSRect(x: sx, y: 1, width: 8, height: 2).fill()
            NSRect(x: sx + 7, y: 2, width: 4, height: 1).fill()
            NSRect(x: sx - 2, y: 2, width: 2, height: 1).fill()
        } else if !collectedTreasureScenes.contains(segment) {
            NSColor(calibratedRed: 0.95, green: 0.75, blue: 0.12, alpha: 1).setFill()
            NSRect(x: x + 52, y: 9, width: 10, height: 3).fill()
            NSColor(calibratedRed: 1.0, green: 0.9, blue: 0.35, alpha: 1).setFill()
            NSRect(x: x + 54, y: 12, width: 6, height: 1).fill()
        }
    }

    private func drawHarry(x: CGFloat, y: CGFloat) {
        NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.48, alpha: 1).setFill()
        NSRect(x: x + 2, y: y + 8, width: 4, height: 4).fill()
        NSColor(calibratedRed: 0.12, green: 0.42, blue: 0.16, alpha: 1).setFill()
        NSRect(x: x + 1, y: y + 3, width: 6, height: 6).fill()
        NSColor(calibratedRed: 0.08, green: 0.15, blue: 0.04, alpha: 1).setFill()
        NSRect(x: x, y: y, width: 3, height: 4).fill()
        NSRect(x: x + 5, y: y, width: 3, height: 4).fill()
    }
}

final class ETPixelGameViewV2: NSView {
    private var playerX: CGFloat = 184
    private var pieces = [CGPoint(x: 300, y: 13), CGPoint(x: 470, y: 12), CGPoint(x: 620, y: 15)]
    private var collected = Set<Int>()
    private var score = 8975
    private let sprite: [String] = [
        "..##########..",
        ".############.",
        ".####......###",
        ".####....#####",
        "....########..",
        "...########...",
        "..#####..###..",
        "...###...###..",
        "..####.####...",
        ".####...####.."
    ]

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        buildControls()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildControls() {
        let specs: [(String, Selector, NSRect)] = [
            ("◀", #selector(stepLeft), NSRect(x: 2, y: 2, width: 28, height: 26)),
            ("TAKE", #selector(takePressed), NSRect(x: 32, y: 2, width: 46, height: 26)),
            ("▶", #selector(stepRight), NSRect(x: 80, y: 2, width: 28, height: 26))
        ]
        for (title, action, frame) in specs {
            let button = NSButton(title: title, target: self, action: action)
            button.font = .systemFont(ofSize: 7)
            button.frame = frame
            addSubview(button)
        }
    }

    @objc private func stepLeft() { playerX = max(122, playerX - 16); needsDisplay = true }
    @objc private func stepRight() { playerX = min(bounds.width - 26, playerX + 16); needsDisplay = true }
    @objc private func takePressed() { collectNearby() }

    private func collectNearby() {
        for index in pieces.indices where !collected.contains(index) {
            if abs(pieces[index].x - playerX) < 25 {
                collected.insert(index)
                score += 25
            }
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let field = NSColor(calibratedRed: 90.0 / 255.0, green: 122.0 / 255.0, blue: 64.0 / 255.0, alpha: 1)
        field.setFill(); dirtyRect.fill()
        NSColor(calibratedRed: 22.0 / 255.0, green: 59.0 / 255.0, blue: 11.0 / 255.0, alpha: 1).setFill()
        for rect in [CGRect(x: 250, y: 9, width: 58, height: 5), CGRect(x: 405, y: 18, width: 70, height: 5), CGRect(x: 555, y: 8, width: 68, height: 5)] { rect.fill() }
        for index in pieces.indices where !collected.contains(index) {
            NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.20, alpha: 1).setFill()
            NSRect(x: pieces[index].x, y: pieces[index].y, width: 5, height: 3).fill()
        }
        drawET(at: NSPoint(x: playerX, y: 7))
        let hud = collected.count == pieces.count ? "CALL HOME" : String(format: "%04d  PHONE %d/3", score, collected.count)
        hud.draw(at: NSPoint(x: 120, y: 1), withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .bold), .foregroundColor: NSColor(calibratedRed: 0.04, green: 0.20, blue: 0.04, alpha: 1)])
    }

    private func drawET(at origin: NSPoint) {
        let pixel: CGFloat = 1.0
        NSColor(calibratedRed: 166.0 / 255.0, green: 202.0 / 255.0, blue: 132.0 / 255.0, alpha: 1).setFill()
        for (row, line) in sprite.enumerated() {
            for (column, character) in line.enumerated() where character == "#" {
                let y = origin.y + CGFloat(sprite.count - 1 - row) * pixel
                NSRect(x: origin.x + CGFloat(column) * pixel, y: y, width: pixel, height: pixel).fill()
            }
        }
        NSColor(calibratedRed: 22.0 / 255.0, green: 59.0 / 255.0, blue: 11.0 / 255.0, alpha: 1).setFill()
        NSRect(x: origin.x + 11, y: origin.y + 15, width: 2, height: 1.5).fill()
    }
}

final class TokiPonaStudyView: NSView {
    private struct Entry { let word: String; let meanings: String }
    private static let rawEntries = """
a|ah!; emotion, emphasis, confirmation
akesi|reptile, amphibian; non-cute animal
ala|no, not, nothing; zero
alasa|hunt, forage, seek, try to
ale|all, every, everything; universe; 100
anpa|low, below, bottom; humble, defeated
ante|different, changed, other; change
anu|or
awen|stay, remain, wait, continue; enduring
e|marks the direct object
en|joins multiple subjects
esun|market, shop, trade, exchange
ijo|thing, object, matter, phenomenon
ike|bad, negative, harmful, unnecessary
ilo|tool, device, machine, instrument
insa|inside, center, contents; internal
jaki|dirty, gross, toxic; waste
jan|person, human, somebody
jelo|yellow, yellowish
jo|have, carry, contain, hold
kala|fish; aquatic animal
kalama|sound, noise; make sound, speak aloud
kama|come, arrive, become; future, arriving
kasi|plant, vegetation, herb, leaf
ken|can, may, possible; ability
kepeken|use, using, by means of
kili|fruit, vegetable, mushroom; edible plant part
kiwen|hard object, stone, metal; solid, hard
ko|paste, powder, semi-solid substance
kon|air, breath, wind; spirit, essence
kule|color, pigment; colorful
kulupu|group, community, collection, company
kute|hear, listen; ear, auditory
la|context separator: given X, Y
lape|sleep, rest; sleeping
laso|blue, green, cyan
lawa|head, mind; control, lead, govern
len|cloth, clothing, cover, layer
lete|cold, cool; uncooked, raw
li|separates subject from predicate
lili|small, little, short, young; reduce
linja|line, cord, hair, rope, long flexible thing
lipu|flat object, paper, page, book, document
loje|red, reddish
lon|at, in, on; exist, be present, true
luka|hand, arm; five; touch, handle
lukin|look, see, examine, read; eye
lupa|hole, opening, door, window
ma|land, earth, country, place, outdoors
mama|parent, ancestor, creator, caretaker
mani|money, wealth, valuable possession
meli|woman, female, feminine
mi|I, me, we, us
mije|man, male, masculine
moku|eat, drink, consume; food
moli|dead, dying; kill, death
monsi|back, behind, rear
mu|animal sound; non-speech vocalization
mun|moon, star, night-sky object
musi|fun, play, game, art, entertainment
mute|many, much, several, very; quantity
nanpa|number; ordinal marker
nasa|strange, unusual, silly, drunk, altered
nasin|way, path, road, method, doctrine
nena|bump, hill, mountain, nose, protrusion
ni|this, that, these, those
nimi|word, name
noka|foot, leg; bottom, lower part
o|vocative; command, wish, request marker
olin|love, respect, deep affection
ona|he, she, it, they; him, her, them
open|open, begin, start, turn on
pakala|broken, damaged, mistake; break, harm
pali|work, do, make, build; activity
palisa|long hard object, rod, stick, branch
pan|grain, bread, cereal, starchy staple
pana|give, send, emit, provide, put
pi|regroups modifiers in a noun phrase
pilin|feel, think intuitively; heart, emotion
pimeja|black, dark, shadowy
pini|end, finish, past; closed, completed
pipi|bug, insect, spider, small crawling animal
poka|side, nearby, beside; with, proximity
poki|container, box, bowl, bag, vessel
pona|good, simple, positive, useful; improve, fix
pu|the official Toki Pona book; use/interact with pu
sama|same, similar, equal; like, as
seli|fire, heat, warmth; hot, cooked
selo|outer layer, skin, shell, boundary
seme|what? which? who?; question word
sewi|above, high, upper; sacred, divine
sijelo|body, physical state, torso
sike|circle, sphere, cycle, round object; year
sin|new, fresh, additional, again
sina|you
sinpin|front, face, wall, vertical surface
sitelen|image, symbol, writing; draw, write
sona|know, understand, skill, knowledge
soweli|land mammal; animal
suli|big, tall, long, important, adult; increase
suno|sun, light, brightness, lamp
supa|horizontal surface, table, floor, furniture
suwi|sweet, cute, pleasant, adorable
tan|from, because of, caused by; origin, cause
taso|only, solely; but, however
tawa|go, move; toward, to, for; moving
telo|water, liquid, fluid, beverage; wash
tenpo|time, duration, moment, event, period
toki|speech, language, communication; speak, say
tomo|building, room, house, indoor space
tu|two; divide, split
unpa|sex, sexual activity
uta|mouth, lips, oral opening
utala|fight, conflict, compete, challenge
walo|white, pale, light-colored
wan|one, unique; unite, combine
waso|bird, flying creature
wawa|strong, powerful, energetic, intense
weka|away, absent, removed; remove, discard
wile|want, need, must, should; desire
"""

    private lazy var entries: [Entry] = Self.rawEntries.split(separator: "\n").compactMap { line in
        let pieces = line.split(separator: "|", maxSplits: 1).map(String.init)
        guard pieces.count == 2 else { return nil }
        return Entry(word: pieces[0], meanings: pieces[1])
    }
    private let wordLabel = NSTextField(labelWithString: "")
    private let pronunciationLabel = NSTextField(labelWithString: "")
    private let meaningLabel = NSTextField(labelWithString: "")
    private var timer: Timer?
    private var currentIndex: Int?

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect); buildUI(); showRandomWord(); restartTimer()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder); buildUI(); showRandomWord(); restartTimer()
    }
    deinit { timer?.invalidate() }

    private func buildUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        wordLabel.font = .monospacedSystemFont(ofSize: 16, weight: .bold)
        wordLabel.textColor = .white
        wordLabel.alignment = .right
        pronunciationLabel.font = .monospacedSystemFont(ofSize: 8.5, weight: .medium)
        pronunciationLabel.textColor = NSColor(calibratedRed: 0.55, green: 0.85, blue: 1, alpha: 1)
        pronunciationLabel.alignment = .center
        meaningLabel.font = .systemFont(ofSize: 9.5)
        meaningLabel.textColor = NSColor(calibratedWhite: 0.88, alpha: 1)
        meaningLabel.lineBreakMode = .byTruncatingTail
        wordLabel.frame = NSRect(x: 8, y: 4, width: 118, height: 22)
        pronunciationLabel.frame = NSRect(x: 132, y: 7, width: 112, height: 16)
        meaningLabel.frame = NSRect(x: 258, y: 7, width: max(120, bounds.width - 266), height: 16)
        meaningLabel.autoresizingMask = [.width]
        addSubview(wordLabel); addSubview(pronunciationLabel); addSubview(meaningLabel)

        let hit = NSButton(frame: bounds)
        hit.title = ""; hit.isBordered = false; hit.alphaValue = 0.01
        hit.target = self; hit.action = #selector(nextWord)
        hit.autoresizingMask = [.width, .height]
        addSubview(hit)
    }

    @objc private func nextWord() { showRandomWord(); restartTimer() }
    private func restartTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.showRandomWord() }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }
    private func showRandomWord() {
        guard !entries.isEmpty else { return }
        var next = Int.random(in: 0..<entries.count)
        while entries.count > 1 && next == currentIndex { next = Int.random(in: 0..<entries.count) }
        currentIndex = next
        let entry = entries[next]
        wordLabel.stringValue = entry.word
        pronunciationLabel.stringValue = pronunciation(for: entry.word)
        meaningLabel.stringValue = "•  " + entry.meanings
    }

    private func pronunciation(for word: String) -> String {
        let chars = Array(word)
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        var syllables: [String] = []
        var index = 0
        func consonant(_ c: Character) -> String { c == "j" ? "y" : String(c) }
        func vowel(_ c: Character) -> String {
            switch c { case "a": return "ah"; case "e": return "eh"; case "i": return "ee"; case "o": return "oh"; case "u": return "oo"; default: return String(c) }
        }
        while index < chars.count {
            var syllable = ""
            if !vowels.contains(chars[index]) { syllable += consonant(chars[index]); index += 1 }
            guard index < chars.count, vowels.contains(chars[index]) else { break }
            syllable += vowel(chars[index]); index += 1
            if index < chars.count, chars[index] == "n" {
                let followedByVowel = index + 1 < chars.count && vowels.contains(chars[index + 1])
                if !followedByVowel { syllable += "n"; index += 1 }
            }
            syllables.append(syllable)
        }
        return syllables.enumerated().map { $0.offset == 0 ? $0.element.uppercased() : $0.element.lowercased() }.joined(separator: "-")
    }
}
