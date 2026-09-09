import AppKit

final class KITTScannerView: NSView {
    private let lampCount = 8
    private var intensities = Array(repeating: CGFloat(0), count: 8)
    private var headIndex = 0
    private var direction = 1
    private var timer: Timer?
    private var accumulator: TimeInterval = 0
    private var lastTick = ProcessInfo.processInfo.systemUptime

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }

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
        intensities[0] = 1
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    deinit { timer?.invalidate() }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick)
        lastTick = now
        accumulator += dt

        let decay = CGFloat(pow(0.026, dt))
        for index in intensities.indices {
            intensities[index] *= decay
            if intensities[index] < 0.012 { intensities[index] = 0 }
        }

        if accumulator >= 0.092 {
            accumulator -= 0.092
            headIndex += direction
            if headIndex >= lampCount - 1 {
                headIndex = lampCount - 1
                direction = -1
            } else if headIndex <= 0 {
                headIndex = 0
                direction = 1
            }
        }

        intensities[headIndex] = 1
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        let totalWidth = min(bounds.width - 10, 650)
        let gap: CGFloat = 3
        let lampWidth = (totalWidth - gap * CGFloat(lampCount - 1)) / CGFloat(lampCount)
        let startX = (bounds.width - totalWidth) / 2
        let lampHeight = max(18, bounds.height - 2)
        let y = (bounds.height - lampHeight) / 2

        for index in 0..<lampCount {
            let intensity = intensities[index]
            let x = startX + CGFloat(index) * (lampWidth + gap)

            NSColor(calibratedRed: 0.055, green: 0.0, blue: 0.0, alpha: 1).setFill()
            NSRect(x: x, y: y, width: lampWidth, height: lampHeight).fill()

            guard intensity > 0 else { continue }
            let red = min(1, 0.16 + intensity * 0.94)
            let green = intensity > 0.84 ? (intensity - 0.84) * 0.45 : 0
            NSColor(calibratedRed: red, green: green, blue: 0, alpha: 1).setFill()
            NSRect(x: x + 1, y: y + 1, width: max(1, lampWidth - 2), height: max(1, lampHeight - 2)).fill()

            if intensity > 0.80 {
                NSColor(calibratedRed: 1, green: 0.12, blue: 0.04, alpha: 0.9).setFill()
                NSRect(x: x + 3, y: y + 3, width: max(1, lampWidth - 6), height: max(1, lampHeight - 6)).fill()
            }
        }
    }
}

// MARK: - Conway's Life

private final class LifeStrokeSurfaceV4: NSView {
    var xHandler: ((CGFloat) -> Void)?
    var endHandler: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        acceptsTouchEvents = true
        allowedTouchTypes = [.direct]
        wantsRestingTouches = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        xHandler?(convert(event.locationInWindow, from: nil).x)
    }

    override func mouseDragged(with event: NSEvent) {
        xHandler?(convert(event.locationInWindow, from: nil).x)
    }

    override func mouseUp(with event: NSEvent) {
        endHandler?()
    }

    override func touchesBegan(with event: NSEvent) {
        emit(event, phase: .began)
    }

    override func touchesMoved(with event: NSEvent) {
        emit(event, phase: .moved)
    }

    override func touchesEnded(with event: NSEvent) {
        emit(event, phase: .ended)
        endHandler?()
    }

    override func touchesCancelled(with event: NSEvent) {
        endHandler?()
    }

    private func emit(_ event: NSEvent, phase: NSTouch.Phase) {
        for touch in event.touches(matching: phase, in: self) {
            xHandler?(touch.location(in: self).x)
        }
    }
}

final class LifeGameViewV4: NSView {
    private let columns = 96
    private let rows = 7
    private var cells = Array(repeating: Array(repeating: false, count: 7), count: 96)
    private var history: [[[Bool]]] = []
    private var running = false
    private var drawingMode = false
    private var selectedRow = 3
    private var paintValue: Bool?
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var accumulator: TimeInterval = 0
    private var controls: [NSView] = []
    private weak var runButton: NSButton?
    private weak var strokeSurface: LifeStrokeSurfaceV4?

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }
    private var controlsWidth: CGFloat { drawingMode ? 180 : 140 }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        seed()
        rebuildControls()

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit { timer?.invalidate() }

    override func layout() {
        super.layout()
        strokeSurface?.frame = NSRect(
            x: controlsWidth,
            y: 0,
            width: max(1, bounds.width - controlsWidth),
            height: bounds.height
        )
    }

    private func symbolButton(
        _ title: String,
        action: Selector,
        x: CGFloat,
        width: CGFloat = 28,
        fontSize: CGFloat = 15
    ) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.focusRingType = .none
        button.font = .systemFont(ofSize: fontSize)
        button.frame = NSRect(x: x, y: 1, width: width, height: 28)
        return button
    }

    private func rebuildControls() {
        controls.forEach { $0.removeFromSuperview() }
        controls.removeAll()
        runButton = nil
        strokeSurface?.removeFromSuperview()
        strokeSurface = nil

        if drawingMode {
            var x: CGFloat = 0
            addControl(symbolButton("✕", action: #selector(closeDraw), x: x, width: 25, fontSize: 15))
            x += 25

            for number in 1...7 {
                let button = symbolButton(
                    "\(number)",
                    action: #selector(selectDrawRow(_:)),
                    x: x,
                    width: 22,
                    fontSize: 13
                )
                button.tag = number
                let rowForNumber = rows - number
                button.font = .monospacedDigitSystemFont(
                    ofSize: rowForNumber == selectedRow ? 15 : 12,
                    weight: rowForNumber == selectedRow ? .bold : .regular
                )
                addControl(button)
                x += 22
            }
        } else {
            var x: CGFloat = 0
            let run = symbolButton(running ? "Ⅱ" : "▶︎", action: #selector(toggleRun), x: x)
            addControl(run)
            runButton = run
            x += 28
            addControl(symbolButton("←", action: #selector(back), x: x))
            x += 28
            addControl(symbolButton("→", action: #selector(stepForward), x: x))
            x += 28
            addControl(symbolButton("🎲", action: #selector(randomize), x: x, fontSize: 14))
            x += 28
            addControl(symbolButton("🖊️", action: #selector(openDraw), x: x, fontSize: 13))
        }

        let stroke = LifeStrokeSurfaceV4(frame: .zero)
        stroke.xHandler = { [weak self] x in self?.paint(atX: x) }
        stroke.endHandler = { [weak self] in self?.paintValue = nil }
        addSubview(stroke)
        strokeSurface = stroke

        needsLayout = true
        needsDisplay = true
    }

    private func addControl(_ view: NSView) {
        addSubview(view)
        controls.append(view)
    }

    @objc private func toggleRun() {
        running.toggle()
        runButton?.title = running ? "Ⅱ" : "▶︎"
    }

    @objc private func back() {
        running = false
        runButton?.title = "▶︎"
        guard let previous = history.popLast() else { return }
        cells = previous
        needsDisplay = true
    }

    @objc private func stepForward() {
        running = false
        runButton?.title = "▶︎"
        step(recordHistory: true)
    }

    @objc private func randomize() {
        pushHistory()
        running = false
        runButton?.title = "▶︎"
        for x in 0..<columns {
            for y in 0..<rows {
                cells[x][y] = Int.random(in: 0..<5) == 0
            }
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
        selectedRow = max(0, min(rows - 1, rows - sender.tag))
        paintValue = nil
        rebuildControls()
    }

    private func paint(atX xPosition: CGFloat) {
        guard drawingMode, let strokeSurface else { return }
        let x = max(
            0,
            min(columns - 1, Int((xPosition / max(1, strokeSurface.bounds.width)) * CGFloat(columns)))
        )

        if paintValue == nil {
            pushHistory()
            paintValue = !cells[x][selectedRow]
        }
        cells[x][selectedRow] = paintValue ?? true
        needsDisplay = true
    }

    private func pushHistory() {
        history.append(cells)
        if history.count > 96 { history.removeFirst() }
    }

    private func seed() {
        for x in stride(from: 8, to: columns - 8, by: 16) {
            cells[x][2] = true
            cells[x + 1][3] = true
            cells[x + 2][1] = true
            cells[x + 2][2] = true
            cells[x + 2][3] = true
        }
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
        NSColor.black.setFill()
        dirtyRect.fill()

        let gridWidth = max(1, bounds.width - controlsWidth)
        let cellWidth = gridWidth / CGFloat(columns)
        let cellHeight = bounds.height / CGFloat(rows)

        if drawingMode {
            NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
            NSRect(
                x: controlsWidth,
                y: CGFloat(selectedRow) * cellHeight,
                width: gridWidth,
                height: cellHeight
            ).fill()
        }

        NSColor(calibratedRed: 0.15, green: 0.86, blue: 0.95, alpha: 1).setFill()
        for x in 0..<columns {
            for y in 0..<rows where cells[x][y] {
                NSRect(
                    x: controlsWidth + CGFloat(x) * cellWidth,
                    y: CGFloat(y) * cellHeight,
                    width: max(1, cellWidth - 0.35),
                    height: max(1, cellHeight - 0.35)
                ).fill()
            }
        }
    }
}

// MARK: - Shared game keyboard monitor

private final class TouchBarGameKeyMonitorV3 {
    private var tokens: [Any] = []
    var handler: ((NSEvent, Bool) -> Void)?

    init() {
        if let token = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp], handler: { [weak self] event in
            self?.handler?(event, event.type == .keyDown)
        }) {
            tokens.append(token)
        }

        if let token = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp], handler: { [weak self] event in
            self?.handler?(event, event.type == .keyDown)
            return event
        }) {
            tokens.append(token)
        }
    }

    deinit {
        for token in tokens { NSEvent.removeMonitor(token) }
    }
}

// MARK: - Pitfall

final class PitfallGameViewV3: NSView {
    private let keyMonitor = TouchBarGameKeyMonitorV3()
    private var pressed = Set<UInt16>()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var animationTime: TimeInterval = 0
    private var worldX: CGFloat = 0
    private var heroY: CGFloat = 0
    private var verticalVelocity: CGFloat = 0
    private var score = 2000
    private var lives = 3
    private var treasures = 0
    private var timeRemaining: TimeInterval = 20 * 60
    private var collisionCooldown: TimeInterval = 0
    private var deathPause: TimeInterval = 0
    private var respawnDrop: TimeInterval = 0
    private var deathSegment = 0
    private var collectedTreasureScenes = Set<Int>()

    private let controlsRight: CGFloat = 160
    private let heroScreenX: CGFloat = 202

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        keyMonitor.handler = { [weak self] event, isDown in
            self?.handleKey(event, isDown: isDown)
        }
        buildControls()

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit { timer?.invalidate() }

    private var isAlive: Bool { deathPause <= 0 && respawnDrop <= 0 }

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
        if let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(window.contentView)
        }
    }

    @objc private func stepLeft() {
        guard isAlive else { return }
        worldX -= 15
        needsDisplay = true
    }

    @objc private func stepRight() {
        guard isAlive else { return }
        worldX += 15
        needsDisplay = true
    }

    @objc private func jumpPressed() { jump() }

    private func handleKey(_ event: NSEvent, isDown: Bool) {
        if isDown {
            pressed.insert(event.keyCode)
        } else {
            pressed.remove(event.keyCode)
        }

        if isDown && [126, 13, 49].contains(event.keyCode) {
            jump()
        }
    }

    private func jump() {
        if isAlive && heroY <= 0.1 {
            verticalVelocity = 108
        }
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
                respawnDrop = 0.82
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

        let segment = Int(floor(worldX / 105))
        let local = worldX - CGFloat(segment) * 105
        let pattern = ((segment % 4) + 4) % 4

        if pattern == 0 && heroY < 4 && local > 40 && local < 64 {
            score = max(0, score - 12)
            collisionCooldown = 0.12
        } else if pattern == 1 && heroY < 4 && local > 34 && local < 76 {
            beginDeath(in: segment)
        } else if pattern == 2 && heroY < 4 && local > 47 && local < 69 {
            beginDeath(in: segment)
        } else if pattern == 3,
                  heroY < 1.8,
                  local > 48,
                  local < 67,
                  !collectedTreasureScenes.contains(segment) {
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
        deathPause = 0.68
        collisionCooldown = 1.2
        verticalVelocity = 0
    }

    override func draw(_ dirtyRect: NSRect) {
        let canopy = NSColor(calibratedRed: 0.10, green: 0.34, blue: 0.06, alpha: 1)
        let jungle = NSColor(calibratedRed: 0.32, green: 0.62, blue: 0.23, alpha: 1)
        let ground = NSColor(calibratedRed: 0.76, green: 0.68, blue: 0.24, alpha: 1)

        canopy.setFill()
        dirtyRect.fill()
        jungle.setFill()
        NSRect(x: controlsRight, y: 6, width: max(0, bounds.width - controlsRight), height: 17).fill()
        ground.setFill()
        NSRect(x: controlsRight, y: 4, width: max(0, bounds.width - controlsRight), height: 3).fill()
        NSColor.black.setFill()
        NSRect(x: controlsRight, y: 0, width: max(0, bounds.width - controlsRight), height: 4).fill()

        let firstSegment = Int(floor(worldX / 105)) - 2
        for offset in 0..<10 {
            let segment = firstSegment + offset
            let x = heroScreenX + CGFloat(segment) * 105 - worldX
            drawScene(segment: segment, x: x)
        }

        if respawnDrop > 0 {
            let progress = CGFloat(1 - max(0, respawnDrop) / 0.82)
            drawHarry(x: controlsRight + 18, y: 24 - progress * 17)
        } else if deathPause <= 0 {
            drawHarry(x: heroScreenX, y: 7 + heroY)
        }

        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        let hud = String(format: "%05d  L%d  T%d  %02d:%02d", score, lives, treasures, minutes, seconds)
        hud.draw(
            at: NSPoint(x: controlsRight + 4, y: 22),
            withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .bold),
                .foregroundColor: NSColor.white
            ]
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
            rope.lineWidth = 1
            rope.stroke()
        } else if pattern == 2 {
            NSColor.black.setFill()
            NSRect(x: x + 47, y: 3, width: 22, height: 6).fill()
            NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
            let scorpionX = x + 52 + sin(animationTime * 2.5) * 5
            NSRect(x: scorpionX, y: 1, width: 8, height: 2).fill()
            NSRect(x: scorpionX + 7, y: 2, width: 4, height: 1).fill()
            NSRect(x: scorpionX - 2, y: 2, width: 2, height: 1).fill()
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

// MARK: - Exact E.T. pixel sprite

final class ETPixelGameViewV3: NSView {
    private var playerX: CGFloat = 184
    private var pieces = [CGPoint(x: 300, y: 13), CGPoint(x: 470, y: 12), CGPoint(x: 620, y: 15)]
    private var collected = Set<Int>()
    private var score = 8975

    // Pixel-for-pixel mask transcribed from the user's reference drawing.
    // Rows are stored top-to-bottom; drawET flips only the coordinate system.
    private let sprite: [String] = [
        "..##############",
        "############..##",
        "################",
        "################",
        "####........####",
        "####............",
        "########........",
        "##########......",
        "################",
        "############..##",
        "############....",
        "############....",
        "####..##..##....",
        "####......####..",
        "######....######"
    ]

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        buildControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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

    @objc private func stepLeft() {
        playerX = max(122, playerX - 16)
        needsDisplay = true
    }

    @objc private func stepRight() {
        playerX = min(bounds.width - 26, playerX + 16)
        needsDisplay = true
    }

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
        field.setFill()
        dirtyRect.fill()

        NSColor(calibratedRed: 22.0 / 255.0, green: 59.0 / 255.0, blue: 11.0 / 255.0, alpha: 1).setFill()
        for rect in [
            CGRect(x: 250, y: 9, width: 58, height: 5),
            CGRect(x: 405, y: 18, width: 70, height: 5),
            CGRect(x: 555, y: 8, width: 68, height: 5)
        ] {
            rect.fill()
        }

        for index in pieces.indices where !collected.contains(index) {
            NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.20, alpha: 1).setFill()
            NSRect(x: pieces[index].x, y: pieces[index].y, width: 5, height: 3).fill()
        }

        drawET(at: NSPoint(x: playerX, y: 7))

        let hud = collected.count == pieces.count
            ? "CALL HOME"
            : String(format: "%04d  PHONE %d/3", score, collected.count)
        hud.draw(
            at: NSPoint(x: 120, y: 1),
            withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .bold),
                .foregroundColor: NSColor(calibratedRed: 0.04, green: 0.20, blue: 0.04, alpha: 1)
            ]
        )
    }

    private func drawET(at origin: NSPoint) {
        NSColor(
            calibratedRed: 149.0 / 255.0,
            green: 206.0 / 255.0,
            blue: 117.0 / 255.0,
            alpha: 1
        ).setFill()

        for (row, line) in sprite.enumerated() {
            for (column, character) in line.enumerated() where character == "#" {
                NSRect(
                    x: origin.x + CGFloat(column),
                    y: origin.y + CGFloat(sprite.count - 1 - row),
                    width: 1.05,
                    height: 1.05
                ).fill()
            }
        }
    }
}

// MARK: - Very Small Cave Adventure

final class AdventureTerminalViewV2: NSView {
    private struct Room {
        let description: String
        let exits: [String: String]
    }

    private let rooms: [String: Room] = [
        "mouth": Room(
            description: "You stand at the mouth of a limestone cave. Cool air drifts from a narrow passage leading north. Behind you, steep brush and broken rock make the slope impassable.",
            exits: ["N": "hall"]
        ),
        "hall": Room(
            description: "The passage opens into a low echoing hall. Water ticks from the ceiling into shallow pools. The cave continues east; the entrance lies south.",
            exits: ["S": "mouth", "E": "chamber"]
        ),
        "chamber": Room(
            description: "This rounded stone chamber smells faintly of wet iron. A battered brass lamp rests on a ledge. Passages lead west and north.",
            exits: ["W": "hall", "N": "bridge"]
        ),
        "bridge": Room(
            description: "A narrow natural bridge crosses a black fissure. Pebbles vanish soundlessly into the depth below. The chamber is south; a faint mineral glimmer shows east.",
            exits: ["S": "chamber", "E": "vault"]
        ),
        "vault": Room(
            description: "You enter a quiet mineral vault veined with pale crystal. In a pocket of dry stone, a small treasure gleams. The bridge is west.",
            exits: ["W": "bridge"]
        )
    ]

    private var room = "mouth"
    private var inventory = Set<String>()
    private var lines = [
        "WELCOME TO VERY SMALL CAVE ADVENTURE.",
        "Tap > TYPE, then enter a command. Try LOOK, N, S, E, W, TAKE, INV, or HELP."
    ]
    private var command = ""
    private var editing = false
    private var localMonitor: Any?

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        let typeButton = NSButton(title: "> TYPE", target: self, action: #selector(beginEditing))
        typeButton.font = .monospacedSystemFont(ofSize: 7, weight: .bold)
        typeButton.frame = NSRect(x: 2, y: 2, width: 58, height: 26)
        addSubview(typeButton)

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.editing else { return event }
            self.consumeKey(event)
            return nil
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }

    @objc private func beginEditing() {
        editing = true
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(self)
        }
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        consumeKey(event)
    }

    private func consumeKey(_ event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            submitCommand()
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            if !command.isEmpty { command.removeLast() }
            needsDisplay = true
            return
        }

        guard let characters = event.charactersIgnoringModifiers else { return }
        for scalar in characters.unicodeScalars where scalar.value >= 32 && scalar.value < 127 {
            if command.count < 80 {
                command.append(Character(String(scalar)))
            }
        }
        needsDisplay = true
    }

    private func submitCommand() {
        let raw = command.trimmingCharacters(in: .whitespacesAndNewlines)
        command = ""
        guard !raw.isEmpty else { return }
        appendWrapped("> " + raw.uppercased())
        process(raw.uppercased())
        needsDisplay = true
    }

    private func appendWrapped(_ text: String) {
        var line = ""
        for word in text.split(separator: " ").map(String.init) {
            let candidate = line.isEmpty ? word : line + " " + word
            if candidate.count > 100 {
                if !line.isEmpty { lines.append(line) }
                line = word
            } else {
                line = candidate
            }
        }
        if !line.isEmpty { lines.append(line) }
        while lines.count > 12 { lines.removeFirst() }
    }

    private func process(_ input: String) {
        var normalized = input
        if normalized.hasPrefix("GO ") {
            normalized = String(normalized.dropFirst(3))
        }

        let aliases = ["NORTH": "N", "SOUTH": "S", "EAST": "E", "WEST": "W"]
        normalized = aliases[normalized] ?? normalized

        if ["N", "S", "E", "W"].contains(normalized) {
            if let destination = rooms[room]?.exits[normalized] {
                room = destination
                appendWrapped(rooms[room]?.description ?? "Darkness presses close around you.")
            } else {
                appendWrapped("You can't go that way.")
            }
            return
        }

        switch normalized {
        case "LOOK", "L":
            appendWrapped(rooms[room]?.description ?? "Darkness presses close around you.")
        case "TAKE LAMP", "GET LAMP", "TAKE":
            if room == "chamber" && !inventory.contains("LAMP") {
                inventory.insert("LAMP")
                appendWrapped("You take the battered brass lamp. It is heavier than it looks, but still seems usable.")
            } else if room == "vault" && !inventory.contains("TREASURE") {
                inventory.insert("TREASURE")
                appendWrapped("You lift the small treasure from its stone pocket.")
            } else {
                appendWrapped("There is nothing obvious here that you can take.")
            }
        case "TAKE TREASURE", "GET TREASURE":
            if room == "vault" && !inventory.contains("TREASURE") {
                inventory.insert("TREASURE")
                appendWrapped("You lift the small treasure from its stone pocket.")
            } else {
                appendWrapped("You see no treasure here to take.")
            }
        case "I", "INV", "INVENTORY":
            let contents = inventory.isEmpty
                ? "You are carrying nothing."
                : "You are carrying: " + inventory.sorted().joined(separator: ", ") + "."
            appendWrapped(contents)
        case "HELP":
            appendWrapped("Commands include N, S, E, W, LOOK, TAKE LAMP, TAKE TREASURE, INV, and HELP.")
        default:
            appendWrapped("I don't understand that command.")
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 4.9, weight: .regular),
            .foregroundColor: NSColor(calibratedRed: 0.20, green: 1.0, blue: 0.38, alpha: 1)
        ]

        let lineHeight: CGFloat = 5.7
        var y = bounds.height - lineHeight
        for line in lines.suffix(4) {
            line.draw(at: NSPoint(x: 64, y: y), withAttributes: attributes)
            y -= lineHeight
        }

        let prompt = "> " + command + (editing ? "_" : "▮")
        prompt.draw(at: NSPoint(x: 64, y: 1), withAttributes: attributes)
    }
}

// MARK: - Koi pond

final class KoiPondView: NSView {
    private struct Fish {
        var x: CGFloat
        var y: CGFloat
        var speed: CGFloat
        var direction: CGFloat
        var phase: CGFloat
        var warm: Bool
    }

    private let sampleCount = 180
    private var heightField = [CGFloat](repeating: 0, count: 180)
    private var velocityField = [CGFloat](repeating: 0, count: 180)
    private var fish: [Fish] = [
        Fish(x: 90, y: 9, speed: 20, direction: 1, phase: 0, warm: true),
        Fish(x: 270, y: 19, speed: 14, direction: -1, phase: 1.3, warm: false),
        Fish(x: 470, y: 12, speed: 18, direction: 1, phase: 2.1, warm: true),
        Fish(x: 620, y: 21, speed: 12, direction: -1, phase: 3.4, warm: false)
    ]
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        acceptsTouchEvents = true
        allowedTouchTypes = [.direct]
        wantsRestingTouches = true

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit { timer?.invalidate() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        splash(at: convert(event.locationInWindow, from: nil).x)
    }

    override func mouseDragged(with event: NSEvent) {
        splash(at: convert(event.locationInWindow, from: nil).x, power: 0.45)
    }

    override func touchesBegan(with event: NSEvent) {
        emitTouches(event, phase: .began, power: 1)
    }

    override func touchesMoved(with event: NSEvent) {
        emitTouches(event, phase: .moved, power: 0.35)
    }

    private func emitTouches(_ event: NSEvent, phase: NSTouch.Phase, power: CGFloat) {
        for touch in event.touches(matching: phase, in: self) {
            splash(at: touch.location(in: self).x, power: power)
        }
    }

    private func splash(at x: CGFloat, power: CGFloat = 1) {
        let index = max(2, min(sampleCount - 3, Int((x / max(1, bounds.width)) * CGFloat(sampleCount))))
        velocityField[index] += 5.5 * power
        velocityField[index - 1] += 2.6 * power
        velocityField[index + 1] += 2.6 * power

        for fishIndex in fish.indices where abs(fish[fishIndex].x - x) < 85 {
            fish[fishIndex].direction = fish[fishIndex].x < x ? -1 : 1
            fish[fishIndex].speed = min(30, fish[fishIndex].speed + 5)
        }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.05, now - lastTick)
        lastTick = now

        var nextVelocity = velocityField
        for index in 1..<(sampleCount - 1) {
            let laplacian = heightField[index - 1] + heightField[index + 1] - 2 * heightField[index]
            nextVelocity[index] = (velocityField[index] + laplacian * 0.24) * 0.985
        }
        velocityField = nextVelocity

        for index in 1..<(sampleCount - 1) {
            heightField[index] = (heightField[index] + velocityField[index]) * 0.995
        }

        for index in fish.indices {
            fish[index].phase += CGFloat(dt) * 5
            fish[index].x += fish[index].direction * fish[index].speed * CGFloat(dt)
            fish[index].speed = max(10, fish[index].speed * 0.999)

            if fish[index].x < -20 {
                fish[index].x = bounds.width + 20
            } else if fish[index].x > bounds.width + 20 {
                fish[index].x = -20
            }
        }

        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.015, green: 0.12, blue: 0.16, alpha: 1).setFill()
        dirtyRect.fill()

        for fish in fish {
            drawFish(fish)
        }

        let dx = bounds.width / CGFloat(sampleCount - 1)
        for index in 1..<(sampleCount - 1) {
            let slope = heightField[index + 1] - heightField[index - 1]
            let amplitude = min(1, abs(slope) * 0.22 + abs(heightField[index]) * 0.035)
            guard amplitude > 0.03 else { continue }

            NSColor(
                calibratedRed: 0.18,
                green: 0.75,
                blue: 0.82,
                alpha: 0.18 + amplitude * 0.42
            ).setFill()
            let y = bounds.midY + heightField[index] * 0.28
            NSRect(
                x: CGFloat(index) * dx,
                y: y,
                width: max(1, dx + 0.3),
                height: 1 + amplitude * 2.5
            ).fill()
        }

        NSColor(calibratedRed: 0.06, green: 0.35, blue: 0.36, alpha: 0.32).setStroke()
        for offset: CGFloat in [-7, 7] {
            let path = NSBezierPath()
            for index in 0..<sampleCount {
                let point = NSPoint(
                    x: CGFloat(index) * dx,
                    y: bounds.midY + offset + heightField[index] * 0.12
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.line(to: point)
                }
            }
            path.lineWidth = 0.7
            path.stroke()
        }
    }

    private func drawFish(_ fish: Fish) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: fish.x, yBy: fish.y)
        if fish.direction < 0 {
            transform.scaleX(by: -1, yBy: 1)
        }
        transform.concat()

        let body = fish.warm
            ? NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.10, alpha: 0.82)
            : NSColor(calibratedWhite: 0.92, alpha: 0.76)
        body.setFill()
        NSBezierPath(ovalIn: NSRect(x: -7, y: -2.5, width: 14, height: 5)).fill()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: -6, y: 0))
        tail.line(to: NSPoint(x: -11, y: 4 + sin(fish.phase)))
        tail.line(to: NSPoint(x: -11, y: -4 + sin(fish.phase)))
        tail.close()
        tail.fill()

        NSColor(calibratedWhite: 0.1, alpha: 0.8).setFill()
        NSBezierPath(ovalIn: NSRect(x: 4.2, y: 0.6, width: 1.1, height: 1.1)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}
