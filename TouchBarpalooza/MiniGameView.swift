import AppKit

final class MiniGameView: NSView {
    enum Game {
        case pong, snake, breakout, life
    }

    private let game: Game
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime

    private var ball = CGPoint(x: 160, y: 12)
    private var velocity = CGVector(dx: 90, dy: 55)
    private var paddleX: CGFloat = 80
    private var enemyY: CGFloat = 9

    private var snake: [CGPoint] = [CGPoint(x: 12, y: 3), CGPoint(x: 11, y: 3), CGPoint(x: 10, y: 3)]
    private var snakeDirection = CGPoint(x: 1, y: 0)
    private var snakeAccumulator: TimeInterval = 0
    private var food = CGPoint(x: 35, y: 3)

    private var bricks: [CGRect] = []

    private var lifeColumns = 90
    private var lifeRows = 6
    private var life: [[Bool]] = []
    private var lifeAccumulator: TimeInterval = 0

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
        resetGame()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    deinit { timer?.invalidate() }

    private func resetGame() {
        ball = CGPoint(x: max(80, bounds.width * 0.45), y: 14)
        velocity = CGVector(dx: 95, dy: 48)
        paddleX = max(40, bounds.width * 0.5)
        enemyY = 9

        snake = [CGPoint(x: 12, y: 3), CGPoint(x: 11, y: 3), CGPoint(x: 10, y: 3)]
        snakeDirection = CGPoint(x: 1, y: 0)
        food = CGPoint(x: 35, y: 3)

        bricks.removeAll()
        let columns = 16
        for row in 0..<2 {
            for column in 0..<columns {
                bricks.append(CGRect(x: CGFloat(column) * 20 + 8, y: CGFloat(row) * 5 + 2, width: 16, height: 3))
            }
        }

        life = Array(repeating: Array(repeating: false, count: lifeRows), count: lifeColumns)
        for x in stride(from: 5, to: lifeColumns - 5, by: 11) {
            life[x][2] = true
            life[x + 1][3] = true
            life[x + 2][1] = true
            life[x + 2][2] = true
            life[x + 2][3] = true
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

    private func updatePong(_ dt: TimeInterval) {
        ball.x += velocity.dx * CGFloat(dt)
        ball.y += velocity.dy * CGFloat(dt)
        if ball.y < 2 || ball.y > bounds.height - 2 { velocity.dy *= -1 }
        enemyY += (ball.y - enemyY - 6) * 0.08

        if ball.x < 18 && ball.y > enemyY && ball.y < enemyY + 12 {
            ball.x = 18
            velocity.dx = abs(velocity.dx)
        }
        if ball.x > bounds.width - 20 && abs(ball.y - 15) < 11 {
            ball.x = bounds.width - 20
            velocity.dx = -abs(velocity.dx)
        }
        if ball.x < 0 || ball.x > bounds.width { resetGame() }
    }

    private func updateSnake(_ dt: TimeInterval) {
        snakeAccumulator += dt
        guard snakeAccumulator > 0.11 else { return }
        snakeAccumulator = 0
        guard let head = snake.first else { return }
        var next = CGPoint(x: head.x + snakeDirection.x, y: head.y + snakeDirection.y)
        let cols = max(20, Int(bounds.width / 6))
        if next.x < 0 { next.x = CGFloat(cols - 1) }
        if next.x >= CGFloat(cols) { next.x = 0 }
        if next.y < 0 { next.y = 4 }
        if next.y > 4 { next.y = 0 }
        if snake.contains(next) { resetGame(); return }
        snake.insert(next, at: 0)
        if next == food {
            food = CGPoint(x: CGFloat(Int.random(in: 4..<max(5, cols - 4))), y: CGFloat(Int.random(in: 0...4)))
        } else {
            snake.removeLast()
        }
    }

    private func updateBreakout(_ dt: TimeInterval) {
        ball.x += velocity.dx * CGFloat(dt)
        ball.y += velocity.dy * CGFloat(dt)
        if ball.x < 2 || ball.x > bounds.width - 2 { velocity.dx *= -1 }
        if ball.y < 2 { velocity.dy = abs(velocity.dy) }
        if ball.y > bounds.height - 5 {
            if abs(ball.x - paddleX) < 34 {
                velocity.dy = -abs(velocity.dy)
                ball.y = bounds.height - 6
            } else {
                resetGame()
                return
            }
        }
        let ballRect = CGRect(x: ball.x - 2, y: ball.y - 2, width: 4, height: 4)
        if let index = bricks.firstIndex(where: { $0.intersects(ballRect) }) {
            bricks.remove(at: index)
            velocity.dy *= -1
            if bricks.isEmpty { resetGame() }
        }
    }

    private func updateLife(_ dt: TimeInterval) {
        lifeAccumulator += dt
        guard lifeAccumulator > 0.14 else { return }
        lifeAccumulator = 0
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

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        handleTouch(p)
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        handleTouch(p)
    }

    private func handleTouch(_ p: CGPoint) {
        switch game {
        case .pong:
            enemyY = max(0, min(bounds.height - 12, p.y - 6))
        case .snake:
            guard let head = snake.first else { return }
            let target = CGPoint(x: p.x / 6, y: p.y / 6)
            let dx = target.x - head.x
            let dy = target.y - head.y
            if abs(dx) > abs(dy) {
                snakeDirection = CGPoint(x: dx >= 0 ? 1 : -1, y: 0)
            } else {
                snakeDirection = CGPoint(x: 0, y: dy >= 0 ? 1 : -1)
            }
        case .breakout:
            paddleX = max(34, min(bounds.width - 34, p.x))
        case .life:
            let x = max(0, min(lifeColumns - 1, Int((p.x / max(1, bounds.width)) * CGFloat(lifeColumns))))
            let y = max(0, min(lifeRows - 1, Int((p.y / max(1, bounds.height)) * CGFloat(lifeRows))))
            life[x][y].toggle()
        }
    }

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
        NSRect(x: 8, y: enemyY, width: 4, height: 12).fill()
        NSRect(x: bounds.width - 12, y: 9, width: 4, height: 12).fill()
        NSRect(x: ball.x - 2, y: ball.y - 2, width: 4, height: 4).fill()
        for y in stride(from: CGFloat(1), through: bounds.height, by: 6) {
            NSRect(x: bounds.midX, y: y, width: 1, height: 3).fill()
        }
    }

    private func drawSnake() {
        let cell: CGFloat = 6
        NSColor(calibratedRed: 0.2, green: 0.95, blue: 0.3, alpha: 1).setFill()
        for part in snake { NSRect(x: part.x * cell, y: part.y * cell, width: cell - 1, height: cell - 1).fill() }
        NSColor(calibratedRed: 1, green: 0.25, blue: 0.1, alpha: 1).setFill()
        NSRect(x: food.x * cell, y: food.y * cell, width: cell - 1, height: cell - 1).fill()
    }

    private func drawBreakout() {
        NSColor(calibratedRed: 0.25, green: 0.62, blue: 1.0, alpha: 1).setFill()
        for brick in bricks { brick.fill() }
        NSColor.white.setFill()
        NSRect(x: paddleX - 30, y: bounds.height - 3, width: 60, height: 3).fill()
        NSRect(x: ball.x - 2, y: ball.y - 2, width: 4, height: 4).fill()
    }

    private func drawLife() {
        let cw = bounds.width / CGFloat(lifeColumns)
        let ch = bounds.height / CGFloat(lifeRows)
        NSColor(calibratedRed: 0.15, green: 0.86, blue: 0.95, alpha: 1).setFill()
        for x in 0..<lifeColumns {
            for y in 0..<lifeRows where life[x][y] {
                NSRect(x: CGFloat(x) * cw, y: CGFloat(y) * ch, width: max(1, cw - 0.5), height: max(1, ch - 0.5)).fill()
            }
        }
    }
}
