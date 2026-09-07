import AppKit

private func focusTouchBarpaloozaExtras() {
    NSApp.activate(ignoringOtherApps: true)
    if let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first {
        window.makeKeyAndOrderFront(nil)
    }
}

private final class ExtrasKeyMonitor {
    private var tokens: [Any] = []
    var handler: ((NSEvent, Bool) -> Void)?

    init() {
        if let token = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            self?.handler?(event, true)
        }) { tokens.append(token) }
        if let token = NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: { [weak self] event in
            self?.handler?(event, false)
        }) { tokens.append(token) }
        if let token = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp], handler: { [weak self] event in
            self?.handler?(event, event.type == .keyDown)
            return event
        }) { tokens.append(token) }
    }

    deinit {
        for token in tokens { NSEvent.removeMonitor(token) }
    }
}

// MARK: - Conway's Life

private final class DirectLifeCanvas: NSView {
    var pointHandler: ((NSPoint, Bool) -> Void)?
    var endHandler: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureTouch()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureTouch()
    }

    private func configureTouch() {
        acceptsTouchEvents = true
        allowedTouchTypes = [.direct]
        wantsRestingTouches = true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        pointHandler?(convert(event.locationInWindow, from: nil), false)
    }

    override func mouseDragged(with event: NSEvent) {
        pointHandler?(convert(event.locationInWindow, from: nil), true)
    }

    override func mouseUp(with event: NSEvent) {
        endHandler?()
    }

    override func touchesBegan(with event: NSEvent) {
        emitTouches(event, phase: .began, dragging: false)
    }

    override func touchesMoved(with event: NSEvent) {
        emitTouches(event, phase: .moved, dragging: true)
    }

    override func touchesEnded(with event: NSEvent) {
        emitTouches(event, phase: .ended, dragging: true)
        endHandler?()
    }

    override func touchesCancelled(with event: NSEvent) {
        endHandler?()
    }

    private func emitTouches(_ event: NSEvent, phase: NSTouch.Phase, dragging: Bool) {
        for touch in event.touches(matching: phase, in: self) {
            pointHandler?(touch.location(in: self), dragging)
        }
    }
}

final class LifeGameView: NSView {
    private let columns = 96
    private let rows = 7
    private let controlsWidth: CGFloat = 202
    private var cells: [[Bool]] = []
    private var history: [[[Bool]]] = []
    private var running = false
    private var accumulator: TimeInterval = 0
    private var paintValue: Bool?
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private weak var canvas: DirectLifeCanvas?

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        cells = Array(repeating: Array(repeating: false, count: rows), count: columns)
        seed()
        buildControls()
        startTimer()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func buildControls() {
        let specs: [(String, Selector, NSRect)] = [
            ("RUN", #selector(toggleRun(_:)), NSRect(x: 2, y: 3, width: 38, height: 24)),
            ("BACK", #selector(back), NSRect(x: 42, y: 3, width: 38, height: 24)),
            ("STEP", #selector(stepButton), NSRect(x: 82, y: 3, width: 38, height: 24)),
            ("CLR", #selector(clear), NSRect(x: 122, y: 3, width: 36, height: 24)),
            ("RND", #selector(randomize), NSRect(x: 160, y: 3, width: 36, height: 24))
        ]
        for (title, action, frame) in specs {
            let button = NSButton(title: title, target: self, action: action)
            button.font = .monospacedSystemFont(ofSize: 6.5, weight: .bold)
            button.frame = frame
            addSubview(button)
        }

        let canvas = DirectLifeCanvas(frame: NSRect(x: controlsWidth, y: 0, width: max(1, bounds.width - controlsWidth), height: bounds.height))
        canvas.autoresizingMask = [.width, .height]
        canvas.pointHandler = { [weak self] point, dragging in self?.paint(at: point, dragging: dragging) }
        canvas.endHandler = { [weak self] in self?.paintValue = nil }
        addSubview(canvas)
        self.canvas = canvas
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

    private func paint(at point: NSPoint, dragging: Bool) {
        guard let canvas else { return }
        let x = max(0, min(columns - 1, Int((point.x / max(1, canvas.bounds.width)) * CGFloat(columns))))
        let y = max(0, min(rows - 1, Int((point.y / max(1, canvas.bounds.height)) * CGFloat(rows))))
        if paintValue == nil {
            pushHistory()
            paintValue = !cells[x][y]
        }
        cells[x][y] = paintValue ?? true
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
                        // Toroidal universe: left/right and top/bottom both wrap.
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

// MARK: - Pitfall!-style jungle runner

final class PitfallGameView: NSView {
    private let keyMonitor = ExtrasKeyMonitor()
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
        let left = NSButton(title: "◀", target: self, action: #selector(stepLeft))
        left.frame = NSRect(x: 2, y: 2, width: 28, height: 26)
        addSubview(left)

        let jump = NSButton(title: "JUMP", target: self, action: #selector(jumpPressed))
        jump.font = .systemFont(ofSize: 7)
        jump.frame = NSRect(x: 32, y: 2, width: 46, height: 26)
        addSubview(jump)

        let right = NSButton(title: "▶", target: self, action: #selector(stepRight))
        right.frame = NSRect(x: 80, y: 2, width: 28, height: 26)
        addSubview(right)

        let keys = NSButton(title: "KEYS", target: self, action: #selector(focusKeyboard))
        keys.font = .monospacedSystemFont(ofSize: 7, weight: .bold)
        keys.frame = NSRect(x: 110, y: 2, width: 48, height: 26)
        addSubview(keys)
    }

    @objc private func focusKeyboard() { focusTouchBarpaloozaExtras() }
    @objc private func stepLeft() { if isAlive { worldX -= 15; needsDisplay = true } }
    @objc private func stepRight() { if isAlive { worldX += 15; needsDisplay = true } }
    @objc private func jumpPressed() { jump() }

    private var isAlive: Bool { deathPause <= 0 && respawnDrop <= 0 }

    private func jump() {
        if isAlive && heroY <= 0.1 { verticalVelocity = 108 }
    }

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
                    lives = 3
                    score = 2000
                    treasures = 0
                    timeRemaining = 20 * 60
                    collectedTreasureScenes.removeAll()
                    deathSegment = 0
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

        // worldX is the world coordinate that is directly under Harry. The old
        // code added heroScreenX a second time, so Harry could die from hazards
        // that were still far ahead of him on screen.
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
        } else if pattern == 3 && local > 48 && local < 67 && !collectedTreasureScenes.contains(segment) {
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
            // In the original game, a replacement Harry drops from the trees on
            // the left side of the screen after a lost life.
            let progress = CGFloat(1 - max(0, respawnDrop) / 0.72)
            let dropY = 23 - progress * 16
            drawHarry(x: controlsRight + 18, y: dropY)
        } else if deathPause <= 0 {
            drawHarry(x: heroScreenX, y: 7 + heroY)
        }

        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        let hud = String(format: "%05d  L%d  T%d  %02d:%02d", score, lives, treasures, minutes, seconds)
        hud.draw(at: NSPoint(x: controlsRight + 4, y: 22), withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 6.0, weight: .bold),
            .foregroundColor: NSColor.white
        ])
    }

    private func drawScene(segment: Int, x: CGFloat) {
        let pattern = ((segment % 4) + 4) % 4
        let trunk = NSColor(calibratedRed: 0.38, green: 0.22, blue: 0.03, alpha: 1)
        trunk.setFill(); NSRect(x: x + 8, y: 7, width: 4, height: 16).fill(); NSRect(x: x + 92, y: 7, width: 4, height: 16).fill()

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

// MARK: - E.T. Atari-style homage

final class ETGameView: NSView {
    private static let spriteBase64 = "iVBORw0KGgoAAAANSUhEUgAAAGIAAABcCAYAAACV1WDTAAABqUlEQVR42u3cQXLCMBBE0YzKR89ZcphcSlmlilUgWLJG49crFsaI+WpN2wLH1/fnB63XcfL9XQlPKX5fNBCWqp8FAcJgGE0dcqhxw54gQLgoNSn0iyln9ERtIAyD8Ooxf4IAYVyB46wjaLPUdOsLr1mBBoixBX57iT/UN0d85wg9goAAgoAAgoAAgoAAgoAooKvvNcVm9ekVHREbTtSoBmJHCJeOXY/QrLni8dxArIURq1ITGJYmPYKAAGLZFSoQYJzS1alpNIzgiBzqQIABhGbNFUBUh1HtXtMzGMERXAPEDjCkJiC4AoiEMO6+Q7caRnBEsokARBIYQGjWBERC+V3TmylndArjiHEQXj0GiMkQTsEAQrPmoMdjgUjSU6SmJM7gCD2CgACCgACCgACCgACCgCigbM9r6snPX8IRU3e4Ljh/CRCzd7im76DpEZr1UmWb4f3Ojsi25k+FkX2HLtt6Pu0/enpEEtcAkQQGEDdLTZ0r8jgCjESpadsnA8z+vm13S1cB1Xa3dBUYUlOy1JRpbY4in/GvsbRkg4uin/V0DEfx1LKNM34AFAM0z9hmIXMAAAAASUVORK5CYII="

    private let keyMonitor = ExtrasKeyMonitor()
    private var pressed = Set<UInt16>()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var playerX: CGFloat = 178
    private var pieces = [CGPoint(x: 285, y: 13), CGPoint(x: 455, y: 12), CGPoint(x: 615, y: 15)]
    private var collected = Set<Int>()
    private var score = 8975
    private lazy var spriteImage: NSImage? = {
        guard let data = Data(base64Encoded: Self.spriteBase64) else { return nil }
        return NSImage(data: data)
    }()

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        keyMonitor.handler = { [weak self] event, down in
            guard let self else { return }
            if down { self.pressed.insert(event.keyCode) } else { self.pressed.remove(event.keyCode) }
            if down && event.keyCode == 49 { self.collectNearby() }
        }
        buildControls()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func buildControls() {
        let left = NSButton(title: "◀", target: self, action: #selector(stepLeft))
        left.frame = NSRect(x: 2, y: 2, width: 28, height: 26)
        addSubview(left)

        let take = NSButton(title: "TAKE", target: self, action: #selector(takePressed))
        take.font = .systemFont(ofSize: 7)
        take.frame = NSRect(x: 32, y: 2, width: 46, height: 26)
        addSubview(take)

        let right = NSButton(title: "▶", target: self, action: #selector(stepRight))
        right.frame = NSRect(x: 80, y: 2, width: 28, height: 26)
        addSubview(right)

        let keys = NSButton(title: "KEYS", target: self, action: #selector(focusKeyboard))
        keys.font = .monospacedSystemFont(ofSize: 7, weight: .bold)
        keys.frame = NSRect(x: 110, y: 2, width: 48, height: 26)
        addSubview(keys)
    }

    @objc private func focusKeyboard() { focusTouchBarpaloozaExtras() }
    @objc private func stepLeft() { playerX = max(168, playerX - 16); needsDisplay = true }
    @objc private func stepRight() { playerX = min(bounds.width - 28, playerX + 16); needsDisplay = true }
    @objc private func takePressed() { collectNearby() }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick)
        lastTick = now
        if pressed.contains(123) || pressed.contains(0) { playerX -= 82 * CGFloat(dt) }
        if pressed.contains(124) || pressed.contains(2) { playerX += 82 * CGFloat(dt) }
        playerX = max(168, min(bounds.width - 28, playerX))
        needsDisplay = true
    }

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
        // Match the field and sprite palette in the supplied Atari E.T. reference.
        let field = NSColor(calibratedRed: 90.0 / 255.0, green: 122.0 / 255.0, blue: 64.0 / 255.0, alpha: 1)
        field.setFill(); dirtyRect.fill()

        NSColor(calibratedRed: 0.60, green: 0.02, blue: 0.46, alpha: 1).setFill()
        NSRect(x: 160, y: bounds.height - 3, width: max(0, bounds.width - 160), height: 3).fill()
        NSColor(calibratedRed: 0.42, green: 0.63, blue: 0.88, alpha: 1).setFill()
        NSRect(x: 160, y: 0, width: max(0, bounds.width - 160), height: 4).fill()

        let pit = NSColor(calibratedRed: 0.01, green: 0.22, blue: 0.06, alpha: 1)
        pit.setFill()
        for rect in [CGRect(x: 210, y: 9, width: 58, height: 5), CGRect(x: 370, y: 18, width: 70, height: 5), CGRect(x: 535, y: 8, width: 68, height: 5)] { rect.fill() }

        for index in pieces.indices where !collected.contains(index) {
            NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.20, alpha: 1).setFill()
            NSRect(x: pieces[index].x, y: pieces[index].y, width: 5, height: 3).fill()
        }

        if let image = spriteImage {
            NSGraphicsContext.current?.imageInterpolation = .none
            image.draw(in: NSRect(x: playerX, y: 4, width: 26, height: 24), from: .zero, operation: .sourceOver, fraction: 1)
        }

        let hud = collected.count == pieces.count ? "CALL HOME" : String(format: "%04d  PHONE %d/3", score, collected.count)
        hud.draw(at: NSPoint(x: 162, y: 1), withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 0.04, green: 0.24, blue: 0.05, alpha: 1)
        ])
    }
}
