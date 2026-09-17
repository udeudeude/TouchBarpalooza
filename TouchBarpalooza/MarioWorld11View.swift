import AppKit

private final class MarioKeyMonitor {
    private var monitors: [Any] = []
    var handler: ((NSEvent, Bool) -> Void)?

    init() {
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            self?.handler?(event, true)
        }) {
            monitors.append(monitor)
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: { [weak self] event in
            self?.handler?(event, false)
        }) {
            monitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp], handler: { [weak self] event in
            self?.handler?(event, event.type == .keyDown)
            return event
        }) {
            monitors.append(monitor)
        }
    }

    deinit {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
    }
}

private func focusMarioKeyboard() {
    NSApp.activate(ignoringOtherApps: true)
    if let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first {
        window.makeKeyAndOrderFront(nil)
    }
}

final class TouchBarPlatformerView: NSView {
    private struct Pipe {
        let x: CGFloat
        let height: CGFloat
    }

    private struct BlockRect {
        let x: CGFloat
        let yFromTop: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    private struct Enemy {
        enum Kind {
            case goomba
            case koopa
        }

        var kind: Kind
        var x: CGFloat
        var direction: CGFloat
        var alive: Bool
    }

    private let keyMonitor = MarioKeyMonitor()
    private var pressed = Set<UInt16>()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var playerX: CGFloat = 32
    private var playerY: CGFloat = 0
    private var horizontalVelocity: CGFloat = 0
    private var verticalVelocity: CGFloat = 0
    private var facing: CGFloat = 1
    private var grounded = true
    private var lives = 3
    private var coins = 0
    private var score = 0
    private var timeRemaining: TimeInterval = 400
    private var runLatched = false
    private var invulnerable: TimeInterval = 0
    private var finishedUntil: TimeInterval = 0
    private var usedQuestionBlocks = Set<Int>()
    private var enemies: [Enemy] = []

    private let controlsWidth: CGFloat = 158
    private let xScale: CGFloat = 0.55
    private let yScale: CGFloat = 0.17
    private let worldLength: CGFloat = 3392
    private let groundTopY: CGFloat = 200

    private let groundRanges: [ClosedRange<CGFloat>] = [
        0...1104,
        1136...1376,
        1424...2448,
        2480...3392
    ]

    private let pipes: [Pipe] = [
        Pipe(x: 448, height: 32),
        Pipe(x: 608, height: 48),
        Pipe(x: 736, height: 64),
        Pipe(x: 912, height: 64),
        Pipe(x: 2608, height: 32),
        Pipe(x: 2864, height: 32)
    ]

    private let questionBlocks: [NSPoint] = [
        NSPoint(x: 256, y: 136), NSPoint(x: 336, y: 136), NSPoint(x: 352, y: 72),
        NSPoint(x: 368, y: 136), NSPoint(x: 1248, y: 136), NSPoint(x: 1504, y: 136),
        NSPoint(x: 1696, y: 136), NSPoint(x: 1744, y: 136), NSPoint(x: 1744, y: 72),
        NSPoint(x: 1792, y: 136), NSPoint(x: 2064, y: 72), NSPoint(x: 2080, y: 72),
        NSPoint(x: 2720, y: 136)
    ]

    private let brickBlocks: [NSPoint] = [
        NSPoint(x: 320, y: 136), NSPoint(x: 352, y: 136), NSPoint(x: 384, y: 136),
        NSPoint(x: 1232, y: 136), NSPoint(x: 1264, y: 136), NSPoint(x: 1280, y: 72),
        NSPoint(x: 1296, y: 72), NSPoint(x: 1312, y: 72), NSPoint(x: 1328, y: 72),
        NSPoint(x: 1344, y: 72), NSPoint(x: 1360, y: 72), NSPoint(x: 1376, y: 72),
        NSPoint(x: 1392, y: 72), NSPoint(x: 1456, y: 72), NSPoint(x: 1472, y: 72),
        NSPoint(x: 1488, y: 72), NSPoint(x: 1504, y: 136), NSPoint(x: 1600, y: 136),
        NSPoint(x: 1616, y: 136), NSPoint(x: 1888, y: 136), NSPoint(x: 1936, y: 72),
        NSPoint(x: 1952, y: 72), NSPoint(x: 1968, y: 72), NSPoint(x: 2048, y: 72),
        NSPoint(x: 2096, y: 72), NSPoint(x: 2064, y: 136), NSPoint(x: 2080, y: 136),
        NSPoint(x: 2688, y: 136), NSPoint(x: 2704, y: 136), NSPoint(x: 2736, y: 136)
    ]

    private let stairRects: [BlockRect] = [
        BlockRect(x: 2144, yFromTop: 184, width: 64, height: 16),
        BlockRect(x: 2160, yFromTop: 168, width: 48, height: 16),
        BlockRect(x: 2176, yFromTop: 152, width: 32, height: 16),
        BlockRect(x: 2192, yFromTop: 136, width: 16, height: 16),
        BlockRect(x: 2240, yFromTop: 136, width: 16, height: 16),
        BlockRect(x: 2240, yFromTop: 152, width: 32, height: 16),
        BlockRect(x: 2240, yFromTop: 168, width: 48, height: 16),
        BlockRect(x: 2240, yFromTop: 184, width: 64, height: 16),
        BlockRect(x: 2368, yFromTop: 184, width: 80, height: 16),
        BlockRect(x: 2384, yFromTop: 168, width: 64, height: 16),
        BlockRect(x: 2400, yFromTop: 152, width: 48, height: 16),
        BlockRect(x: 2416, yFromTop: 136, width: 32, height: 16),
        BlockRect(x: 2480, yFromTop: 136, width: 16, height: 16),
        BlockRect(x: 2480, yFromTop: 152, width: 32, height: 16),
        BlockRect(x: 2480, yFromTop: 168, width: 48, height: 16),
        BlockRect(x: 2480, yFromTop: 184, width: 64, height: 16),
        BlockRect(x: 2896, yFromTop: 184, width: 144, height: 16),
        BlockRect(x: 2912, yFromTop: 168, width: 128, height: 16),
        BlockRect(x: 2928, yFromTop: 152, width: 112, height: 16),
        BlockRect(x: 2944, yFromTop: 136, width: 96, height: 16),
        BlockRect(x: 2960, yFromTop: 120, width: 80, height: 16),
        BlockRect(x: 2976, yFromTop: 104, width: 64, height: 16),
        BlockRect(x: 2992, yFromTop: 88, width: 48, height: 16),
        BlockRect(x: 3008, yFromTop: 72, width: 32, height: 16),
        BlockRect(x: 3168, yFromTop: 184, width: 16, height: 16)
    ]

    override var intrinsicContentSize: NSSize {
        NSSize(width: 660, height: 30)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        resetEnemies()
        keyMonitor.handler = { [weak self] event, down in
            self?.handleKey(event, down: down)
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

    deinit {
        timer?.invalidate()
    }

    private func resetEnemies() {
        let goombaStarts: [CGFloat] = [
            352, 640, 864, 872, 1536, 1568, 1856, 1864,
            2384, 2392, 2544, 2552, 2608, 2616, 3088, 3096
        ]
        enemies = goombaStarts.map {
            Enemy(kind: .goomba, x: $0, direction: -1, alive: true)
        }
        enemies.append(Enemy(kind: .koopa, x: 2224, direction: -1, alive: true))
    }

    private func buildControls() {
        let left = NSButton(title: "◀", target: self, action: #selector(stepLeft))
        left.frame = NSRect(x: 2, y: 2, width: 25, height: 26)
        left.isContinuous = true
        left.periodicDelay = 0.18
        left.periodicInterval = 0.055
        addSubview(left)

        let jump = NSButton(title: "JUMP", target: self, action: #selector(jumpPressed))
        jump.font = .systemFont(ofSize: 7)
        jump.frame = NSRect(x: 29, y: 2, width: 40, height: 26)
        addSubview(jump)

        let right = NSButton(title: "▶", target: self, action: #selector(stepRight))
        right.frame = NSRect(x: 71, y: 2, width: 25, height: 26)
        right.isContinuous = true
        right.periodicDelay = 0.18
        right.periodicInterval = 0.055
        addSubview(right)

        let run = NSButton(title: "RUN", target: self, action: #selector(toggleRun(_:)))
        run.font = .systemFont(ofSize: 6.5)
        run.frame = NSRect(x: 98, y: 2, width: 27, height: 26)
        run.setButtonType(.pushOnPushOff)
        addSubview(run)

        let keys = NSButton(title: "KEYS", target: self, action: #selector(focusKeyboard))
        keys.font = .monospacedSystemFont(ofSize: 6.2, weight: .bold)
        keys.frame = NSRect(x: 127, y: 2, width: 29, height: 26)
        keys.toolTip = "Switch keyboard control to TouchBarpalooza"
        addSubview(keys)
    }

    @objc private func stepLeft() {
        playerX = max(0, playerX - 18)
        facing = -1
        needsDisplay = true
    }

    @objc private func stepRight() {
        playerX = min(worldLength, playerX + 18)
        facing = 1
        needsDisplay = true
    }

    @objc private func jumpPressed() {
        jump()
    }

    @objc private func toggleRun(_ sender: NSButton) {
        runLatched = sender.state == .on
    }

    @objc private func focusKeyboard() {
        focusMarioKeyboard()
    }

    private func handleKey(_ event: NSEvent, down: Bool) {
        if down {
            pressed.insert(event.keyCode)
            if event.keyCode == 49 || event.keyCode == 6 || event.keyCode == 126 || event.keyCode == 13 {
                jump()
            }
        } else {
            pressed.remove(event.keyCode)
            if (event.keyCode == 49 || event.keyCode == 6 || event.keyCode == 126 || event.keyCode == 13),
               verticalVelocity > 70 {
                verticalVelocity *= 0.52
            }
        }
    }

    private func jump() {
        guard grounded else { return }
        grounded = false
        verticalVelocity = 238 + min(abs(horizontalVelocity), 180) * 0.17
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.05, now - lastTick)
        lastTick = now

        invulnerable = max(0, invulnerable - dt)
        finishedUntil = max(0, finishedUntil - dt)
        if finishedUntil > 0 {
            needsDisplay = true
            return
        }
        timeRemaining = max(0, timeRemaining - dt)

        var input: CGFloat = 0
        if pressed.contains(123) || pressed.contains(0) { input -= 1 }
        if pressed.contains(124) || pressed.contains(2) { input += 1 }

        let running = runLatched || pressed.contains(56) || pressed.contains(60) || pressed.contains(7)
        let maxSpeed: CGFloat = running ? 184 : 112
        let acceleration: CGFloat = running ? 330 : 250

        if input != 0 {
            facing = input
            horizontalVelocity += input * acceleration * CGFloat(dt)
            horizontalVelocity = max(-maxSpeed, min(maxSpeed, horizontalVelocity))
        } else {
            let braking = 360 * CGFloat(dt)
            if horizontalVelocity > 0 {
                horizontalVelocity = max(0, horizontalVelocity - braking)
            } else if horizontalVelocity < 0 {
                horizontalVelocity = min(0, horizontalVelocity + braking)
            }
        }

        moveHorizontally(dt: dt)
        verticalVelocity -= 500 * CGFloat(dt)
        let oldY = playerY
        playerY += verticalVelocity * CGFloat(dt)
        resolveVerticalMovement(oldY: oldY)
        updateEnemies(dt: dt)
        handleEnemyCollisions()
        handleBlockHit(oldY: oldY)

        if playerY < -55 || timeRemaining <= 0 {
            loseLife()
        }

        if playerX >= 3168 {
            score += max(100, Int(timeRemaining) * 10)
            finishedUntil = 1.25
            playerX = 32
            playerY = 0
            horizontalVelocity = 0
            verticalVelocity = 0
            timeRemaining = 400
            usedQuestionBlocks.removeAll()
            resetEnemies()
        }

        needsDisplay = true
    }

    private func moveHorizontally(dt: TimeInterval) {
        let oldX = playerX
        var nextX = max(0, min(worldLength, playerX + horizontalVelocity * CGFloat(dt)))

        for pipe in pipes {
            let left = pipe.x - 7
            let right = pipe.x + 39
            if playerY < pipe.height - 2 {
                if oldX <= left && nextX > left {
                    nextX = left
                    horizontalVelocity = 0
                } else if oldX >= right && nextX < right {
                    nextX = right
                    horizontalVelocity = 0
                }
            }
        }

        playerX = nextX
    }

    private func resolveVerticalMovement(oldY: CGFloat) {
        let support = supportHeight(at: playerX)
        if verticalVelocity <= 0 && oldY >= support && playerY <= support {
            playerY = support
            verticalVelocity = 0
            grounded = true
        } else {
            grounded = abs(playerY - support) < 0.2
        }
    }

    private func supportHeight(at x: CGFloat) -> CGFloat {
        var support: CGFloat = groundRanges.contains(where: { $0.contains(x) }) ? 0 : -1000

        for pipe in pipes where x >= pipe.x - 3 && x <= pipe.x + 35 {
            support = max(support, pipe.height)
        }

        for point in questionBlocks + brickBlocks where x >= point.x - 5 && x <= point.x + 21 {
            let top = groundTopY - point.y
            if playerY >= top - 8 {
                support = max(support, top)
            }
        }

        for rect in stairRects where x >= rect.x - 4 && x <= rect.x + rect.width + 4 {
            let top = groundTopY - rect.yFromTop
            if playerY >= top - 8 {
                support = max(support, top)
            }
        }

        return support
    }

    private func handleBlockHit(oldY: CGFloat) {
        guard verticalVelocity > 0 || playerY > oldY else { return }
        let playerTop = playerY + 16
        let oldTop = oldY + 16

        for index in questionBlocks.indices {
            let block = questionBlocks[index]
            let bottom = groundTopY - (block.y + 16)
            if abs(playerX - (block.x + 8)) < 13 && oldTop <= bottom && playerTop >= bottom {
                playerY = bottom - 16
                verticalVelocity = -48
                if !usedQuestionBlocks.contains(index) {
                    usedQuestionBlocks.insert(index)
                    coins += 1
                    score += 200
                }
                return
            }
        }

        for block in brickBlocks {
            let bottom = groundTopY - (block.y + 16)
            if abs(playerX - (block.x + 8)) < 13 && oldTop <= bottom && playerTop >= bottom {
                playerY = bottom - 16
                verticalVelocity = -48
                return
            }
        }
    }

    private func updateEnemies(dt: TimeInterval) {
        for index in enemies.indices where enemies[index].alive {
            let speed: CGFloat = enemies[index].kind == .goomba ? 34 : 31
            let next = enemies[index].x + enemies[index].direction * speed * CGFloat(dt)
            let onGround = groundRanges.contains(where: { $0.contains(next) })
            let hitsPipe = pipes.contains { pipe in
                next > pipe.x - 8 && next < pipe.x + 40
            }

            if onGround && !hitsPipe {
                enemies[index].x = next
            } else {
                enemies[index].direction *= -1
            }
        }
    }

    private func handleEnemyCollisions() {
        guard invulnerable <= 0 else { return }
        for index in enemies.indices where enemies[index].alive {
            if abs(enemies[index].x - playerX) < 11 {
                if verticalVelocity < 0 && playerY > 8 {
                    enemies[index].alive = false
                    verticalVelocity = 118
                    score += enemies[index].kind == .goomba ? 100 : 200
                } else if playerY < 11 {
                    loseLife()
                    return
                }
            }
        }
    }

    private func loseLife() {
        lives -= 1
        if lives <= 0 {
            lives = 3
            coins = 0
            score = 0
            usedQuestionBlocks.removeAll()
            resetEnemies()
        }
        playerX = playerX > 1700 ? 1632 : 32
        playerY = 0
        horizontalVelocity = 0
        verticalVelocity = 0
        grounded = true
        timeRemaining = 400
        invulnerable = 1.1
    }

    override func draw(_ dirtyRect: NSRect) {
        let sky = NSColor(calibratedRed: 0.36, green: 0.58, blue: 0.98, alpha: 1)
        sky.setFill()
        dirtyRect.fill()

        let gameLeft = controlsWidth
        let gameWidth = max(1, bounds.width - gameLeft)
        let visibleWorldWidth = gameWidth / xScale
        let camera = max(0, min(worldLength - visibleWorldWidth, playerX - visibleWorldWidth * 0.18))

        drawBackground(camera: camera, gameLeft: gameLeft)
        drawGround(camera: camera, gameLeft: gameLeft)
        drawBlocks(camera: camera, gameLeft: gameLeft)
        drawPipes(camera: camera, gameLeft: gameLeft)
        drawEnemies(camera: camera, gameLeft: gameLeft)
        drawFlagAndCastle(camera: camera, gameLeft: gameLeft)

        let playerScreenX = gameLeft + (playerX - camera) * xScale
        if invulnerable <= 0 || Int(invulnerable * 14) % 2 == 0 {
            drawMario(at: NSPoint(x: playerScreenX, y: 4 + playerY * yScale))
        }

        let hud = finishedUntil > 0
            ? "COURSE CLEAR"
            : String(format: "MARIO %05d   ×%02d   1-1   %03d", score, coins, Int(timeRemaining))
        (hud as NSString).draw(
            at: NSPoint(x: gameLeft + 3, y: 22),
            withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 5.8, weight: .bold),
                .foregroundColor: NSColor.white
            ]
        )
    }

    private func drawBackground(camera: CGFloat, gameLeft: CGFloat) {
        let cloud = NSColor.white
        let bush = NSColor(calibratedRed: 0.18, green: 0.68, blue: 0.15, alpha: 1)
        let hill = NSColor(calibratedRed: 0.24, green: 0.76, blue: 0.28, alpha: 1)

        for base in stride(from: CGFloat(280), through: worldLength, by: 760) {
            let x = gameLeft + (base - camera * 0.70) * xScale
            if x > gameLeft - 30 && x < bounds.width + 30 {
                hill.setFill()
                let path = NSBezierPath()
                path.move(to: NSPoint(x: x - 20, y: 4))
                path.line(to: NSPoint(x: x, y: 14))
                path.line(to: NSPoint(x: x + 24, y: 4))
                path.close()
                path.fill()
                NSColor.black.setFill()
                NSRect(x: x - 4, y: 8, width: 2, height: 2).fill()
                NSRect(x: x + 7, y: 8, width: 2, height: 2).fill()
            }
        }

        for base in stride(from: CGFloat(430), through: worldLength, by: 520) {
            let x = gameLeft + (base - camera * 0.83) * xScale
            if x > gameLeft - 20 && x < bounds.width + 20 {
                bush.setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: 4, width: 20, height: 7)).fill()
                NSBezierPath(ovalIn: NSRect(x: x + 8, y: 5, width: 16, height: 8)).fill()
            }
        }

        for base in stride(from: CGFloat(350), through: worldLength, by: 610) {
            let x = gameLeft + (base - camera * 0.55) * xScale
            if x > gameLeft - 24 && x < bounds.width + 24 {
                cloud.setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: 20, width: 12, height: 5)).fill()
                NSBezierPath(ovalIn: NSRect(x: x + 6, y: 21, width: 14, height: 6)).fill()
                NSBezierPath(ovalIn: NSRect(x: x + 13, y: 20, width: 10, height: 5)).fill()
            }
        }
    }

    private func drawGround(camera: CGFloat, gameLeft: CGFloat) {
        let ground = NSColor(calibratedRed: 0.78, green: 0.34, blue: 0.10, alpha: 1)
        let dark = NSColor(calibratedRed: 0.45, green: 0.15, blue: 0.04, alpha: 1)

        for range in groundRanges {
            let x = gameLeft + (range.lowerBound - camera) * xScale
            let width = (range.upperBound - range.lowerBound) * xScale
            if x + width < gameLeft || x > bounds.width { continue }
            ground.setFill()
            NSRect(x: x, y: 0, width: width, height: 4).fill()
            dark.setFill()
            for tileX in stride(from: x, through: x + width, by: 9) {
                NSRect(x: tileX, y: 0, width: 1, height: 4).fill()
            }
        }
    }

    private func drawBlocks(camera: CGFloat, gameLeft: CGFloat) {
        for index in questionBlocks.indices {
            let point = questionBlocks[index]
            let x = gameLeft + (point.x - camera) * xScale
            let y = 4 + (groundTopY - point.y) * yScale
            if x < gameLeft - 12 || x > bounds.width + 12 { continue }
            drawQuestionBlock(at: NSPoint(x: x, y: y), used: usedQuestionBlocks.contains(index))
        }

        for point in brickBlocks {
            let x = gameLeft + (point.x - camera) * xScale
            let y = 4 + (groundTopY - point.y) * yScale
            if x < gameLeft - 12 || x > bounds.width + 12 { continue }
            drawBrickTile(at: NSPoint(x: x, y: y))
        }

        for rect in stairRects {
            let x = gameLeft + (rect.x - camera) * xScale
            let y = 4 + (groundTopY - rect.yFromTop) * yScale
            let width = rect.width * xScale
            let height = max(2.4, rect.height * yScale)
            if x + width < gameLeft || x > bounds.width { continue }
            NSColor(calibratedRed: 0.78, green: 0.34, blue: 0.10, alpha: 1).setFill()
            NSRect(x: x, y: y, width: width, height: height).fill()
            NSColor(calibratedRed: 0.43, green: 0.13, blue: 0.03, alpha: 1).setFill()
            for tileX in stride(from: x, through: x + width, by: 8.8) {
                NSRect(x: tileX, y: y, width: 0.8, height: height).fill()
            }
        }
    }

    private func drawPipes(camera: CGFloat, gameLeft: CGFloat) {
        for pipe in pipes {
            let x = gameLeft + (pipe.x - camera) * xScale
            let height = pipe.height * yScale
            if x < gameLeft - 24 || x > bounds.width + 24 { continue }
            NSColor(calibratedRed: 0.07, green: 0.69, blue: 0.12, alpha: 1).setFill()
            NSRect(x: x + 2, y: 4, width: 12, height: height).fill()
            NSRect(x: x, y: 4 + height - 3.2, width: 16, height: 3.5).fill()
            NSColor(calibratedRed: 0.01, green: 0.30, blue: 0.04, alpha: 1).setFill()
            NSRect(x: x + 10, y: 4, width: 2.2, height: height).fill()
            NSRect(x: x + 12.8, y: 4 + height - 3.2, width: 2, height: 3.5).fill()
        }
    }

    private func drawEnemies(camera: CGFloat, gameLeft: CGFloat) {
        for enemy in enemies where enemy.alive {
            let x = gameLeft + (enemy.x - camera) * xScale
            if x < gameLeft - 20 || x > bounds.width + 20 { continue }
            if enemy.kind == .goomba {
                drawGoomba(at: NSPoint(x: x, y: 4))
            } else {
                drawKoopa(at: NSPoint(x: x, y: 4))
            }
        }
    }

    private func drawFlagAndCastle(camera: CGFloat, gameLeft: CGFloat) {
        let flagX = gameLeft + (3184 - camera) * xScale
        if flagX > gameLeft - 10 && flagX < bounds.width + 20 {
            NSColor.white.setFill()
            NSRect(x: flagX, y: 4, width: 1.3, height: 22).fill()
            NSColor(calibratedRed: 0.08, green: 0.67, blue: 0.15, alpha: 1).setFill()
            NSRect(x: flagX + 1.3, y: 20, width: 9, height: 5).fill()
            NSBezierPath(ovalIn: NSRect(x: flagX - 1.5, y: 25, width: 4, height: 4)).fill()
        }

        let castleX = gameLeft + (3264 - camera) * xScale
        if castleX > gameLeft - 40 && castleX < bounds.width + 60 {
            NSColor(calibratedRed: 0.70, green: 0.26, blue: 0.08, alpha: 1).setFill()
            NSRect(x: castleX, y: 4, width: 34, height: 15).fill()
            NSRect(x: castleX + 5, y: 19, width: 7, height: 5).fill()
            NSRect(x: castleX + 22, y: 19, width: 7, height: 5).fill()
            NSColor(calibratedRed: 0.20, green: 0.08, blue: 0.03, alpha: 1).setFill()
            NSRect(x: castleX + 14, y: 4, width: 7, height: 9).fill()
            NSRect(x: castleX + 6, y: 12, width: 4, height: 4).fill()
            NSRect(x: castleX + 24, y: 12, width: 4, height: 4).fill()
        }
    }

    private func drawQuestionBlock(at point: NSPoint, used: Bool) {
        let fill = used
            ? NSColor(calibratedRed: 0.53, green: 0.25, blue: 0.08, alpha: 1)
            : NSColor(calibratedRed: 0.96, green: 0.58, blue: 0.07, alpha: 1)
        fill.setFill()
        NSRect(x: point.x, y: point.y, width: 8.8, height: 3.1).fill()
        if !used {
            NSColor(calibratedRed: 0.45, green: 0.18, blue: 0.02, alpha: 1).setFill()
            NSRect(x: point.x + 4, y: point.y + 0.8, width: 1, height: 1.5).fill()
        }
    }

    private func drawBrickTile(at point: NSPoint) {
        NSColor(calibratedRed: 0.77, green: 0.31, blue: 0.09, alpha: 1).setFill()
        NSRect(x: point.x, y: point.y, width: 8.8, height: 3.1).fill()
        NSColor(calibratedRed: 0.38, green: 0.10, blue: 0.02, alpha: 1).setFill()
        NSRect(x: point.x + 4.1, y: point.y, width: 0.7, height: 3.1).fill()
        NSRect(x: point.x, y: point.y + 1.45, width: 8.8, height: 0.55).fill()
    }

    private func drawMario(at point: NSPoint) {
        let x = floor(point.x)
        let y = floor(point.y)
        let red = NSColor(calibratedRed: 0.89, green: 0.10, blue: 0.06, alpha: 1)
        let skin = NSColor(calibratedRed: 0.96, green: 0.67, blue: 0.41, alpha: 1)
        let brown = NSColor(calibratedRed: 0.28, green: 0.10, blue: 0.02, alpha: 1)

        red.setFill()
        NSRect(x: x + 1, y: y + 8, width: 7, height: 2).fill()
        NSRect(x: x + 3, y: y + 10, width: 5, height: 2).fill()
        skin.setFill()
        NSRect(x: x + 2, y: y + 5, width: 6, height: 3).fill()
        brown.setFill()
        NSRect(x: x + 2, y: y + 4, width: 2, height: 2).fill()
        NSRect(x: x + 6, y: y + 6, width: 2, height: 1).fill()
        red.setFill()
        NSRect(x: x + 2, y: y + 1, width: 6, height: 4).fill()
        brown.setFill()
        if facing > 0 {
            NSRect(x: x + 8, y: y + 5, width: 2, height: 2).fill()
        } else {
            NSRect(x: x, y: y + 5, width: 2, height: 2).fill()
        }
        NSRect(x: x + 1, y: y, width: 3, height: 1.5).fill()
        NSRect(x: x + 6, y: y, width: 3, height: 1.5).fill()
    }

    private func drawGoomba(at point: NSPoint) {
        NSColor(calibratedRed: 0.50, green: 0.20, blue: 0.05, alpha: 1).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: point.x, y: point.y + 2, width: 8, height: 6),
            xRadius: 3,
            yRadius: 3
        ).fill()
        NSColor(calibratedRed: 0.90, green: 0.63, blue: 0.30, alpha: 1).setFill()
        NSRect(x: point.x + 1, y: point.y, width: 2.5, height: 2.5).fill()
        NSRect(x: point.x + 4.5, y: point.y, width: 2.5, height: 2.5).fill()
        NSColor.black.setFill()
        NSRect(x: point.x + 2, y: point.y + 5, width: 1, height: 1.5).fill()
        NSRect(x: point.x + 5, y: point.y + 5, width: 1, height: 1.5).fill()
    }

    private func drawKoopa(at point: NSPoint) {
        NSColor(calibratedRed: 0.08, green: 0.63, blue: 0.13, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: point.x + 1, y: point.y + 3, width: 7, height: 8)).fill()
        NSColor(calibratedRed: 0.93, green: 0.73, blue: 0.39, alpha: 1).setFill()
        NSRect(x: point.x + 3, y: point.y + 10, width: 4, height: 3).fill()
        NSRect(x: point.x, y: point.y, width: 3, height: 2).fill()
        NSRect(x: point.x + 6, y: point.y, width: 3, height: 2).fill()
    }
}
