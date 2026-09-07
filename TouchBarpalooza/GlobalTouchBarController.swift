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
        case home
        case lemmingsMenu
        case lemmingsPlay
        case lemmingsDemo
        case clipboard
        case audio
        case midi
        case gamesMenu
        case pong
        case snake
        case breakout
        case life
        case pitfall
        case et
        case adventure
        case kitt
        case tokiPona
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
                .touchBarpaloozaLemmings,
                .touchBarpaloozaClipboard,
                .touchBarpaloozaAudio,
                .touchBarpaloozaMIDI,
                .touchBarpaloozaGames,
                .touchBarpaloozaKITT,
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
        case .clipboard: return 690
        case .midi: return 690
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
        case .clipboard:
            content = ClipboardShelfView(frame: frame)
        case .audio:
            content = AudioVisualizerView(frame: frame)
        case .midi:
            content = MIDIControlView(frame: frame)
        case .pong:
            content = MiniGameView(frame: frame, game: .pong)
        case .snake:
            content = MiniGameView(frame: frame, game: .snake)
        case .breakout:
            content = MiniGameView(frame: frame, game: .breakout)
        case .life:
            content = LifeGameViewV2(frame: frame)
        case .pitfall:
            content = PitfallGameView(frame: frame)
        case .et:
            content = ETPixelGameView(frame: frame)
        case .adventure:
            content = AdventureTerminalView(frame: frame)
        case .kitt:
            content = KITTScannerView(frame: frame)
        case .tokiPona:
            content = TokiPonaStudyView(frame: frame)
        default:
            content = NSView(frame: frame)
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

        // Chronological by the first public release of each inspiration:
        // Life (1970), Pong (1972), Adventure (early 1976), Breakout (May 1976),
        // Blockade/Snake (Oct/Nov 1976), Pitfall! (1982), E.T. (Dec 1982).
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

    private func compactButton(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.font = .systemFont(ofSize: 8)
        return button
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

    @objc private func skillChanged(_ sender: NSSegmentedControl) {
        guard let skill = LemmingsView.Skill(rawValue: sender.selectedSegment) else { return }
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

// AppKit intentionally exposes Touch Bar custom touch input as essentially 1-D:
// x is meaningful, y is not. This version makes that explicit. The row selector
// chooses which Life row a horizontal finger stroke edits.
private final class LifeStrokeView: NSView {
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

final class LifeGameViewV2: NSView {
    private let columns = 82
    private let rows = 7
    private let controlsWidth: CGFloat = 284
    private var cells: [[Bool]]
    private var history: [[[Bool]]] = []
    private var running = false
    private var accumulator: TimeInterval = 0
    private var paintValue: Bool?
    private var selectedRow = 3
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private weak var strokeView: LifeStrokeView?

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }

    override init(frame frameRect: NSRect) {
        cells = Array(repeating: Array(repeating: false, count: rows), count: columns)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        seed()
        buildControls()
        startTimer()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func buildControls() {
        let specs: [(String, Selector, NSRect)] = [
            ("RUN", #selector(toggleRun(_:)), NSRect(x: 2, y: 3, width: 37, height: 24)),
            ("BACK", #selector(back), NSRect(x: 41, y: 3, width: 38, height: 24)),
            ("STEP", #selector(stepButton), NSRect(x: 81, y: 3, width: 38, height: 24)),
            ("CLR", #selector(clear), NSRect(x: 121, y: 3, width: 34, height: 24)),
            ("RND", #selector(randomize), NSRect(x: 157, y: 3, width: 34, height: 24))
        ]
        for (title, action, frame) in specs {
            let button = NSButton(title: title, target: self, action: action)
            button.font = .monospacedSystemFont(ofSize: 6.3, weight: .bold)
            button.frame = frame
            addSubview(button)
        }

        let rowControl = NSSegmentedControl(labels: ["1", "2", "3", "4", "5", "6", "7"], trackingMode: .selectOne, target: self, action: #selector(rowChanged(_:)))
        rowControl.selectedSegment = selectedRow
        rowControl.font = .monospacedDigitSystemFont(ofSize: 6, weight: .bold)
        rowControl.frame = NSRect(x: 194, y: 3, width: 86, height: 24)
        for index in 0..<7 { rowControl.setWidth(12, forSegment: index) }
        rowControl.toolTip = "Life row to paint; Touch Bar custom touch input provides horizontal position only"
        addSubview(rowControl)

        let stroke = LifeStrokeView(frame: NSRect(x: controlsWidth, y: 0, width: max(1, bounds.width - controlsWidth), height: bounds.height))
        stroke.autoresizingMask = [.width, .height]
        stroke.xHandler = { [weak self] x in self?.paint(atX: x) }
        stroke.endHandler = { [weak self] in self?.paintValue = nil }
        addSubview(stroke)
        strokeView = stroke
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
        if history.count > 64 { history.removeFirst() }
    }

    @objc private func toggleRun(_ sender: NSButton) {
        running.toggle()
        sender.title = running ? "PAUSE" : "RUN"
    }

    @objc private func back() {
        running = false
        guard let previous = history.popLast() else { return }
        cells = previous
        needsDisplay = true
    }

    @objc private func stepButton() { step(recordHistory: true) }

    @objc private func clear() {
        pushHistory()
        running = false
        cells = Array(repeating: Array(repeating: false, count: rows), count: columns)
        needsDisplay = true
    }

    @objc private func randomize() {
        pushHistory()
        for x in 0..<columns {
            for y in 0..<rows { cells[x][y] = Int.random(in: 0..<5) == 0 }
        }
        needsDisplay = true
    }

    @objc private func rowChanged(_ sender: NSSegmentedControl) {
        selectedRow = max(0, min(rows - 1, sender.selectedSegment))
        paintValue = nil
        needsDisplay = true
    }

    private func paint(atX xPosition: CGFloat) {
        guard let strokeView else { return }
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

        NSColor(calibratedWhite: 0.18, alpha: 1).setFill()
        NSRect(x: controlsWidth, y: CGFloat(selectedRow) * cellHeight, width: gridWidth, height: cellHeight).fill()

        NSColor(calibratedRed: 0.15, green: 0.86, blue: 0.95, alpha: 1).setFill()
        for x in 0..<columns {
            for y in 0..<rows where cells[x][y] {
                NSRect(
                    x: controlsWidth + CGFloat(x) * cellWidth,
                    y: CGFloat(y) * cellHeight,
                    width: max(1, cellWidth - 0.4),
                    height: max(1, cellHeight - 0.4)
                ).fill()
            }
        }
    }
}

final class ETPixelGameView: NSView {
    private var playerX: CGFloat = 184
    private var pieces = [CGPoint(x: 300, y: 13), CGPoint(x: 470, y: 12), CGPoint(x: 620, y: 15)]
    private var collected = Set<Int>()
    private var score = 8975

    // Fresh pixel drawing based directly on the supplied Atari reference,
    // mirrored so the creature faces right. No generated or embedded image asset.
    private let sprite: [String] = [
        "..########..",
        "..##########",
        "..##......##",
        "..##....####",
        "..######.....",
        "..#######....",
        "..##..####...",
        "..##..##.....",
        "...##.###....",
        "..###..###..."
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
    @objc private func stepRight() { playerX = min(bounds.width - 24, playerX + 16); needsDisplay = true }
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
        let field = NSColor(calibratedRed: 0.31, green: 0.47, blue: 0.23, alpha: 1)
        field.setFill(); dirtyRect.fill()

        NSColor(calibratedRed: 0.03, green: 0.22, blue: 0.04, alpha: 1).setFill()
        for rect in [CGRect(x: 250, y: 9, width: 58, height: 5), CGRect(x: 405, y: 18, width: 70, height: 5), CGRect(x: 555, y: 8, width: 68, height: 5)] { rect.fill() }

        for index in pieces.indices where !collected.contains(index) {
            NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.20, alpha: 1).setFill()
            NSRect(x: pieces[index].x, y: pieces[index].y, width: 5, height: 3).fill()
        }

        drawET(at: NSPoint(x: playerX, y: 7))

        let hud = collected.count == pieces.count ? "CALL HOME" : String(format: "%04d  PHONE %d/3", score, collected.count)
        hud.draw(at: NSPoint(x: 120, y: 1), withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 0.04, green: 0.20, blue: 0.04, alpha: 1)
        ])
    }

    private func drawET(at origin: NSPoint) {
        let pixel: CGFloat = 1.35
        let color = NSColor(calibratedRed: 0.67, green: 0.83, blue: 0.49, alpha: 1)
        color.setFill()

        for (row, line) in sprite.enumerated() {
            for (column, character) in line.enumerated() where character == "#" {
                let y = origin.y + CGFloat(sprite.count - 1 - row) * pixel
                NSRect(
                    x: origin.x + CGFloat(column) * pixel,
                    y: y,
                    width: pixel + 0.08,
                    height: pixel + 0.08
                ).fill()
            }
        }

        // Single dark Atari-style eye at the leading/right side of the head.
        NSColor(calibratedRed: 0.08, green: 0.24, blue: 0.06, alpha: 1).setFill()
        NSRect(x: origin.x + 9.2 * pixel, y: origin.y + 8.0 * pixel, width: 1.4 * pixel, height: 1.1 * pixel).fill()
    }
}

final class TokiPonaStudyView: NSView {
    private struct Entry {
        let word: String
        let meanings: String
    }

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
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
        showRandomWord()
        restartTimer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
        showRandomWord()
        restartTimer()
    }

    deinit { timer?.invalidate() }

    private func buildUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        wordLabel.font = .monospacedSystemFont(ofSize: 16, weight: .bold)
        wordLabel.textColor = .white
        wordLabel.alignment = .right

        pronunciationLabel.font = .monospacedSystemFont(ofSize: 8.5, weight: .medium)
        pronunciationLabel.textColor = NSColor(calibratedRed: 0.55, green: 0.85, blue: 1.0, alpha: 1)
        pronunciationLabel.alignment = .center

        meaningLabel.font = .systemFont(ofSize: 9.5)
        meaningLabel.textColor = NSColor(calibratedWhite: 0.88, alpha: 1)
        meaningLabel.lineBreakMode = .byTruncatingTail
        meaningLabel.maximumNumberOfLines = 1

        wordLabel.frame = NSRect(x: 8, y: 4, width: 118, height: 22)
        pronunciationLabel.frame = NSRect(x: 132, y: 7, width: 112, height: 16)
        meaningLabel.frame = NSRect(x: 258, y: 7, width: max(120, bounds.width - 266), height: 16)
        meaningLabel.autoresizingMask = [.width]

        addSubview(wordLabel)
        addSubview(pronunciationLabel)
        addSubview(meaningLabel)

        let hitButton = NSButton(frame: bounds)
        hitButton.title = ""
        hitButton.isBordered = false
        hitButton.target = self
        hitButton.action = #selector(nextWord)
        hitButton.autoresizingMask = [.width, .height]
        hitButton.alphaValue = 0.01
        addSubview(hitButton)
    }

    @objc private func nextWord() {
        showRandomWord()
        restartTimer()
    }

    private func restartTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.showRandomWord()
        }
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }

    private func showRandomWord() {
        guard !entries.isEmpty else { return }
        var next = Int.random(in: 0..<entries.count)
        if entries.count > 1 {
            while next == currentIndex { next = Int.random(in: 0..<entries.count) }
        }
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
            switch c {
            case "a": return "ah"
            case "e": return "eh"
            case "i": return "ee"
            case "o": return "oh"
            case "u": return "oo"
            default: return String(c)
            }
        }

        while index < chars.count {
            var syllable = ""
            if !vowels.contains(chars[index]) {
                syllable += consonant(chars[index])
                index += 1
            }
            guard index < chars.count, vowels.contains(chars[index]) else { break }
            syllable += vowel(chars[index])
            index += 1
            if index < chars.count, chars[index] == "n" {
                let followedByVowel = index + 1 < chars.count && vowels.contains(chars[index + 1])
                if !followedByVowel {
                    syllable += "n"
                    index += 1
                }
            }
            syllables.append(syllable)
        }

        return syllables.enumerated().map { pair in
            pair.offset == 0 ? pair.element.uppercased() : pair.element.lowercased()
        }.joined(separator: "-")
    }
}
