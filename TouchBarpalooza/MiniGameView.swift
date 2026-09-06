import AppKit

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

final class MiniGameView: NSView {
    enum Game {
        case pong, snake, breakout, life
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
    private var bricks: [CGRect] = []
    private var breakoutLives = 3
    private var breakoutScore = 0

    // Life
    private var lifeColumns = 104
    private var lifeRows = 7
    private var life: [[Bool]] = []
    private var lifeAccumulator: TimeInterval = 0
    private var lifeRunning = false
    private var lifePaintValue: Bool?
    private let lifeControlsWidth: CGFloat = 154

    init(frame frameRect: NSRect, game: Game) {
        self.game = game
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        self.game = .pong
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        keyMonitor.handler = { [weak self] event, down in
            self?.handleKey(event, down: down)
        }
        resetGame(full: true)
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    deinit { timer?.invalidate() }

    private func handleKey(_ event: NSEvent, down: Bool) {
        if down { pressedKeys.insert(event.keyCode) } else { pressedKeys.remove(event.keyCode) }

        guard down, game == .snake else { return }
        switch event.keyCode {
        case 123: setSnakeDirection(x: -1, y: 0) // left
        case 124: setSnakeDirection(x: 1, y: 0)  // right
        case 125: setSnakeDirection(x: 0, y: -1) // down
        case 126: setSnakeDirection(x: 0, y: 1)  // up
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
        leftPaddleY = max(1, bounds.midY - 7)
        rightPaddleY = leftPaddleY
    }

    private func updatePong(_ dt: TimeInterval) {
        let paddleSpeed: CGFloat = 145
        if pressedKeys.contains(13) { leftPaddleY += paddleSpeed * CGFloat(dt) }  // W
        if pressedKeys.contains(1) { leftPaddleY -= paddleSpeed * CGFloat(dt) }   // S
        if pressedKeys.contains(126) { rightPaddleY += paddleSpeed * CGFloat(dt) }
        if pressedKeys.contains(125) { rightPaddleY -= paddleSpeed * CGFloat(dt) }

        let paddleHeight: CGFloat = 14
        leftPaddleY = max(1, min(bounds.height - paddleHeight - 1, leftPaddleY))
        rightPaddleY = max(1, min(bounds.height - paddleHeight - 1, rightPaddleY))

        ball.x += velocity.dx * CGFloat(dt)
        ball.y += velocity.dy * CGFloat(dt)

        if ball.y <= 2 {
            ball.y = 2
            velocity.dy = abs(velocity.dy)
        } else if ball.y >= bounds.height - 2 {
            ball.y = bounds.height - 2
            velocity.dy = -abs(velocity.dy)
        }

        if velocity.dx < 0,
           ball.x <= 16,
           ball.x >= 8,
           ball.y >= leftPaddleY - 2,
           ball.y <= leftPaddleY + paddleHeight + 2 {
            ball.x = 16
            velocity.dx = abs(velocity.dx) * 1.02
            let offset = (ball.y - (leftPaddleY + paddleHeight / 2)) / (paddleHeight / 2)
            velocity.dy += offset * 28
        }

        if velocity.dx > 0,
           ball.x >= bounds.width - 16,
           ball.x <= bounds.width - 8,
           ball.y >= rightPaddleY - 2,
           ball.y <= rightPaddleY + paddleHeight + 2 {
            ball.x = bounds.width - 16
            velocity.dx = -abs(velocity.dx) * 1.02
            let offset = (ball.y - (rightPaddleY + paddleHeight / 2)) / (paddleHeight / 2)
            velocity.dy += offset * 28
        }

        if ball.x < -4 {
            rightScore += 1
            resetPongBall(towardRight: false)
        } else if ball.x > bounds.width + 4 {
            leftScore += 1
            resetPongBall(towardRight: true)
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
            food = CGPoint(x: CGFloat(Int.random(in: 1..<max(2, cols - 1))), y: CGFloat(Int.random(in: 0..<rows)))
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

        // The Touch Bar is so shallow that vertical wrapping is important.
        // Left and right remain real walls, while top/bottom connect.
        if next.y < 0 { next.y = CGFloat(rows - 1) }
        else if next.y >= CGFloat(rows) { next.y = 0 }

        if next.x < 0 || next.x >= CGFloat(cols) || snake.contains(next) {
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
                bricks.append(CGRect(x: x, y: y, width: brickWidth, height: 3.5))
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
        if pressedKeys.contains(123) || pressedKeys.contains(0) { paddleX -= paddleSpeed * CGFloat(dt) } // left / A
        if pressedKeys.contains(124) || pressedKeys.contains(2) { paddleX += paddleSpeed * CGFloat(dt) } // right / D
        paddleX = max(38, min(bounds.width - 38, paddleX))

        ball.x += velocity.dx * CGFloat(dt)
        ball.y += velocity.dy * CGFloat(dt)

        if ball.x <= 2 {
            ball.x = 2
            velocity.dx = abs(velocity.dx)
        } else if ball.x >= bounds.width - 2 {
            ball.x = bounds.width - 2
            velocity.dx = -abs(velocity.dx)
        }
        if ball.y >= bounds.height - 1 {
            ball.y = bounds.height - 1
            velocity.dy = -abs(velocity.dy)
        }

        let paddleRect = CGRect(x: paddleX - 34, y: 2, width: 68, height: 3)
        let ballRect = CGRect(x: ball.x - 2, y: ball.y - 2, width: 4, height: 4)
        if velocity.dy < 0 && paddleRect.intersects(ballRect) {
            ball.y = paddleRect.maxY + 2
            let hit = max(-1, min(1, (ball.x - paddleX) / 34))
            velocity.dx = hit * 125
            velocity.dy = abs(velocity.dy) * 1.015
        }

        if let index = bricks.firstIndex(where: { $0.intersects(ballRect) }) {
            let brick = bricks[index]
            bricks.remove(at: index)
            breakoutScore += 10
            let horizontalPenetration = min(abs(ballRect.maxX - brick.minX), abs(brick.maxX - ballRect.minX))
            let verticalPenetration = min(abs(ballRect.maxY - brick.minY), abs(brick.maxY - ballRect.minY))
            if horizontalPenetration < verticalPenetration { velocity.dx *= -1 } else { velocity.dy *= -1 }
            if bricks.isEmpty {
                buildBricks()
                resetBreakoutBall()
            }
        }

        if ball.y < -4 {
            breakoutLives -= 1
            if breakoutLives <= 0 { resetGame(full: true) } else { resetBreakoutBall() }
        }
    }

    // MARK: Life

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
    }

    // MARK: Interaction

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        handleTouch(p, dragging: false)
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        handleTouch(p, dragging: true)
    }

    override func mouseUp(with event: NSEvent) {
        lifePaintValue = nil
    }

    private func handleTouch(_ p: CGPoint, dragging: Bool) {
        switch game {
        case .pong:
            let paddleHeight: CGFloat = 14
            if p.x < bounds.midX {
                leftPaddleY = max(1, min(bounds.height - paddleHeight - 1, p.y - paddleHeight / 2))
            } else {
                rightPaddleY = max(1, min(bounds.height - paddleHeight - 1, p.y - paddleHeight / 2))
            }

        case .snake:
            guard !dragging, let head = snake.first else { return }
            let target = CGPoint(x: p.x / snakeCell, y: p.y / snakeCell)
            let dx = target.x - head.x
            let dy = target.y - head.y
            if abs(dx) > abs(dy) { setSnakeDirection(x: dx >= 0 ? 1 : -1, y: 0) }
            else { setSnakeDirection(x: 0, y: dy >= 0 ? 1 : -1) }

        case .breakout:
            paddleX = max(38, min(bounds.width - 38, p.x))

        case .life:
            if p.x < lifeControlsWidth && !dragging {
                handleLifeControl(p.x)
                return
            }
            let gridWidth = max(1, bounds.width - lifeControlsWidth)
            let x = max(0, min(lifeColumns - 1, Int(((p.x - lifeControlsWidth) / gridWidth) * CGFloat(lifeColumns))))
            let y = max(0, min(lifeRows - 1, Int((p.y / max(1, bounds.height)) * CGFloat(lifeRows))))
            if lifePaintValue == nil { lifePaintValue = !life[x][y] }
            life[x][y] = lifePaintValue ?? true
        }
        needsDisplay = true
    }

    private func handleLifeControl(_ x: CGFloat) {
        switch x {
        case 0..<42:
            lifeRunning.toggle()
        case 42..<78:
            stepLife()
        case 78..<116:
            life = Array(repeating: Array(repeating: false, count: lifeRows), count: lifeColumns)
            lifeRunning = false
        default:
            for column in 0..<lifeColumns {
                for row in 0..<lifeRows { life[column][row] = Int.random(in: 0..<5) == 0 }
            }
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()
        switch game {
        case .pong: drawPong()
        case .snake: drawSnake()
        case .breakout: drawBreakout()
        case .life: drawLife()
        }
    }

    private func drawPong() {
        NSColor.white.setFill()
        NSRect(x: 8, y: leftPaddleY, width: 4, height: 14).fill()
        NSRect(x: bounds.width - 12, y: rightPaddleY, width: 4, height: 14).fill()
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
        "\(snakeScore)".draw(at: NSPoint(x: 3, y: bounds.height - 8), withAttributes: attrs)
    }

    private func drawBreakout() {
        for (index, brick) in bricks.enumerated() {
            let row = (index / 20) % 3
            let colors = [
                NSColor(calibratedRed: 0.95, green: 0.28, blue: 0.22, alpha: 1),
                NSColor(calibratedRed: 0.95, green: 0.72, blue: 0.18, alpha: 1),
                NSColor(calibratedRed: 0.25, green: 0.62, blue: 1.0, alpha: 1)
            ]
            colors[row].setFill()
            brick.fill()
        }
        NSColor.white.setFill()
        NSRect(x: paddleX - 34, y: 2, width: 68, height: 3).fill()
        NSRect(x: ball.x - 2, y: ball.y - 2, width: 4, height: 4).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .medium), .foregroundColor: NSColor.white]
        "\(breakoutScore)  ♥\(breakoutLives)".draw(at: NSPoint(x: 5, y: 5), withAttributes: attrs)
    }

    private func drawLife() {
        let controlRects: [(String, NSRect)] = [
            (lifeRunning ? "PAUSE" : "RUN", NSRect(x: 2, y: 3, width: 38, height: 23)),
            ("STEP", NSRect(x: 42, y: 3, width: 34, height: 23)),
            ("CLR", NSRect(x: 78, y: 3, width: 36, height: 23)),
            ("RND", NSRect(x: 116, y: 3, width: 36, height: 23))
        ]
        let buttonAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 7, weight: .bold), .foregroundColor: NSColor.white]
        for (label, rect) in controlRects {
            NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
            rect.fill()
            let size = label.size(withAttributes: buttonAttrs)
            label.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: buttonAttrs)
        }

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

// MARK: - Pitfall-style jungle runner

final class PitfallHomageView: NSView {
    private let keyMonitor = GameKeyMonitor()
    private var pressed = Set<UInt16>()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var worldX: CGFloat = 0
    private var heroY: CGFloat = 0
    private var verticalVelocity: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        keyMonitor.handler = { [weak self] event, down in
            if down { self?.pressed.insert(event.keyCode) } else { self?.pressed.remove(event.keyCode) }
        }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick)
        lastTick = now
        let speed: CGFloat = 80
        if pressed.contains(123) { worldX -= speed * CGFloat(dt) }
        if pressed.contains(124) { worldX += speed * CGFloat(dt) }
        if (pressed.contains(126) || pressed.contains(49)) && heroY <= 0.1 { verticalVelocity = 115 }
        verticalVelocity -= 250 * CGFloat(dt)
        heroY = max(0, heroY + verticalVelocity * CGFloat(dt))
        if heroY == 0 && verticalVelocity < 0 { verticalVelocity = 0 }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); dirtyRect.fill()
        let ground: CGFloat = 5
        NSColor(calibratedRed: 0.18, green: 0.65, blue: 0.14, alpha: 1).setFill()
        NSRect(x: 0, y: ground, width: bounds.width, height: 3).fill()

        let spacing: CGFloat = 110
        let first = floor(worldX / spacing) - 1
        for i in 0..<10 {
            let worldIndex = first + CGFloat(i)
            let x = worldIndex * spacing - worldX + 130
            if Int(abs(worldIndex)) % 3 == 1 {
                NSColor.black.setFill(); NSRect(x: x, y: ground - 1, width: 32, height: 7).fill()
                NSColor(calibratedRed: 0.25, green: 0.10, blue: 0.03, alpha: 1).setFill(); NSRect(x: x, y: 0, width: 32, height: 2).fill()
            } else {
                NSColor(calibratedRed: 0.55, green: 0.25, blue: 0.05, alpha: 1).setFill(); NSRect(x: x, y: ground + 1, width: 18, height: 4).fill()
            }
            NSColor(calibratedRed: 0.05, green: 0.36, blue: 0.08, alpha: 1).setFill()
            NSRect(x: x + 45, y: ground + 2, width: 4, height: 20).fill()
            NSRect(x: x + 38, y: ground + 18, width: 18, height: 4).fill()
        }

        let hx: CGFloat = 90
        let hy = ground + 3 + heroY
        NSColor(calibratedRed: 0.92, green: 0.70, blue: 0.42, alpha: 1).setFill(); NSRect(x: hx, y: hy + 6, width: 5, height: 7).fill()
        NSColor(calibratedRed: 0.90, green: 0.20, blue: 0.10, alpha: 1).setFill(); NSRect(x: hx - 1, y: hy + 2, width: 7, height: 5).fill()
        NSColor.white.setFill(); NSRect(x: hx, y: hy, width: 2, height: 3).fill(); NSRect(x: hx + 4, y: hy, width: 2, height: 3).fill()
    }
}

// MARK: - E.T.-style phone-piece rescue

final class ETHomageView: NSView {
    private let keyMonitor = GameKeyMonitor()
    private var pressed = Set<UInt16>()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var playerX: CGFloat = 80
    private var pieces = [CGPoint(x: 210, y: 8), CGPoint(x: 430, y: 8), CGPoint(x: 650, y: 8)]
    private var collected = Set<Int>()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        keyMonitor.handler = { [weak self] event, down in
            if down { self?.pressed.insert(event.keyCode) } else { self?.pressed.remove(event.keyCode) }
            if down && event.keyCode == 49 { self?.collectNearby() }
        }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick); lastTick = now
        if pressed.contains(123) { playerX -= 82 * CGFloat(dt) }
        if pressed.contains(124) { playerX += 82 * CGFloat(dt) }
        playerX = max(12, min(bounds.width - 20, playerX))
        needsDisplay = true
    }

    private func collectNearby() {
        for index in pieces.indices where !collected.contains(index) {
            if abs(pieces[index].x - playerX) < 24 { collected.insert(index) }
        }
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) { collectNearby() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.03, green: 0.07, blue: 0.03, alpha: 1).setFill(); dirtyRect.fill()
        NSColor(calibratedRed: 0.20, green: 0.52, blue: 0.14, alpha: 1).setFill(); NSRect(x: 0, y: 3, width: bounds.width, height: 3).fill()
        for i in pieces.indices where !collected.contains(i) {
            NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.20, alpha: 1).setFill()
            NSRect(x: pieces[i].x, y: pieces[i].y, width: 7, height: 4).fill()
        }
        NSColor(calibratedRed: 0.58, green: 0.32, blue: 0.18, alpha: 1).setFill()
        NSRect(x: playerX, y: 6, width: 8, height: 13).fill(); NSRect(x: playerX - 2, y: 16, width: 12, height: 6).fill()
        NSColor.white.setFill(); NSRect(x: playerX + 2, y: 19, width: 2, height: 1).fill(); NSRect(x: playerX + 7, y: 19, width: 2, height: 1).fill()

        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 7, weight: .bold), .foregroundColor: NSColor.white]
        let text = collected.count == pieces.count ? "PHONE COMPLETE  •  CALL HOME" : "PHONE \(collected.count)/\(pieces.count)  SPACE/TAP TO TAKE"
        text.draw(at: NSPoint(x: 12, y: bounds.height - 9), withAttributes: attrs)
    }
}

// MARK: - Vector cave flyer

final class CaveFlyerView: NSView {
    private let keyMonitor = GameKeyMonitor()
    private var pressed = Set<UInt16>()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var distance: CGFloat = 0
    private var shipY: CGFloat = 15
    private var score = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        keyMonitor.handler = { [weak self] event, down in
            if down { self?.pressed.insert(event.keyCode) } else { self?.pressed.remove(event.keyCode) }
        }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func ceiling(at worldX: CGFloat) -> CGFloat {
        23 + sin(worldX * 0.025) * 3 + sin(worldX * 0.071) * 2
    }

    private func floorY(at worldX: CGFloat) -> CGFloat {
        6 + sin(worldX * 0.031 + 1.8) * 2 + sin(worldX * 0.083) * 1.5
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick); lastTick = now
        distance += 70 * CGFloat(dt)
        if pressed.contains(126) || pressed.contains(13) { shipY += 68 * CGFloat(dt) }
        if pressed.contains(125) || pressed.contains(1) { shipY -= 68 * CGFloat(dt) }
        shipY = max(2, min(bounds.height - 2, shipY))

        let worldX = distance + 86
        if shipY + 3 > ceiling(at: worldX) || shipY - 3 < floorY(at: worldX) {
            distance = 0; shipY = bounds.midY; score = 0
        } else {
            score = Int(distance / 10)
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); dirtyRect.fill()
        let green = NSColor(calibratedRed: 0.25, green: 1.0, blue: 0.45, alpha: 1)
        green.setStroke()
        let top = NSBezierPath(); let bottom = NSBezierPath()
        for x in stride(from: CGFloat(0), through: bounds.width, by: 5) {
            let wx = distance + x
            let cy = ceiling(at: wx)
            let fy = floorY(at: wx)
            if x == 0 { top.move(to: NSPoint(x: x, y: cy)); bottom.move(to: NSPoint(x: x, y: fy)) }
            else { top.line(to: NSPoint(x: x, y: cy)); bottom.line(to: NSPoint(x: x, y: fy)) }
        }
        top.lineWidth = 1; bottom.lineWidth = 1; top.stroke(); bottom.stroke()

        let sx: CGFloat = 86
        let ship = NSBezierPath()
        ship.move(to: NSPoint(x: sx + 7, y: shipY))
        ship.line(to: NSPoint(x: sx - 5, y: shipY + 4))
        ship.line(to: NSPoint(x: sx - 2, y: shipY))
        ship.line(to: NSPoint(x: sx - 5, y: shipY - 4))
        ship.close(); ship.lineWidth = 1; ship.stroke()
        let flame = NSBezierPath(); flame.move(to: NSPoint(x: sx - 3, y: shipY)); flame.line(to: NSPoint(x: sx - 9, y: shipY)); flame.stroke()

        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .medium), .foregroundColor: green]
        "\(score)  ↑↓ / W S".draw(at: NSPoint(x: 5, y: bounds.height - 8), withAttributes: attrs)
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
    private var lines = ["WELCOME TO A VERY SMALL ADVENTURE.", "TAP > TO TYPE. TRY LOOK OR N."]
    private var command = ""
    private var editing = false
    private var localMonitor: Any?

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.editing else { return event }
            self.consumeKey(event)
            return nil
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }

    override func mouseDown(with event: NSEvent) {
        editing = true
        NSApp.activate(ignoringOtherApps: true)
        window?.makeFirstResponder(self)
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
            room = destination
            appendLine(rooms[room]?.description ?? "DARKNESS.")
            return
        }
        switch normalized {
        case "LOOK", "L":
            appendLine(rooms[room]?.description ?? "DARKNESS.")
        case "TAKE LAMP", "GET LAMP":
            if room == "chamber" && !inventory.contains("LAMP") {
                inventory.insert("LAMP"); appendLine("TAKEN: BRASS LAMP.")
            } else { appendLine("YOU SEE NO LAMP TO TAKE.") }
        case "TAKE TREASURE", "GET TREASURE":
            if room == "vault" && !inventory.contains("TREASURE") {
                inventory.insert("TREASURE"); appendLine("TREASURE TAKEN. NICE WORK.")
            } else { appendLine("NO TREASURE HERE.") }
        case "I", "INV", "INVENTORY":
            appendLine(inventory.isEmpty ? "YOU ARE EMPTY-HANDED." : "YOU HAVE: " + inventory.sorted().joined(separator: ", "))
        case "HELP":
            appendLine("N S E W, LOOK, TAKE LAMP, INV.")
        default:
            appendLine("I DON'T UNDERSTAND THAT.")
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); dirtyRect.fill()
        let green = NSColor(calibratedRed: 0.20, green: 1.0, blue: 0.38, alpha: 1)
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 5.5, weight: .regular), .foregroundColor: green]
        let lineHeight: CGFloat = 6.5
        var y = bounds.height - lineHeight
        for line in lines.suffix(3) {
            line.draw(at: NSPoint(x: 6, y: y), withAttributes: attrs)
            y -= lineHeight
        }
        let prompt = "> " + command + (editing ? "_" : "▮")
        prompt.draw(at: NSPoint(x: 6, y: 2), withAttributes: attrs)
    }
}
