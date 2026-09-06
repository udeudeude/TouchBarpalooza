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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        pointHandler?(convert(event.locationInWindow, from: nil), false)
    }

    override func mouseDragged(with event: NSEvent) {
        pointHandler?(convert(event.locationInWindow, from: nil), true)
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
    private let lifeColumns = 104
    private let lifeRows = 7
    private var life: [[Bool]] = []
    private var lifeAccumulator: TimeInterval = 0
    private var lifeRunning = false
    private var lifePaintValue: Bool?
    private let lifeControlsWidth: CGFloat = 154
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
        let button = NSButton(title: "⌨", target: self, action: #selector(focusKeyboard))
        button.font = .systemFont(ofSize: 10)
        button.frame = NSRect(x: 2, y: 2, width: 29, height: 26)
        button.autoresizingMask = []
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
            if full { leftScore = 0; rightScore = 0 }
            resetPongBall(towardRight: Bool.random())
        case .snake:
            snake = [CGPoint(x: 15, y: 3), CGPoint(x: 14, y: 3), CGPoint(x: 13, y: 3)]
            snakeDirection = CGPoint(x: 1, y: 0)
            pendingSnakeDirection = snakeDirection
            snakeAccumulator = 0
            if full { snakeScore = 0 }
            placeFood()
        case .breakout:
            if full { breakoutLives = 3; breakoutScore = 0; buildBricks() }
            resetBreakoutBall()
        case .life:
            life = Array(repeating: Array(repeating: false, count: lifeRows), count: lifeColumns)
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

    private func resetPongBall(towardRight: Bool) {
        ball = CGPoint(x: max(80, bounds.width * 0.5), y: max(8, bounds.height * 0.5))
        velocity = CGVector(dx: towardRight ? 112 : -112, dy: Bool.random() ? 62 : -62)
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

        let leftX: CGFloat = 38
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

        if ball.x < -4 { rightScore += 1; resetPongBall(towardRight: false) }
        else if ball.x > bounds.width + 4 { leftScore += 1; resetPongBall(towardRight: true) }
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
        if next == food { snakeScore += 1; placeFood() }
        else { snake.removeLast() }
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
        paddleX = max(45, bounds.width * 0.5)
        ball = CGPoint(x: paddleX, y: 8)
        velocity = CGVector(dx: Bool.random() ? 76 : -76, dy: 105)
    }

    private func updateBreakout(_ dt: TimeInterval) {
        let paddleSpeed: CGFloat = 190
        if pressedKeys.contains(123) || pressedKeys.contains(0) { paddleX -= paddleSpeed * CGFloat(dt) }
        if pressedKeys.contains(124) || pressedKeys.contains(2) { paddleX += paddleSpeed * CGFloat(dt) }
        paddleX = max(38, min(bounds.width - 38, paddleX))

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
            if bricks.isEmpty { buildBricks(); resetBreakoutBall() }
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
            ("STEP", #selector(stepLifeButton), NSRect(x: 42, y: 3, width: 34, height: 24)),
            ("CLR", #selector(clearLife), NSRect(x: 78, y: 3, width: 36, height: 24)),
            ("RND", #selector(randomLife), NSRect(x: 116, y: 3, width: 36, height: 24))
        ]
        for (title, action, frame) in specs {
            let button = NSButton(title: title, target: self, action: action)
            button.font = .monospacedSystemFont(ofSize: 7, weight: .bold)
            button.frame = frame
            addSubview(button)
        }

        let grid = LifeGridButton(frame: NSRect(x: lifeControlsWidth, y: 0, width: max(1, bounds.width - lifeControlsWidth), height: bounds.height))
        grid.title = ""
        grid.isBordered = false
        grid.autoresizingMask = [.width, .height]
        grid.pointHandler = { [weak self] point, dragging in self?.paintLife(point, dragging: dragging) }
        addSubview(grid)
        lifeGridButton = grid
    }

    @objc private func toggleLife(_ sender: NSButton) {
        lifeRunning.toggle()
        sender.title = lifeRunning ? "PAUSE" : "RUN"
    }

    @objc private func stepLifeButton() { stepLife() }

    @objc private func clearLife() {
        life = Array(repeating: Array(repeating: false, count: lifeRows), count: lifeColumns)
        lifeRunning = false
        needsDisplay = true
    }

    @objc private func randomLife() {
        for x in 0..<lifeColumns {
            for y in 0..<lifeRows { life[x][y] = Int.random(in: 0..<5) == 0 }
        }
        needsDisplay = true
    }

    private func paintLife(_ point: CGPoint, dragging: Bool) {
        let width = max(1, (lifeGridButton?.bounds.width ?? 1))
        let height = max(1, (lifeGridButton?.bounds.height ?? 1))
        let x = max(0, min(lifeColumns - 1, Int((point.x / width) * CGFloat(lifeColumns))))
        let y = max(0, min(lifeRows - 1, Int((point.y / height) * CGFloat(lifeRows))))
        if !dragging || lifePaintValue == nil { lifePaintValue = !life[x][y] }
        life[x][y] = lifePaintValue ?? true
        needsDisplay = true
        if !dragging { lifePaintValue = nil }
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
        stepLife()
    }

    private func stepLife() {
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

    // MARK: Touch interaction

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
            paddleX = max(38, min(bounds.width - 38, p.x))
        case .life:
            break
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard game == .breakout else { return }
        let p = convert(event.locationInWindow, from: nil)
        paddleX = max(38, min(bounds.width - 38, p.x))
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
        NSRect(x: 38, y: leftPaddleY, width: 4, height: pongPaddleHeight).fill()
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
        for part in snake { NSRect(x: part.x * snakeCell, y: part.y * snakeCell, width: snakeCell - 1, height: snakeCell - 1).fill() }
        NSColor(calibratedRed: 1, green: 0.25, blue: 0.1, alpha: 1).setFill()
        NSRect(x: food.x * snakeCell, y: food.y * snakeCell, width: snakeCell - 1, height: snakeCell - 1).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .bold), .foregroundColor: NSColor.white]
        "\(snakeScore)".draw(at: NSPoint(x: 34, y: bounds.height - 8), withAttributes: attrs)
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
        "\(breakoutScore)  ♥\(breakoutLives)".draw(at: NSPoint(x: 34, y: 5), withAttributes: attrs)
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
    private var timeRemaining: TimeInterval = 20 * 60
    private var collisionCooldown: TimeInterval = 0

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        keyMonitor.handler = { [weak self] event, down in
            if down { self?.pressed.insert(event.keyCode) } else { self?.pressed.remove(event.keyCode) }
        }
        addFocusButton()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func addFocusButton() {
        let b = NSButton(title: "⌨", target: self, action: #selector(focusKeyboard))
        b.font = .systemFont(ofSize: 10); b.frame = NSRect(x: 2, y: 2, width: 29, height: 26); addSubview(b)
    }
    @objc private func focusKeyboard() { focusTouchBarpalooza() }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick); lastTick = now
        timeRemaining = max(0, timeRemaining - dt)
        collisionCooldown = max(0, collisionCooldown - dt)
        let speed: CGFloat = 78
        if pressed.contains(123) || pressed.contains(0) { worldX -= speed * CGFloat(dt) }
        if pressed.contains(124) || pressed.contains(2) { worldX += speed * CGFloat(dt); score += Int(8 * dt) }
        if (pressed.contains(126) || pressed.contains(13) || pressed.contains(49)) && heroY <= 0.1 { verticalVelocity = 105 }
        verticalVelocity -= 245 * CGFloat(dt)
        heroY = max(0, heroY + verticalVelocity * CGFloat(dt))
        if heroY == 0 && verticalVelocity < 0 { verticalVelocity = 0 }
        detectHazard()
        needsDisplay = true
    }

    private func detectHazard() {
        guard collisionCooldown <= 0, heroY < 4 else { return }
        let heroWorld = worldX + 90
        let segment = Int(floor(heroWorld / 105))
        let local = heroWorld - CGFloat(segment) * 105
        let pattern = abs(segment) % 4
        if pattern == 0 && local > 43 && local < 60 {
            score = max(0, score - 75); collisionCooldown = 0.6
        } else if pattern == 1 && local > 34 && local < 74 {
            score = max(0, score - 250); collisionCooldown = 0.8
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
            let x = CGFloat(segment) * 105 - worldX + 90
            drawPitfallScene(segment: segment, x: x)
        }

        drawPitfallHarry(x: 90, y: 7 + heroY)

        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        let hud = String(format: "%05d  %02d:%02d", score, minutes, seconds)
        hud.draw(at: NSPoint(x: 35, y: 22), withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 6.5, weight: .bold), .foregroundColor: NSColor.white])
    }

    private func drawPitfallScene(segment: Int, x: CGFloat) {
        let pattern = abs(segment) % 4
        let trunk = NSColor(calibratedRed: 0.38, green: 0.22, blue: 0.03, alpha: 1)
        trunk.setFill(); NSRect(x: x + 8, y: 7, width: 4, height: 16).fill()
        NSRect(x: x + 92, y: 7, width: 4, height: 16).fill()

        if pattern == 0 {
            let log = NSColor(calibratedRed: 0.48, green: 0.25, blue: 0.03, alpha: 1)
            log.setFill(); NSRect(x: x + 43, y: 7, width: 18, height: 4).fill()
            NSColor(calibratedRed: 0.25, green: 0.12, blue: 0.01, alpha: 1).setFill()
            NSRect(x: x + 47, y: 8, width: 2, height: 2).fill(); NSRect(x: x + 55, y: 8, width: 2, height: 2).fill()
        } else if pattern == 1 {
            NSColor(calibratedRed: 0.13, green: 0.45, blue: 0.66, alpha: 1).setFill()
            NSRect(x: x + 34, y: 4, width: 42, height: 4).fill()
            let gator = NSColor(calibratedRed: 0.03, green: 0.27, blue: 0.06, alpha: 1)
            gator.setFill()
            for gx in stride(from: x + 38, through: x + 68, by: 14) {
                NSRect(x: gx, y: 6, width: 10, height: 2).fill(); NSRect(x: gx + 2, y: 8, width: 5, height: 1).fill()
            }
            // The original vine descends diagonally from the canopy.
            let rope = NSBezierPath(); rope.move(to: NSPoint(x: x + 55, y: 23)); rope.line(to: NSPoint(x: x + 47, y: 11));
            NSColor(calibratedRed: 0.42, green: 0.27, blue: 0.05, alpha: 1).setStroke(); rope.lineWidth = 1; rope.stroke()
        } else if pattern == 2 {
            NSColor.black.setFill(); NSRect(x: x + 47, y: 3, width: 22, height: 6).fill()
            // White scorpion in the underground passage, echoing the 2600 sprite.
            NSColor.white.setFill();
            NSRect(x: x + 51, y: 1, width: 8, height: 2).fill(); NSRect(x: x + 58, y: 2, width: 4, height: 1).fill(); NSRect(x: x + 49, y: 2, width: 2, height: 1).fill()
        } else {
            // Small treasure bar.
            NSColor(calibratedRed: 0.95, green: 0.75, blue: 0.12, alpha: 1).setFill()
            NSRect(x: x + 52, y: 9, width: 10, height: 3).fill()
        }
    }

    private func drawPitfallHarry(x: CGFloat, y: CGFloat) {
        NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.48, alpha: 1).setFill(); NSRect(x: x + 2, y: y + 8, width: 4, height: 4).fill()
        NSColor(calibratedRed: 0.12, green: 0.42, blue: 0.16, alpha: 1).setFill(); NSRect(x: x + 1, y: y + 3, width: 6, height: 6).fill()
        NSColor(calibratedRed: 0.08, green: 0.15, blue: 0.04, alpha: 1).setFill(); NSRect(x: x, y: y, width: 3, height: 4).fill(); NSRect(x: x + 5, y: y, width: 3, height: 4).fill()
    }
}

// MARK: - E.T. Atari-style homage

final class ETHomageView: NSView {
    private let keyMonitor = GameKeyMonitor()
    private var pressed = Set<UInt16>()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var playerX: CGFloat = 110
    private var pieces = [CGPoint(x: 235, y: 14), CGPoint(x: 430, y: 12), CGPoint(x: 610, y: 16)]
    private var collected = Set<Int>()
    private var score = 8975

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        keyMonitor.handler = { [weak self] event, down in
            if down { self?.pressed.insert(event.keyCode) } else { self?.pressed.remove(event.keyCode) }
            if down && event.keyCode == 49 { self?.collectNearby() }
        }
        let b = NSButton(title: "⌨", target: self, action: #selector(focusKeyboard))
        b.font = .systemFont(ofSize: 10); b.frame = NSRect(x: 2, y: 2, width: 29, height: 26); addSubview(b)
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = t; RunLoop.main.add(t, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }
    @objc private func focusKeyboard() { focusTouchBarpalooza() }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick); lastTick = now
        if pressed.contains(123) || pressed.contains(0) { playerX -= 82 * CGFloat(dt) }
        if pressed.contains(124) || pressed.contains(2) { playerX += 82 * CGFloat(dt) }
        playerX = max(38, min(bounds.width - 20, playerX))
        needsDisplay = true
    }

    private func collectNearby() {
        for index in pieces.indices where !collected.contains(index) {
            if abs(pieces[index].x - playerX) < 24 { collected.insert(index); score += 25 }
        }
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) { collectNearby() }

    override func draw(_ dirtyRect: NSRect) {
        let field = NSColor(calibratedRed: 0.27, green: 0.43, blue: 0.17, alpha: 1)
        field.setFill(); dirtyRect.fill()
        NSColor(calibratedRed: 0.55, green: 0.02, blue: 0.43, alpha: 1).setFill(); NSRect(x: 0, y: bounds.height - 3, width: bounds.width, height: 3).fill()
        NSColor(calibratedRed: 0.42, green: 0.63, blue: 0.88, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: bounds.width, height: 4).fill()

        let pit = NSColor(calibratedRed: 0.01, green: 0.22, blue: 0.06, alpha: 1)
        pit.setFill()
        let pits = [CGRect(x: 75, y: 9, width: 60, height: 5), CGRect(x: 315, y: 18, width: 70, height: 5), CGRect(x: 500, y: 8, width: 68, height: 5), CGRect(x: 650, y: 17, width: 45, height: 5)]
        for r in pits { r.fill() }

        for i in pieces.indices where !collected.contains(i) {
            NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.20, alpha: 1).setFill()
            NSRect(x: pieces[i].x, y: pieces[i].y, width: 5, height: 3).fill()
        }

        // E.T.'s squat pale-green 2600 silhouette.
        NSColor(calibratedRed: 0.72, green: 0.91, blue: 0.35, alpha: 1).setFill()
        NSRect(x: playerX + 1, y: 10, width: 8, height: 9).fill(); NSRect(x: playerX + 3, y: 8, width: 4, height: 3).fill(); NSRect(x: playerX, y: 17, width: 10, height: 4).fill()
        field.setFill(); NSRect(x: playerX + 6, y: 17, width: 4, height: 2).fill()

        // Human/agent sprite in the warm Atari palette.
        NSColor(calibratedRed: 0.92, green: 0.55, blue: 0.25, alpha: 1).setFill(); NSRect(x: 185, y: 10, width: 6, height: 9).fill()
        NSColor(calibratedRed: 0.15, green: 0.24, blue: 0.58, alpha: 1).setFill(); NSRect(x: 185, y: 8, width: 3, height: 4).fill(); NSRect(x: 190, y: 8, width: 3, height: 4).fill()

        let hud = collected.count == pieces.count ? "CALL HOME" : String(format: "%04d  PHONE %d/3", score, collected.count)
        hud.draw(at: NSPoint(x: 36, y: 1), withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .bold), .foregroundColor: NSColor(calibratedRed: 0.04, green: 0.24, blue: 0.05, alpha: 1)])
    }
}

// MARK: - Scramble / Vectrex-style cave flyer

final class CaveFlyerView: NSView {
    private let keyMonitor = GameKeyMonitor()
    private var pressed = Set<UInt16>()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var distance: CGFloat = 0
    private var shipY: CGFloat = 15
    private var score = 0

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        keyMonitor.handler = { [weak self] event, down in
            if down { self?.pressed.insert(event.keyCode) } else { self?.pressed.remove(event.keyCode) }
        }
        let b = NSButton(title: "⌨", target: self, action: #selector(focusKeyboard))
        b.font = .systemFont(ofSize: 10); b.frame = NSRect(x: 2, y: 2, width: 29, height: 26); addSubview(b)
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = t; RunLoop.main.add(t, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }
    @objc private func focusKeyboard() { focusTouchBarpalooza() }

    private func baseCeiling(_ x: CGFloat) -> CGFloat { 26 + sin(x * 0.018) * 1.4 }
    private func baseFloor(_ x: CGFloat) -> CGFloat { 4 + sin(x * 0.021 + 1.7) * 1.1 }

    private func spikeAmount(at worldX: CGFloat, top: Bool) -> CGFloat {
        let segmentWidth: CGFloat = 92
        let segment = Int(floor(worldX / segmentWidth))
        // Two long clear segments out of every seven give the eye and pilot a rest.
        let phase = ((segment % 7) + 7) % 7
        if phase == 0 || phase == 1 { return 0 }
        let local = worldX - CGFloat(segment) * segmentWidth
        let center: CGFloat = top ? 28 : 63
        let distance = abs(local - center)
        let half: CGFloat = 13
        guard distance < half else { return 0 }
        return (1 - distance / half) * (top ? 8.5 : 7.5)
    }

    private func ceiling(at x: CGFloat) -> CGFloat { baseCeiling(x) - spikeAmount(at: x, top: true) }
    private func floorY(at x: CGFloat) -> CGFloat { baseFloor(x) + spikeAmount(at: x, top: false) }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick); lastTick = now
        distance += 72 * CGFloat(dt)
        if pressed.contains(126) || pressed.contains(13) { shipY += 68 * CGFloat(dt) }
        if pressed.contains(125) || pressed.contains(1) { shipY -= 68 * CGFloat(dt) }
        shipY = max(2, min(bounds.height - 2, shipY))

        let worldX = distance + 94
        if shipY + 3 > ceiling(at: worldX) || shipY - 3 < floorY(at: worldX) {
            distance = 0; shipY = bounds.midY; score = 0
        } else { score = Int(distance / 8) }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); dirtyRect.fill()
        let green = NSColor(calibratedRed: 0.25, green: 1.0, blue: 0.45, alpha: 1)
        green.setStroke()
        let top = NSBezierPath(); let bottom = NSBezierPath()
        for x in stride(from: CGFloat(0), through: bounds.width, by: 3) {
            let wx = distance + x
            let cy = ceiling(at: wx); let fy = floorY(at: wx)
            if x == 0 { top.move(to: NSPoint(x: x, y: cy)); bottom.move(to: NSPoint(x: x, y: fy)) }
            else { top.line(to: NSPoint(x: x, y: cy)); bottom.line(to: NSPoint(x: x, y: fy)) }
        }
        top.lineWidth = 1; bottom.lineWidth = 1; top.stroke(); bottom.stroke()

        let sx: CGFloat = 94
        let ship = NSBezierPath()
        ship.move(to: NSPoint(x: sx + 7, y: shipY)); ship.line(to: NSPoint(x: sx - 5, y: shipY + 4)); ship.line(to: NSPoint(x: sx - 2, y: shipY)); ship.line(to: NSPoint(x: sx - 5, y: shipY - 4)); ship.close(); ship.lineWidth = 1; ship.stroke()
        let flame = NSBezierPath(); flame.move(to: NSPoint(x: sx - 3, y: shipY)); flame.line(to: NSPoint(x: sx - 9, y: shipY)); flame.stroke()

        "SCRAMBLE  \(score)".draw(at: NSPoint(x: 35, y: bounds.height - 8), withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .medium), .foregroundColor: green])
    }
}

// MARK: - Colossal-Cave-style terminal adventure

final class AdventureTerminalView: NSView {
    private struct Room {
        let description: String
        let exits: [String: String]
    }

    private let rooms: [String: Room] = [
        "mouth": Room(description: "CAVE MOUTH. DARK PASSAGE NORTH.", exits: ["N": "hall"]),
        "hall": Room(description: "LOW HALL. WATER DRIPS. E OR S.", exits: ["S": "mouth", "E": "chamber"]),
        "chamber": Room(description: "STONE CHAMBER. BRASS LAMP HERE.", exits: ["W": "hall", "N": "bridge"]),
        "bridge": Room(description: "NARROW BRIDGE OVER BLACK DEPTHS.", exits: ["S": "chamber", "E": "vault"]),
        "vault": Room(description: "QUIET VAULT. A SMALL TREASURE GLEAMS.", exits: ["W": "bridge"])
    ]

    private var room = "mouth"
    private var inventory = Set<String>()
    private var lines = ["WELCOME TO A VERY SMALL ADVENTURE.", "TAP > TYPE, THEN ENTER A COMMAND."]
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
        typeButton.frame = NSRect(x: 2, y: 2, width: 55, height: 26)
        addSubview(typeButton)

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.editing else { return event }
            self.consumeKey(event)
            return nil
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { if let monitor = localMonitor { NSEvent.removeMonitor(monitor) } }

    @objc private func beginEditing() {
        editing = true
        focusTouchBarpalooza()
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) { consumeKey(event) }

    private func consumeKey(_ event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 { submitCommand(); return }
        if event.keyCode == 51 || event.keyCode == 117 {
            if !command.isEmpty { command.removeLast() }
            needsDisplay = true; return
        }
        guard let chars = event.charactersIgnoringModifiers else { return }
        for scalar in chars.unicodeScalars where scalar.value >= 32 && scalar.value < 127 {
            if command.count < 42 { command.append(Character(String(scalar))) }
        }
        needsDisplay = true
    }

    private func submitCommand() {
        let raw = command.trimmingCharacters(in: .whitespacesAndNewlines)
        command = ""
        guard !raw.isEmpty else { needsDisplay = true; return }
        appendLine("> " + raw.uppercased())
        process(raw.uppercased())
        needsDisplay = true
    }

    private func appendLine(_ text: String) {
        lines.append(text)
        while lines.count > 4 { lines.removeFirst() }
    }

    private func process(_ input: String) {
        let aliases = ["NORTH": "N", "SOUTH": "S", "EAST": "E", "WEST": "W"]
        let normalized = aliases[input] ?? input
        if let destination = rooms[room]?.exits[normalized] {
            room = destination; appendLine(rooms[room]?.description ?? "DARKNESS."); return
        }
        switch normalized {
        case "LOOK", "L": appendLine(rooms[room]?.description ?? "DARKNESS.")
        case "TAKE LAMP", "GET LAMP":
            if room == "chamber" && !inventory.contains("LAMP") { inventory.insert("LAMP"); appendLine("TAKEN: BRASS LAMP.") }
            else { appendLine("YOU SEE NO LAMP TO TAKE.") }
        case "TAKE TREASURE", "GET TREASURE":
            if room == "vault" && !inventory.contains("TREASURE") { inventory.insert("TREASURE"); appendLine("TREASURE TAKEN. NICE WORK.") }
            else { appendLine("NO TREASURE HERE.") }
        case "I", "INV", "INVENTORY": appendLine(inventory.isEmpty ? "YOU ARE EMPTY-HANDED." : "YOU HAVE: " + inventory.sorted().joined(separator: ", "))
        case "HELP": appendLine("N S E W, LOOK, TAKE LAMP, INV.")
        default: appendLine("I DON'T UNDERSTAND THAT.")
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); dirtyRect.fill()
        let green = NSColor(calibratedRed: 0.20, green: 1.0, blue: 0.38, alpha: 1)
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 5.5, weight: .regular), .foregroundColor: green]
        let lineHeight: CGFloat = 6.4
        var y = bounds.height - lineHeight
        for line in lines.suffix(3) {
            line.draw(at: NSPoint(x: 62, y: y), withAttributes: attrs)
            y -= lineHeight
        }
        let prompt = "> " + command + (editing ? "_" : "▮")
        prompt.draw(at: NSPoint(x: 62, y: 2), withAttributes: attrs)
    }
}
