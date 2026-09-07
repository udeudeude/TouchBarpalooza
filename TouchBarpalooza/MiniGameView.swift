import AppKit

private func focusTouchBarpalooza() {
    NSApp.activate(ignoringOtherApps: true)
    if let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first {
        window.makeKeyAndOrderFront(nil)
    }
}

private final class GameKeyMonitor {
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

private final class LifeGridButton: NSButton {
    var pointHandler: ((CGPoint, Bool) -> Void)?
    var endHandler: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func draw(_ dirtyRect: NSRect) {}

    override func mouseDown(with event: NSEvent) {
        pointHandler?(convert(event.locationInWindow, from: nil), false)
    }

    override func mouseDragged(with event: NSEvent) {
        pointHandler?(convert(event.locationInWindow, from: nil), true)
    }

    override func mouseUp(with event: NSEvent) {
        endHandler?()
    }
}

final class MiniGameView: NSView {
    enum Game {
        case pong, snake, breakout, life
    }

    private struct Brick {
        var rect: CGRect
        let row: Int
    }

    private let game: Game
    private let keyMonitor = GameKeyMonitor()
    private var pressedKeys = Set<UInt16>()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime

    // Pong
    private var ball = CGPoint(x: 160, y: 12)
    private var velocity = CGVector(dx: 110, dy: 62)
    private var leftPaddleY: CGFloat = 8
    private var rightPaddleY: CGFloat = 8
    private var leftScore = 0
    private var rightScore = 0
    private let pongPaddleHeight: CGFloat = 9
    private var serveFromLeft = true

    // Snake
    private let snakeCell: CGFloat = 5
    private var snake: [CGPoint] = []
    private var snakeDirection = CGPoint(x: 1, y: 0)
    private var pendingSnakeDirection = CGPoint(x: 1, y: 0)
    private var snakeAccumulator: TimeInterval = 0
    private var food = CGPoint(x: 35, y: 3)
    private var snakeScore = 0

    // Breakout
    private var paddleX: CGFloat = 80
    private var bricks: [Brick] = []
    private var breakoutLives = 3
    private var breakoutScore = 0

    // Life
    private let lifeColumns = 96
    private let lifeRows = 7
    private var life: [[Bool]] = []
    private var lifeHistory: [[[Bool]]] = []
    private var lifeAccumulator: TimeInterval = 0
    private var lifeRunning = false
    private var lifePaintValue: Bool?
    private let lifeControlsWidth: CGFloat = 202
    private var lifeGridButton: LifeGridButton?

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    init(frame frameRect: NSRect, game: Game) {
        self.game = game
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        game = .pong
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        keyMonitor.handler = { [weak self] event, down in self?.handleKey(event, down: down) }
        resetGame(full: true)

        if game == .life { buildLifeControls() }
        else { addKeyboardFocusButton() }

        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    deinit { timer?.invalidate() }

    private func addKeyboardFocusButton() {
        let button = NSButton(title: "KEYS", target: self, action: #selector(focusKeyboard))
        button.font = .monospacedSystemFont(ofSize: 7, weight: .bold)
        button.frame = NSRect(x: 2, y: 2, width: 43, height: 26)
        button.toolTip = "Bring TouchBarpalooza to the front for keyboard controls"
        addSubview(button)
    }

    @objc private func focusKeyboard() { focusTouchBarpalooza() }

    private func handleKey(_ event: NSEvent, down: Bool) {
        if down { pressedKeys.insert(event.keyCode) } else { pressedKeys.remove(event.keyCode) }
        guard down, game == .snake else { return }

        switch event.keyCode {
        case 123, 0: setSnakeDirection(x: -1, y: 0) // left / A
        case 124, 2: setSnakeDirection(x: 1, y: 0)  // right / D
        case 125, 1: setSnakeDirection(x: 0, y: -1) // down / S
        case 126, 13: setSnakeDirection(x: 0, y: 1) // up / W
        default: break
        }
    }

    private func resetGame(full: Bool) {
        switch game {
        case .pong:
            if full {
                leftScore = 0
                rightScore = 0
                serveFromLeft = true
            }
            resetPongServe()
        case .snake:
            snake = [CGPoint(x: 15, y: 3), CGPoint(x: 14, y: 3), CGPoint(x: 13, y: 3)]
            snakeDirection = CGPoint(x: 1, y: 0)
            pendingSnakeDirection = snakeDirection
            snakeAccumulator = 0
            if full { snakeScore = 0 }
            placeFood()
        case .breakout:
            if full {
                breakoutLives = 3
                breakoutScore = 0
                buildBricks()
            }
            resetBreakoutBall()
        case .life:
            life = Array(repeating: Array(repeating: false, count: lifeRows), count: lifeColumns)
            lifeHistory.removeAll()
            seedLife()
            lifeRunning = false
        }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick)
        lastTick = now

        switch game {
        case .pong: updatePong(dt)
        case .snake: updateSnake(dt)
        case .breakout: updateBreakout(dt)
        case .life: updateLife(dt)
        }
        needsDisplay = true
    }

    // MARK: Pong

    private func resetPongServe() {
        ball = CGPoint(x: max(90, bounds.width * 0.5), y: max(8, bounds.height * 0.5))
        velocity = CGVector(dx: serveFromLeft ? 112 : -112, dy: Bool.random() ? 62 : -62)
        serveFromLeft.toggle()
        leftPaddleY = max(1, bounds.midY - pongPaddleHeight / 2)
        rightPaddleY = leftPaddleY
    }

    private func updatePong(_ dt: TimeInterval) {
        let paddleSpeed: CGFloat = 150
        if pressedKeys.contains(13) { leftPaddleY += paddleSpeed * CGFloat(dt) }
        if pressedKeys.contains(1) { leftPaddleY -= paddleSpeed * CGFloat(dt) }
        if pressedKeys.contains(126) { rightPaddleY += paddleSpeed * CGFloat(dt) }
        if pressedKeys.contains(125) { rightPaddleY -= paddleSpeed * CGFloat(dt) }

        leftPaddleY = max(1, min(bounds.height - pongPaddleHeight - 1, leftPaddleY))
        rightPaddleY = max(1, min(bounds.height - pongPaddleHeight - 1, rightPaddleY))

        ball.x += velocity.dx * CGFloat(dt)
        ball.y += velocity.dy * CGFloat(dt)

        if ball.y <= 2 { ball.y = 2; velocity.dy = abs(velocity.dy) }
        else if ball.y >= bounds.height - 2 { ball.y = bounds.height - 2; velocity.dy = -abs(velocity.dy) }

        let leftX: CGFloat = 50
        if velocity.dx < 0,
           ball.x <= leftX + 8, ball.x >= leftX,
           ball.y >= leftPaddleY - 2, ball.y <= leftPaddleY + pongPaddleHeight + 2 {
            ball.x = leftX + 8
            velocity.dx = abs(velocity.dx) * 1.025
            let offset = (ball.y - (leftPaddleY + pongPaddleHeight / 2)) / (pongPaddleHeight / 2)
            velocity.dy += offset * 35
        }

        if velocity.dx > 0,
           ball.x >= bounds.width - 16, ball.x <= bounds.width - 8,
           ball.y >= rightPaddleY - 2, ball.y <= rightPaddleY + pongPaddleHeight + 2 {
            ball.x = bounds.width - 16
            velocity.dx = -abs(velocity.dx) * 1.025
            let offset = (ball.y - (rightPaddleY + pongPaddleHeight / 2)) / (pongPaddleHeight / 2)
            velocity.dy += offset * 35
        }

        if ball.x < -4 {
            rightScore += 1
            resetPongServe()
        } else if ball.x > bounds.width + 4 {
            leftScore += 1
            resetPongServe()
        }
    }

    // MARK: Snake

    private func setSnakeDirection(x: CGFloat, y: CGFloat) {
        let proposed = CGPoint(x: x, y: y)
        if proposed.x == -snakeDirection.x && proposed.y == -snakeDirection.y { return }
        pendingSnakeDirection = proposed
    }

    private func placeFood() {
        let cols = max(24, Int(bounds.width / snakeCell))
        let rows = max(4, Int(bounds.height / snakeCell))
        repeat {
            food = CGPoint(x: CGFloat(Int.random(in: 0..<cols)), y: CGFloat(Int.random(in: 0..<rows)))
        } while snake.contains(food)
    }

    private func updateSnake(_ dt: TimeInterval) {
        snakeAccumulator += dt
        guard snakeAccumulator >= 0.115 else { return }
        snakeAccumulator -= 0.115
        guard let head = snake.first else { return }

        snakeDirection = pendingSnakeDirection
        var next = CGPoint(x: head.x + snakeDirection.x, y: head.y + snakeDirection.y)
        let cols = max(24, Int(bounds.width / snakeCell))
        let rows = max(4, Int(bounds.height / snakeCell))

        if next.x < 0 { next.x = CGFloat(cols - 1) }
        else if next.x >= CGFloat(cols) { next.x = 0 }
        if next.y < 0 { next.y = CGFloat(rows - 1) }
        else if next.y >= CGFloat(rows) { next.y = 0 }

        if snake.contains(next) {
            resetGame(full: true)
            return
        }

        snake.insert(next, at: 0)
        if next == food {
            snakeScore += 1
            placeFood()
        } else {
            snake.removeLast()
        }
    }

    // MARK: Breakout

    private func buildBricks() {
        bricks.removeAll()
        let columns = 20
        let rows = 3
        let gap: CGFloat = 2
        let sideMargin: CGFloat = 8
        let usable = max(180, bounds.width - sideMargin * 2)
        let brickWidth = (usable - gap * CGFloat(columns - 1)) / CGFloat(columns)
        for row in 0..<rows {
            for column in 0..<columns {
                let x = sideMargin + CGFloat(column) * (brickWidth + gap)
                let y = bounds.height - 5 - CGFloat(row) * 5
                bricks.append(Brick(rect: CGRect(x: x, y: y, width: brickWidth, height: 3.5), row: row))
            }
        }
    }

    private func resetBreakoutBall() {
        paddleX = max(55, bounds.width * 0.5)
        ball = CGPoint(x: paddleX, y: 8)
        velocity = CGVector(dx: Bool.random() ? 76 : -76, dy: 105)
    }

    private func updateBreakout(_ dt: TimeInterval) {
        let paddleSpeed: CGFloat = 190
        if pressedKeys.contains(123) || pressedKeys.contains(0) { paddleX -= paddleSpeed * CGFloat(dt) }
        if pressedKeys.contains(124) || pressedKeys.contains(2) { paddleX += paddleSpeed * CGFloat(dt) }
        paddleX = max(48, min(bounds.width - 38, paddleX))

        ball.x += velocity.dx * CGFloat(dt)
        ball.y += velocity.dy * CGFloat(dt)
        if ball.x <= 2 { ball.x = 2; velocity.dx = abs(velocity.dx) }
        else if ball.x >= bounds.width - 2 { ball.x = bounds.width - 2; velocity.dx = -abs(velocity.dx) }
        if ball.y >= bounds.height - 1 { ball.y = bounds.height - 1; velocity.dy = -abs(velocity.dy) }

        let paddleRect = CGRect(x: paddleX - 30, y: 2, width: 60, height: 3)
        let ballRect = CGRect(x: ball.x - 2, y: ball.y - 2, width: 4, height: 4)
        if velocity.dy < 0 && paddleRect.intersects(ballRect) {
            ball.y = paddleRect.maxY + 2
            let hit = max(-1, min(1, (ball.x - paddleX) / 30))
            velocity.dx = hit * 125
            velocity.dy = abs(velocity.dy) * 1.015
        }

        if let index = bricks.firstIndex(where: { $0.rect.intersects(ballRect) }) {
            let brick = bricks[index]
            bricks.remove(at: index)
            breakoutScore += 10
            let horizontalPenetration = min(abs(ballRect.maxX - brick.rect.minX), abs(brick.rect.maxX - ballRect.minX))
            let verticalPenetration = min(abs(ballRect.maxY - brick.rect.minY), abs(brick.rect.maxY - ballRect.minY))
            if horizontalPenetration < verticalPenetration { velocity.dx *= -1 }
            else { velocity.dy *= -1 }
            if bricks.isEmpty {
                buildBricks()
                resetBreakoutBall()
            }
        }

        if ball.y < -4 {
            breakoutLives -= 1
            if breakoutLives <= 0 { resetGame(full: true) }
            else { resetBreakoutBall() }
        }
    }

    // MARK: Life

    private func buildLifeControls() {
        let specs: [(String, Selector, NSRect)] = [
            ("RUN", #selector(toggleLife), NSRect(x: 2, y: 3, width: 38, height: 24)),
            ("BACK", #selector(backLife), NSRect(x: 42, y: 3, width: 38, height: 24)),
            ("STEP", #selector(stepLifeButton), NSRect(x: 82, y: 3, width: 38, height: 24)),
            ("CLR", #selector(clearLife), NSRect(x: 122, y: 3, width: 36, height: 24)),
            ("RND", #selector(randomLife), NSRect(x: 160, y: 3, width: 36, height: 24))
        ]
        for (title, action, frame) in specs {
            let button = NSButton(title: title, target: self, action: action)
            button.font = .monospacedSystemFont(ofSize: 6.5, weight: .bold)
            button.frame = frame
            addSubview(button)
        }

        let grid = LifeGridButton(frame: NSRect(x: lifeControlsWidth, y: 0, width: max(1, bounds.width - lifeControlsWidth), height: bounds.height))
        grid.title = ""
        grid.isBordered = false
        grid.focusRingType = .none
        grid.autoresizingMask = [.width, .height]
        grid.pointHandler = { [weak self] point, dragging in self?.paintLife(point, dragging: dragging) }
        grid.endHandler = { [weak self] in self?.lifePaintValue = nil }
        addSubview(grid)
        lifeGridButton = grid
    }

    private func pushLifeHistory() {
        lifeHistory.append(life)
        if lifeHistory.count > 64 { lifeHistory.removeFirst() }
    }

    @objc private func toggleLife(_ sender: NSButton) {
        lifeRunning.toggle()
        sender.title = lifeRunning ? "PAUSE" : "RUN"
    }

    @objc private func stepLifeButton() { stepLife(recordHistory: true) }

    @objc private func backLife() {
        lifeRunning = false
        guard let previous = lifeHistory.popLast() else { return }
        life = previous
        needsDisplay = true
    }

    @objc private func clearLife() {
        pushLifeHistory()
        life = Array(repeating: Array(repeating: false, count: lifeRows), count: lifeColumns)
        lifeRunning = false
        needsDisplay = true
    }

    @objc private func randomLife() {
        pushLifeHistory()
        for x in 0..<lifeColumns {
            for y in 0..<lifeRows { life[x][y] = Int.random(in: 0..<5) == 0 }
        }
        needsDisplay = true
    }

    private func paintLife(_ point: CGPoint, dragging: Bool) {
        guard let grid = lifeGridButton else { return }
        let width = max(1, grid.bounds.width)
        let height = max(1, grid.bounds.height)
        let x = max(0, min(lifeColumns - 1, Int((point.x / width) * CGFloat(lifeColumns))))
        let y = max(0, min(lifeRows - 1, Int((point.y / height) * CGFloat(lifeRows))))
        if lifePaintValue == nil {
            pushLifeHistory()
            lifePaintValue = !life[x][y]
        }
        life[x][y] = lifePaintValue ?? true
        needsDisplay = true
    }

    private func seedLife() {
        guard lifeColumns > 12, lifeRows > 4 else { return }
        for x in stride(from: 7, to: lifeColumns - 7, by: 14) {
            life[x][2] = true
            life[x + 1][3] = true
            life[x + 2][1] = true
            life[x + 2][2] = true
            life[x + 2][3] = true
        }
    }

    private func updateLife(_ dt: TimeInterval) {
        guard lifeRunning else { return }
        lifeAccumulator += dt
        guard lifeAccumulator >= 0.16 else { return }
        lifeAccumulator -= 0.16
        stepLife(recordHistory: true)
    }

    private func stepLife(recordHistory: Bool) {
        if recordHistory { pushLifeHistory() }
        var next = life
        for x in 0..<lifeColumns {
            for y in 0..<lifeRows {
                var neighbors = 0
                for dx in -1...1 {
                    for dy in -1...1 where !(dx == 0 && dy == 0) {
                        let nx = (x + dx + lifeColumns) % lifeColumns
                        let ny = (y + dy + lifeRows) % lifeRows
                        if life[nx][ny] { neighbors += 1 }
                    }
                }
                next[x][y] = neighbors == 3 || (life[x][y] && neighbors == 2)
            }
        }
        life = next
        needsDisplay = true
    }

    // MARK: Touch interaction for the non-button games

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        switch game {
        case .pong:
            if p.x < bounds.midX { leftPaddleY = max(1, min(bounds.height - pongPaddleHeight - 1, p.y - pongPaddleHeight / 2)) }
            else { rightPaddleY = max(1, min(bounds.height - pongPaddleHeight - 1, p.y - pongPaddleHeight / 2)) }
        case .snake:
            guard let head = snake.first else { return }
            let target = CGPoint(x: p.x / snakeCell, y: p.y / snakeCell)
            let dx = target.x - head.x
            let dy = target.y - head.y
            if abs(dx) > abs(dy) { setSnakeDirection(x: dx >= 0 ? 1 : -1, y: 0) }
            else { setSnakeDirection(x: 0, y: dy >= 0 ? 1 : -1) }
        case .breakout:
            paddleX = max(48, min(bounds.width - 38, p.x))
        case .life:
            break
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard game == .breakout else { return }
        let p = convert(event.locationInWindow, from: nil)
        paddleX = max(48, min(bounds.width - 38, p.x))
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); dirtyRect.fill()
        switch game {
        case .pong: drawPong()
        case .snake: drawSnake()
        case .breakout: drawBreakout()
        case .life: drawLife()
        }
    }

    private func drawPong() {
        NSColor.white.setFill()
        NSRect(x: 50, y: leftPaddleY, width: 4, height: pongPaddleHeight).fill()
        NSRect(x: bounds.width - 12, y: rightPaddleY, width: 4, height: pongPaddleHeight).fill()
        NSRect(x: ball.x - 2, y: ball.y - 2, width: 4, height: 4).fill()
        for y in stride(from: CGFloat(1), through: bounds.height, by: 6) {
            NSRect(x: bounds.midX, y: y, width: 1, height: 3).fill()
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .bold), .foregroundColor: NSColor.white]
        "\(leftScore)".draw(at: NSPoint(x: bounds.midX - 18, y: bounds.height - 10), withAttributes: attrs)
        "\(rightScore)".draw(at: NSPoint(x: bounds.midX + 10, y: bounds.height - 10), withAttributes: attrs)
    }

    private func drawSnake() {
        NSColor(calibratedRed: 0.2, green: 0.95, blue: 0.3, alpha: 1).setFill()
        for part in snake {
            NSRect(x: part.x * snakeCell, y: part.y * snakeCell, width: snakeCell - 1, height: snakeCell - 1).fill()
        }
        NSColor(calibratedRed: 1, green: 0.25, blue: 0.1, alpha: 1).setFill()
        NSRect(x: food.x * snakeCell, y: food.y * snakeCell, width: snakeCell - 1, height: snakeCell - 1).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .bold), .foregroundColor: NSColor.white]
        "\(snakeScore)".draw(at: NSPoint(x: 47, y: bounds.height - 8), withAttributes: attrs)
    }

    private func drawBreakout() {
        let colors = [
            NSColor(calibratedRed: 0.95, green: 0.28, blue: 0.22, alpha: 1),
            NSColor(calibratedRed: 0.95, green: 0.72, blue: 0.18, alpha: 1),
            NSColor(calibratedRed: 0.25, green: 0.62, blue: 1.0, alpha: 1)
        ]
        for brick in bricks {
            colors[max(0, min(colors.count - 1, brick.row))].setFill()
            brick.rect.fill()
        }
        NSColor.white.setFill()
        NSRect(x: paddleX - 30, y: 2, width: 60, height: 3).fill()
        NSRect(x: ball.x - 2, y: ball.y - 2, width: 4, height: 4).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .medium), .foregroundColor: NSColor.white]
        "\(breakoutScore)  ♥\(breakoutLives)".draw(at: NSPoint(x: 47, y: 5), withAttributes: attrs)
    }

    private func drawLife() {
        let gridWidth = max(1, bounds.width - lifeControlsWidth)
        let cw = gridWidth / CGFloat(lifeColumns)
        let ch = bounds.height / CGFloat(lifeRows)
        NSColor(calibratedRed: 0.15, green: 0.86, blue: 0.95, alpha: 1).setFill()
        for x in 0..<lifeColumns {
            for y in 0..<lifeRows where life[x][y] {
                NSRect(x: lifeControlsWidth + CGFloat(x) * cw, y: CGFloat(y) * ch, width: max(1, cw - 0.4), height: max(1, ch - 0.4)).fill()
            }
        }
    }
}

// MARK: - Pitfall!-style jungle runner

final class PitfallHomageView: NSView {
    private let keyMonitor = GameKeyMonitor()
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
    private var deathTime: TimeInterval = 0
    private var collectedTreasureScenes = Set<Int>()

    private let heroScreenX: CGFloat = 170

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        keyMonitor.handler = { [weak self] event, down in
            guard let self = self else { return }
            if down { self.pressed.insert(event.keyCode) } else { self.pressed.remove(event.keyCode) }
            if down && (event.keyCode == 126 || event.keyCode == 13 || event.keyCode == 49) { self.jump() }
        }
        addTouchControls()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func addTouchControls() {
        let left = NSButton(title: "◀", target: self, action: #selector(stepLeft))
        left.frame = NSRect(x: 2, y: 2, width: 28, height: 26)
        addSubview(left)

        let jumpButton = NSButton(title: "JUMP", target: self, action: #selector(jumpButtonPressed))
        jumpButton.font = .systemFont(ofSize: 7)
        jumpButton.frame = NSRect(x: 32, y: 2, width: 46, height: 26)
        addSubview(jumpButton)

        let right = NSButton(title: "▶", target: self, action: #selector(stepRight))
        right.frame = NSRect(x: 80, y: 2, width: 28, height: 26)
        addSubview(right)

        let keyboard = NSButton(title: "KEYS", target: self, action: #selector(focusKeyboard))
        keyboard.font = .monospacedSystemFont(ofSize: 7, weight: .bold)
        keyboard.frame = NSRect(x: 110, y: 2, width: 48, height: 26)
        addSubview(keyboard)
    }

    @objc private func focusKeyboard() { focusTouchBarpalooza() }
    @objc private func stepLeft() { if deathTime <= 0 { worldX -= 17; needsDisplay = true } }
    @objc private func stepRight() { if deathTime <= 0 { worldX += 17; needsDisplay = true } }
    @objc private func jumpButtonPressed() { jump() }

    private func jump() {
        if deathTime <= 0 && heroY <= 0.1 { verticalVelocity = 108 }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick)
        lastTick = now
        animationTime += dt
        timeRemaining = max(0, timeRemaining - dt)
        collisionCooldown = max(0, collisionCooldown - dt)

        if deathTime > 0 {
            deathTime -= dt
            if deathTime <= 0 { respawnAfterDeath() }
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
        let heroWorld = worldX + heroScreenX
        let segment = Int(floor(heroWorld / 105))
        let local = heroWorld - CGFloat(segment) * 105
        let pattern = ((segment % 4) + 4) % 4

        if pattern == 0 && heroY < 4 && local > 40 && local < 64 {
            score = max(0, score - 12)
            collisionCooldown = 0.12
        } else if pattern == 1 && heroY < 4 && local > 34 && local < 76 {
            beginDeath()
        } else if pattern == 2 && heroY < 4 && local > 47 && local < 69 {
            beginDeath()
        } else if pattern == 3 && local > 48 && local < 67 && !collectedTreasureScenes.contains(segment) {
            collectedTreasureScenes.insert(segment)
            treasures += 1
            score += 2000
            collisionCooldown = 0.35
        }
    }

    private func beginDeath() {
        guard deathTime <= 0 else { return }
        lives -= 1
        deathTime = 0.9
        verticalVelocity = 0
        collisionCooldown = 1.0
    }

    private func respawnAfterDeath() {
        heroY = 0
        verticalVelocity = 0
        if lives <= 0 {
            lives = 3
            score = 2000
            treasures = 0
            timeRemaining = 20 * 60
            worldX = 0
            collectedTreasureScenes.removeAll()
        } else {
            worldX -= 34
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let canopy = NSColor(calibratedRed: 0.10, green: 0.34, blue: 0.06, alpha: 1)
        let jungle = NSColor(calibratedRed: 0.32, green: 0.62, blue: 0.23, alpha: 1)
        let ground = NSColor(calibratedRed: 0.76, green: 0.68, blue: 0.24, alpha: 1)
        canopy.setFill(); dirtyRect.fill()
        jungle.setFill(); NSRect(x: 0, y: 6, width: bounds.width, height: 17).fill()
        ground.setFill(); NSRect(x: 0, y: 4, width: bounds.width, height: 3).fill()
        NSColor.black.setFill(); NSRect(x: 0, y: 0, width: bounds.width, height: 4).fill()

        let firstSegment = Int(floor(worldX / 105)) - 1
        for offset in 0..<10 {
            let segment = firstSegment + offset
            let x = CGFloat(segment) * 105 - worldX + heroScreenX
            drawPitfallScene(segment: segment, x: x)
        }

        drawPitfallHarry(x: heroScreenX, y: 7 + heroY, dying: deathTime > 0)

        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        let hud = String(format: "%05d  L%d  T%d  %02d:%02d", score, lives, treasures, minutes, seconds)
        hud.draw(at: NSPoint(x: 162, y: 22), withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 6.2, weight: .bold),
            .foregroundColor: NSColor.white
        ])
        if deathTime > 0 {
            "OUCH".draw(at: NSPoint(x: heroScreenX - 2, y: 20), withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 6, weight: .bold),
                .foregroundColor: NSColor.white
            ])
        }
    }

    private func drawPitfallScene(segment: Int, x: CGFloat) {
        let pattern = ((segment % 4) + 4) % 4
        let trunk = NSColor(calibratedRed: 0.38, green: 0.22, blue: 0.03, alpha: 1)
        trunk.setFill(); NSRect(x: x + 8, y: 7, width: 4, height: 16).fill(); NSRect(x: x + 92, y: 7, width: 4, height: 16).fill()

        if pattern == 0 {
            let roll = CGFloat(animationTime.truncatingRemainder(dividingBy: 1.0)) * 18
            let log = NSColor(calibratedRed: 0.48, green: 0.25, blue: 0.03, alpha: 1)
            log.setFill(); NSRect(x: x + 55 - roll, y: 7, width: 18, height: 4).fill()
            NSColor(calibratedRed: 0.25, green: 0.12, blue: 0.01, alpha: 1).setFill()
            NSRect(x: x + 59 - roll, y: 8, width: 2, height: 2).fill(); NSRect(x: x + 67 - roll, y: 8, width: 2, height: 2).fill()
        } else if pattern == 1 {
            NSColor(calibratedRed: 0.13, green: 0.45, blue: 0.66, alpha: 1).setFill()
            NSRect(x: x + 34, y: 4, width: 42, height: 4).fill()
            let gator = NSColor(calibratedRed: 0.03, green: 0.27, blue: 0.06, alpha: 1)
            gator.setFill()
            let jawsOpen = sin(animationTime * 5) > 0
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
            NSColor.black.setFill(); NSRect(x: x + 47, y: 3, width: 22, height: 6).fill()
            NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
            let sx = x + 52 + sin(animationTime * 2.5) * 5
            NSRect(x: sx, y: 1, width: 8, height: 2).fill(); NSRect(x: sx + 7, y: 2, width: 4, height: 1).fill(); NSRect(x: sx - 2, y: 2, width: 2, height: 1).fill()
        } else if !collectedTreasureScenes.contains(segment) {
            NSColor(calibratedRed: 0.95, green: 0.75, blue: 0.12, alpha: 1).setFill()
            NSRect(x: x + 52, y: 9, width: 10, height: 3).fill()
            NSColor(calibratedRed: 1.0, green: 0.9, blue: 0.35, alpha: 1).setFill()
            NSRect(x: x + 54, y: 12, width: 6, height: 1).fill()
        }
    }

    private func drawPitfallHarry(x: CGFloat, y: CGFloat, dying: Bool) {
        let wobble = dying ? sin(CGFloat(deathTime) * 28) * 4 : 0
        let skin = dying && Int(deathTime * 12) % 2 == 0 ? NSColor.white : NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.48, alpha: 1)
        skin.setFill(); NSRect(x: x + 2 + wobble, y: y + 8, width: 4, height: 4).fill()
        NSColor(calibratedRed: 0.12, green: 0.42, blue: 0.16, alpha: 1).setFill(); NSRect(x: x + 1 + wobble, y: y + 3, width: 6, height: 6).fill()
        NSColor(calibratedRed: 0.08, green: 0.15, blue: 0.04, alpha: 1).setFill(); NSRect(x: x + wobble, y: y, width: 3, height: 4).fill(); NSRect(x: x + 5 + wobble, y: y, width: 3, height: 4).fill()
    }
}

// MARK: - E.T. homage

final class ETHomageView: NSView {
    private let keyMonitor = GameKeyMonitor()
    private var pressed = Set<UInt16>()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var playerX: CGFloat = 170
    private var pieces = [CGPoint(x: 265, y: 13), CGPoint(x: 440, y: 12), CGPoint(x: 610, y: 15)]
    private var collected = Set<Int>()
    private var score = 8975

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        keyMonitor.handler = { [weak self] event, down in
            guard let self = self else { return }
            if down { self.pressed.insert(event.keyCode) } else { self.pressed.remove(event.keyCode) }
            if down && event.keyCode == 49 { self.collectNearby() }
        }
        addTouchControls()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func addTouchControls() {
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

        let keyboard = NSButton(title: "KEYS", target: self, action: #selector(focusKeyboard))
        keyboard.font = .monospacedSystemFont(ofSize: 7, weight: .bold)
        keyboard.frame = NSRect(x: 110, y: 2, width: 48, height: 26)
        addSubview(keyboard)
    }

    @objc private func focusKeyboard() { focusTouchBarpalooza() }
    @objc private func stepLeft() { playerX = max(162, playerX - 16); needsDisplay = true }
    @objc private func stepRight() { playerX = min(bounds.width - 22, playerX + 16); needsDisplay = true }
    @objc private func takePressed() { collectNearby() }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick)
        lastTick = now
        if pressed.contains(123) || pressed.contains(0) { playerX -= 82 * CGFloat(dt) }
        if pressed.contains(124) || pressed.contains(2) { playerX += 82 * CGFloat(dt) }
        playerX = max(162, min(bounds.width - 22, playerX))
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
        let field = NSColor(calibratedRed: 0.28, green: 0.45, blue: 0.17, alpha: 1)
        field.setFill(); dirtyRect.fill()
        NSColor(calibratedRed: 0.60, green: 0.02, blue: 0.46, alpha: 1).setFill(); NSRect(x: 0, y: bounds.height - 3, width: bounds.width, height: 3).fill()
        NSColor(calibratedRed: 0.42, green: 0.63, blue: 0.88, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: bounds.width, height: 4).fill()

        let pit = NSColor(calibratedRed: 0.01, green: 0.22, blue: 0.06, alpha: 1)
        pit.setFill()
        for r in [CGRect(x: 190, y: 9, width: 58, height: 5), CGRect(x: 350, y: 18, width: 70, height: 5), CGRect(x: 515, y: 8, width: 68, height: 5), CGRect(x: 650, y: 17, width: 45, height: 5)] { r.fill() }

        for i in pieces.indices where !collected.contains(i) {
            NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.20, alpha: 1).setFill()
            NSRect(x: pieces[i].x, y: pieces[i].y, width: 5, height: 3).fill()
        }

        drawET(at: playerX)

        NSColor(calibratedRed: 0.92, green: 0.55, blue: 0.25, alpha: 1).setFill(); NSRect(x: 300, y: 10, width: 6, height: 9).fill()
        NSColor(calibratedRed: 0.15, green: 0.24, blue: 0.58, alpha: 1).setFill(); NSRect(x: 300, y: 8, width: 3, height: 4).fill(); NSRect(x: 305, y: 8, width: 3, height: 4).fill()
        NSColor.black.setFill(); NSRect(x: 301, y: 19, width: 5, height: 2).fill()

        let hud = collected.count == pieces.count ? "CALL HOME" : String(format: "%04d  PHONE %d/3", score, collected.count)
        hud.draw(at: NSPoint(x: 162, y: 1), withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .bold), .foregroundColor: NSColor(calibratedRed: 0.04, green: 0.24, blue: 0.05, alpha: 1)])
    }

    private func drawET(at x: CGFloat) {
        // Film E.T. is leathery brown/tan, with a very broad, flattened rounded
        // head, huge dark eyes and a narrow extendable neck. The 2600 game made
        // him pale green, but recognizability wins here while the world remains
        // deliberately Atari-like.
        let skin = NSColor(calibratedRed: 0.58, green: 0.36, blue: 0.22, alpha: 1)
        let light = NSColor(calibratedRed: 0.76, green: 0.52, blue: 0.33, alpha: 1)
        let eye = NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.10, alpha: 1)

        skin.setFill()
        let head = NSBezierPath(ovalIn: NSRect(x: x, y: 16, width: 18, height: 7))
        head.fill()
        NSRect(x: x + 6, y: 11, width: 6, height: 7).fill()
        NSRect(x: x + 4, y: 6, width: 10, height: 7).fill()
        NSRect(x: x + 2, y: 8, width: 4, height: 2).fill()
        NSRect(x: x + 13, y: 8, width: 4, height: 2).fill()
        NSRect(x: x + 5, y: 3, width: 3, height: 4).fill()
        NSRect(x: x + 11, y: 3, width: 3, height: 4).fill()
        NSRect(x: x + 3, y: 2, width: 6, height: 2).fill()
        NSRect(x: x + 10, y: 2, width: 6, height: 2).fill()

        light.setFill(); NSRect(x: x + 5, y: 18, width: 8, height: 2).fill()
        eye.setFill(); NSRect(x: x + 4, y: 19, width: 3, height: 2).fill(); NSRect(x: x + 11, y: 19, width: 3, height: 2).fill()
    }
}

// MARK: - Very Small Cave Adventure

final class AdventureTerminalView: NSView {
    private struct Room {
        let description: String
        let exits: [String: String]
    }

    private let rooms: [String: Room] = [
        "mouth": Room(
            description: "You stand at the mouth of a limestone cave. Cool air drifts from a narrow passage leading north, and daylight fades quickly behind you.",
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
            description: "A narrow natural bridge crosses a black fissure. Pebbles vanish soundlessly into the depth below. The chamber is south; a faint glimmer shows east.",
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
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        let typeButton = NSButton(title: "> TYPE", target: self, action: #selector(beginEditing))
        typeButton.font = .monospacedSystemFont(ofSize: 7, weight: .bold)
        typeButton.frame = NSRect(x: 2, y: 2, width: 58, height: 26)
        addSubview(typeButton)

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.editing else { return event }
            self.consumeKey(event)
            return nil
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
    }

    @objc private func beginEditing() {
        editing = true
        focusTouchBarpalooza()
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) { consumeKey(event) }

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
        guard let chars = event.charactersIgnoringModifiers else { return }
        for scalar in chars.unicodeScalars where scalar.value >= 32 && scalar.value < 127 {
            if command.count < 70 { command.append(Character(String(scalar))) }
        }
        needsDisplay = true
    }

    private func submitCommand() {
        let raw = command.trimmingCharacters(in: .whitespacesAndNewlines)
        command = ""
        guard !raw.isEmpty else { needsDisplay = true; return }
        appendWrapped("> " + raw.uppercased())
        process(raw.uppercased())
        needsDisplay = true
    }

    private func appendWrapped(_ text: String) {
        let words = text.split(separator: " ").map(String.init)
        var line = ""
        for word in words {
            let candidate = line.isEmpty ? word : line + " " + word
            if candidate.count > 100 {
                if !line.isEmpty { lines.append(line) }
                line = word
            } else {
                line = candidate
            }
        }
        if !line.isEmpty { lines.append(line) }
        while lines.count > 10 { lines.removeFirst() }
    }

    private func process(_ input: String) {
        let aliases = ["NORTH": "N", "SOUTH": "S", "EAST": "E", "WEST": "W"]
        let normalized = aliases[input] ?? input
        if let destination = rooms[room]?.exits[normalized] {
            room = destination
            appendWrapped(rooms[room]?.description ?? "Darkness presses close around you.")
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
                appendWrapped("You lift the small treasure from its stone pocket. The cave seems suddenly worth the damp socks.")
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
            appendWrapped(inventory.isEmpty ? "You are carrying nothing." : "You are carrying: " + inventory.sorted().joined(separator: ", ") + ".")
        case "HELP":
            appendWrapped("Commands include N, S, E, W, LOOK, TAKE LAMP, TAKE TREASURE, INV, and HELP.")
        default:
            appendWrapped("I don't understand that command.")
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); dirtyRect.fill()
        let green = NSColor(calibratedRed: 0.20, green: 1.0, blue: 0.38, alpha: 1)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 4.9, weight: .regular),
            .foregroundColor: green
        ]
        let lineHeight: CGFloat = 5.7
        var y = bounds.height - lineHeight
        for line in lines.suffix(4) {
            line.draw(at: NSPoint(x: 64, y: y), withAttributes: attrs)
            y -= lineHeight
        }
        let prompt = "> " + command + (editing ? "_" : "▮")
        prompt.draw(at: NSPoint(x: 64, y: 1), withAttributes: attrs)
    }
}
