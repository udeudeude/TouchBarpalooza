import AppKit

private final class RetroKeyMonitor {
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

private func focusRetroKeyboard() {
    NSApp.activate(ignoringOtherApps: true)
    if let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first {
        window.makeKeyAndOrderFront(nil)
    }
}

// MARK: - DVD Video bounce

final class DVDBounceSaverView: NSView {
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var position = NSPoint(x: 18, y: 4)
    private var velocity = NSPoint(x: 86, y: 37)
    private var hue: CGFloat = 0.58
    private let logoSize = NSSize(width: 70, height: 22)

    override var intrinsicContentSize: NSSize { NSSize(width: 660, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.08, now - lastTick)
        lastTick = now

        position.x += velocity.x * CGFloat(dt)
        position.y += velocity.y * CGFloat(dt)

        let maxX = max(0, bounds.width - logoSize.width)
        let maxY = max(0, bounds.height - logoSize.height)
        var bounced = false

        if position.x <= 0 {
            position.x = 0
            velocity.x = abs(velocity.x)
            bounced = true
        } else if position.x >= maxX {
            position.x = maxX
            velocity.x = -abs(velocity.x)
            bounced = true
        }

        if position.y <= 0 {
            position.y = 0
            velocity.y = abs(velocity.y)
            bounced = true
        } else if position.y >= maxY {
            position.y = maxY
            velocity.y = -abs(velocity.y)
            bounced = true
        }

        if bounced {
            hue = (hue + 0.17).truncatingRemainder(dividingBy: 1.0)
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        let color = NSColor(calibratedHue: hue, saturation: 0.95, brightness: 1.0, alpha: 1)
        let rect = NSRect(origin: position, size: logoSize)
        let outline = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4)
        color.setStroke()
        outline.lineWidth = 1.5
        outline.stroke()

        let dvd = "DVD" as NSString
        dvd.draw(
            at: NSPoint(x: position.x + 7, y: position.y + 6),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .black),
                .foregroundColor: color
            ]
        )
        let video = "VIDEO" as NSString
        video.draw(
            at: NSPoint(x: position.x + 38, y: position.y + 8),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 6.5, weight: .bold),
                .foregroundColor: color
            ]
        )
    }
}

// MARK: - 3D Pipes homage, including the teapot Easter egg

final class PipesSaverView: NSView {
    private struct Pipe {
        var points: [NSPoint]
        var direction: Int
        var colorIndex: Int
        var progress: CGFloat
    }

    private var pipes: [Pipe] = []
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var elapsed: TimeInterval = 0
    private var nextTurn: TimeInterval = 0.7
    private var nextTeapotAt: TimeInterval = 10
    private var teapotUntil: TimeInterval = 0

    private let colors: [NSColor] = [
        NSColor(calibratedRed: 0.17, green: 0.95, blue: 0.28, alpha: 1),
        NSColor(calibratedRed: 0.16, green: 0.55, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.32, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.96, green: 0.80, blue: 0.12, alpha: 1),
        NSColor(calibratedRed: 0.72, green: 0.30, blue: 1.00, alpha: 1)
    ]

    override var intrinsicContentSize: NSSize { NSSize(width: 660, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        seedPipes()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func seedPipes() {
        pipes = [
            Pipe(points: [NSPoint(x: 30, y: 7), NSPoint(x: 130, y: 7)], direction: 0, colorIndex: 0, progress: 0),
            Pipe(points: [NSPoint(x: 210, y: 23), NSPoint(x: 300, y: 23)], direction: 0, colorIndex: 1, progress: 0),
            Pipe(points: [NSPoint(x: 390, y: 9), NSPoint(x: 470, y: 9)], direction: 0, colorIndex: 2, progress: 0),
            Pipe(points: [NSPoint(x: 535, y: 20), NSPoint(x: 620, y: 20)], direction: 0, colorIndex: 3, progress: 0)
        ]
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick)
        lastTick = now
        elapsed += dt

        for index in pipes.indices {
            pipes[index].progress += CGFloat(dt) * (22 + CGFloat(index) * 3)
            if pipes[index].progress >= 18 {
                pipes[index].progress = 0
                extendPipe(index)
            }
        }

        if elapsed >= nextTeapotAt {
            teapotUntil = elapsed + 1.7
            nextTeapotAt = elapsed + Double.random(in: 12...24)
        }

        needsDisplay = true
    }

    private func extendPipe(_ index: Int) {
        guard let last = pipes[index].points.last else { return }
        var direction = pipes[index].direction
        if Int.random(in: 0..<3) == 0 {
            direction = (direction + (Bool.random() ? 1 : 3)) % 4
        }

        let step: CGFloat = 28
        var next = last
        switch direction {
        case 0: next.x += step
        case 1: next.y += 10
        case 2: next.x -= step
        default: next.y -= 10
        }

        if next.x < 8 || next.x > bounds.width - 8 || next.y < 5 || next.y > bounds.height - 5 {
            direction = (direction + 2) % 4
            switch direction {
            case 0: next = NSPoint(x: last.x + step, y: last.y)
            case 1: next = NSPoint(x: last.x, y: last.y + 10)
            case 2: next = NSPoint(x: last.x - step, y: last.y)
            default: next = NSPoint(x: last.x, y: last.y - 10)
            }
        }

        pipes[index].direction = direction
        pipes[index].points.append(next)
        if pipes[index].points.count > 15 {
            pipes[index].points.removeFirst()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        for pipe in pipes {
            let color = colors[pipe.colorIndex % colors.count]
            for segment in 1..<pipe.points.count {
                drawPipeSegment(from: pipe.points[segment - 1], to: pipe.points[segment], color: color)
            }
        }

        if elapsed < teapotUntil {
            drawTeapot(center: NSPoint(x: bounds.midX, y: bounds.midY))
        }
    }

    private func drawPipeSegment(from a: NSPoint, to b: NSPoint, color: NSColor) {
        let shadow = NSBezierPath()
        shadow.move(to: NSPoint(x: a.x + 1.2, y: a.y - 1.2))
        shadow.line(to: NSPoint(x: b.x + 1.2, y: b.y - 1.2))
        shadow.lineWidth = 7
        NSColor(calibratedWhite: 0.08, alpha: 1).setStroke()
        shadow.stroke()

        let pipe = NSBezierPath()
        pipe.move(to: a)
        pipe.line(to: b)
        pipe.lineWidth = 5
        color.setStroke()
        pipe.stroke()

        let highlight = NSBezierPath()
        highlight.move(to: NSPoint(x: a.x - 0.8, y: a.y + 0.8))
        highlight.line(to: NSPoint(x: b.x - 0.8, y: b.y + 0.8))
        highlight.lineWidth = 1
        NSColor(calibratedWhite: 1, alpha: 0.65).setStroke()
        highlight.stroke()

        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: b.x - 3.5, y: b.y - 3.5, width: 7, height: 7)).fill()
    }

    private func drawTeapot(center: NSPoint) {
        let metal = NSColor(calibratedRed: 0.73, green: 0.78, blue: 0.84, alpha: 1)
        let shine = NSColor(calibratedWhite: 1, alpha: 0.85)
        metal.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 15, y: center.y - 7, width: 30, height: 15)).fill()
        NSRect(x: center.x - 5, y: center.y + 7, width: 10, height: 2).fill()
        NSRect(x: center.x - 2, y: center.y + 9, width: 4, height: 2).fill()

        let spout = NSBezierPath()
        spout.move(to: NSPoint(x: center.x + 10, y: center.y + 3))
        spout.line(to: NSPoint(x: center.x + 23, y: center.y + 7))
        spout.line(to: NSPoint(x: center.x + 16, y: center.y - 1))
        spout.close()
        metal.setFill()
        spout.fill()

        let handle = NSBezierPath()
        handle.appendArc(withCenter: NSPoint(x: center.x - 15, y: center.y + 1), radius: 8, startAngle: 70, endAngle: 290, clockwise: true)
        handle.lineWidth = 3
        metal.setStroke()
        handle.stroke()

        shine.setFill()
        NSRect(x: center.x - 7, y: center.y + 3, width: 7, height: 1.5).fill()
    }
}

// MARK: - Flying Toasters homage

final class FlyingToastersSaverView: NSView {
    private struct Flyer {
        var x: CGFloat
        var y: CGFloat
        var speed: CGFloat
        var phase: CGFloat
        var toast: Bool
    }

    private var flyers: [Flyer] = []
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var time: CGFloat = 0

    override var intrinsicContentSize: NSSize { NSSize(width: 660, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        for index in 0..<9 {
            flyers.append(Flyer(
                x: CGFloat(index) * 86 - 30,
                y: CGFloat(4 + (index * 7) % 18),
                speed: CGFloat(26 + (index * 5) % 23),
                phase: CGFloat(index) * 0.8,
                toast: index % 4 == 3
            ))
        }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick)
        lastTick = now
        time += CGFloat(dt)

        for index in flyers.indices {
            flyers[index].x += flyers[index].speed * CGFloat(dt)
            flyers[index].y += sin(time * 2.0 + flyers[index].phase) * CGFloat(dt) * 3
            if flyers[index].x > bounds.width + 30 {
                flyers[index].x = -40
                flyers[index].y = CGFloat(3 + Int.random(in: 0..<20))
            }
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.015, green: 0.02, blue: 0.06, alpha: 1).setFill()
        dirtyRect.fill()

        NSColor(calibratedWhite: 0.65, alpha: 0.6).setFill()
        for index in 0..<22 {
            let x = CGFloat((index * 83 + 17) % 659)
            let y = CGFloat((index * 11 + 3) % 29)
            NSRect(x: x, y: y, width: 1, height: 1).fill()
        }

        for flyer in flyers {
            if flyer.toast {
                drawToast(at: NSPoint(x: flyer.x, y: flyer.y))
            } else {
                drawToaster(at: NSPoint(x: flyer.x, y: flyer.y), phase: time + flyer.phase)
            }
        }
    }

    private func drawToaster(at point: NSPoint, phase: CGFloat) {
        let body = NSColor(calibratedRed: 0.74, green: 0.76, blue: 0.80, alpha: 1)
        let dark = NSColor(calibratedRed: 0.28, green: 0.30, blue: 0.34, alpha: 1)
        let wing = NSColor(calibratedWhite: 0.96, alpha: 1)
        body.setFill()
        NSBezierPath(roundedRect: NSRect(x: point.x, y: point.y, width: 20, height: 12), xRadius: 3, yRadius: 3).fill()
        dark.setFill()
        NSRect(x: point.x + 4, y: point.y + 9, width: 12, height: 2).fill()
        NSRect(x: point.x + 2, y: point.y - 2, width: 4, height: 2).fill()
        NSRect(x: point.x + 14, y: point.y - 2, width: 4, height: 2).fill()

        let flap = sin(phase * 7) * 3
        wing.setStroke()
        let left = NSBezierPath()
        left.move(to: NSPoint(x: point.x + 2, y: point.y + 8))
        left.line(to: NSPoint(x: point.x - 8, y: point.y + 9 + flap))
        left.line(to: NSPoint(x: point.x - 2, y: point.y + 4))
        left.lineWidth = 2.5
        left.stroke()

        let right = NSBezierPath()
        right.move(to: NSPoint(x: point.x + 18, y: point.y + 8))
        right.line(to: NSPoint(x: point.x + 28, y: point.y + 9 + flap))
        right.line(to: NSPoint(x: point.x + 22, y: point.y + 4))
        right.lineWidth = 2.5
        right.stroke()
    }

    private func drawToast(at point: NSPoint) {
        let crust = NSColor(calibratedRed: 0.58, green: 0.30, blue: 0.10, alpha: 1)
        let bread = NSColor(calibratedRed: 0.95, green: 0.77, blue: 0.42, alpha: 1)
        crust.setFill()
        NSBezierPath(roundedRect: NSRect(x: point.x, y: point.y, width: 12, height: 14), xRadius: 4, yRadius: 4).fill()
        bread.setFill()
        NSBezierPath(roundedRect: NSRect(x: point.x + 2, y: point.y + 2, width: 8, height: 10), xRadius: 3, yRadius: 3).fill()
    }
}

// MARK: - Touch Bar platformer inspired by 1980s side-scrollers

final class TouchBarPlatformerView: NSView {
    private let keyMonitor = RetroKeyMonitor()
    private var pressed = Set<UInt16>()
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var playerX: CGFloat = 35
    private var playerY: CGFloat = 0
    private var verticalVelocity: CGFloat = 0
    private var facing: CGFloat = 1
    private var coins = 0
    private var lives = 3
    private var invulnerable: TimeInterval = 0
    private var wonUntil: TimeInterval = 0

    private let controlsWidth: CGFloat = 146
    private let worldLength: CGFloat = 1400
    private let groundY: CGFloat = 4

    private let pits: [ClosedRange<CGFloat>] = [310...350, 785...825, 1120...1165]
    private let pipes: [(CGFloat, CGFloat)] = [(235, 11), (545, 15), (930, 12), (1260, 17)]
    private let bricks: [CGFloat] = [150, 176, 202, 425, 451, 675, 701, 1040, 1066]
    private let coinPositions: [NSPoint] = [
        NSPoint(x: 160, y: 18), NSPoint(x: 188, y: 18), NSPoint(x: 440, y: 18),
        NSPoint(x: 690, y: 18), NSPoint(x: 950, y: 21), NSPoint(x: 1060, y: 18),
        NSPoint(x: 1220, y: 15)
    ]
    private var collectedCoins = Set<Int>()

    override var intrinsicContentSize: NSSize { NSSize(width: 660, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        keyMonitor.handler = { [weak self] event, down in
            guard let self = self else { return }
            if down {
                self.pressed.insert(event.keyCode)
                if event.keyCode == 49 || event.keyCode == 126 || event.keyCode == 13 {
                    self.jump()
                }
            } else {
                self.pressed.remove(event.keyCode)
            }
        }
        buildControls()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func buildControls() {
        let left = NSButton(title: "◀", target: self, action: #selector(stepLeft))
        left.frame = NSRect(x: 2, y: 2, width: 28, height: 26)
        addSubview(left)

        let jumpButton = NSButton(title: "JUMP", target: self, action: #selector(jumpPressed))
        jumpButton.font = .systemFont(ofSize: 7)
        jumpButton.frame = NSRect(x: 32, y: 2, width: 44, height: 26)
        addSubview(jumpButton)

        let right = NSButton(title: "▶", target: self, action: #selector(stepRight))
        right.frame = NSRect(x: 78, y: 2, width: 28, height: 26)
        addSubview(right)

        let keys = NSButton(title: "KEYS", target: self, action: #selector(focusKeyboard))
        keys.font = .monospacedSystemFont(ofSize: 7, weight: .bold)
        keys.frame = NSRect(x: 108, y: 2, width: 36, height: 26)
        addSubview(keys)
    }

    @objc private func stepLeft() {
        playerX = max(0, playerX - 13)
        facing = -1
        needsDisplay = true
    }

    @objc private func stepRight() {
        playerX = min(worldLength, playerX + 13)
        facing = 1
        needsDisplay = true
    }

    @objc private func jumpPressed() { jump() }
    @objc private func focusKeyboard() { focusRetroKeyboard() }

    private func jump() {
        if playerY <= 0.1 {
            verticalVelocity = 102
        }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.08, now - lastTick)
        lastTick = now

        invulnerable = max(0, invulnerable - dt)
        wonUntil = max(0, wonUntil - dt)

        var direction: CGFloat = 0
        if pressed.contains(123) || pressed.contains(0) { direction -= 1 }
        if pressed.contains(124) || pressed.contains(2) { direction += 1 }
        if direction != 0 {
            facing = direction
            playerX += direction * 72 * CGFloat(dt)
        }
        playerX = max(0, min(worldLength, playerX))

        verticalVelocity -= 240 * CGFloat(dt)
        playerY += verticalVelocity * CGFloat(dt)
        if playerY <= 0 {
            playerY = 0
            if verticalVelocity < 0 { verticalVelocity = 0 }
        }

        detectWorldInteractions()
        needsDisplay = true
    }

    private func detectWorldInteractions() {
        if playerY <= 0.1 && pits.contains(where: { $0.contains(playerX) }) {
            loseLife()
            return
        }

        for (x, height) in pipes {
            if abs(playerX - x) < 8 && playerY < height - groundY {
                playerX += facing > 0 ? -3 : 3
            }
        }

        for index in coinPositions.indices where !collectedCoins.contains(index) {
            let coin = coinPositions[index]
            if abs(playerX - coin.x) < 11 && abs((groundY + playerY + 7) - coin.y) < 9 {
                collectedCoins.insert(index)
                coins += 1
            }
        }

        let enemyX = CGFloat(620) + sin(CGFloat(ProcessInfo.processInfo.systemUptime) * 1.8) * 35
        if invulnerable <= 0 && abs(playerX - enemyX) < 8 && playerY < 7 {
            loseLife()
        }

        if playerX >= worldLength - 18 {
            wonUntil = 1.4
            playerX = 35
            playerY = 0
            verticalVelocity = 0
            collectedCoins.removeAll()
        }
    }

    private func loseLife() {
        lives -= 1
        if lives <= 0 {
            lives = 3
            coins = 0
            collectedCoins.removeAll()
        }
        playerX = max(20, playerX - 80)
        playerY = 0
        verticalVelocity = 0
        invulnerable = 1.0
    }

    override func draw(_ dirtyRect: NSRect) {
        let sky = NSColor(calibratedRed: 0.28, green: 0.62, blue: 0.96, alpha: 1)
        sky.setFill()
        dirtyRect.fill()

        let gameLeft = controlsWidth
        let gameWidth = max(1, bounds.width - gameLeft)
        let camera = max(0, min(worldLength - gameWidth + 48, playerX - 52))

        NSColor(calibratedRed: 0.78, green: 0.39, blue: 0.12, alpha: 1).setFill()
        var groundX: CGFloat = 0
        while groundX < worldLength {
            let segment = groundX...(groundX + 24)
            let isPit = pits.contains(where: { $0.overlaps(segment) })
            if !isPit {
                let screenX = gameLeft + groundX - camera
                NSRect(x: screenX, y: 0, width: 24, height: groundY).fill()
            }
            groundX += 24
        }

        for x in bricks {
            let screenX = gameLeft + x - camera
            if screenX > gameLeft - 20 && screenX < bounds.width + 20 {
                drawBrick(at: NSPoint(x: screenX, y: 16))
            }
        }

        for (x, height) in pipes {
            let screenX = gameLeft + x - camera
            if screenX > gameLeft - 20 && screenX < bounds.width + 20 {
                drawPipe(at: NSPoint(x: screenX, y: groundY), height: height)
            }
        }

        for index in coinPositions.indices where !collectedCoins.contains(index) {
            let coin = coinPositions[index]
            let screenX = gameLeft + coin.x - camera
            if screenX > gameLeft && screenX < bounds.width {
                NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.08, alpha: 1).setFill()
                NSBezierPath(ovalIn: NSRect(x: screenX, y: coin.y, width: 4, height: 7)).fill()
            }
        }

        let enemyX = CGFloat(620) + sin(CGFloat(ProcessInfo.processInfo.systemUptime) * 1.8) * 35
        let enemyScreenX = gameLeft + enemyX - camera
        if enemyScreenX > gameLeft && enemyScreenX < bounds.width {
            drawEnemy(at: NSPoint(x: enemyScreenX, y: groundY))
        }

        let flagX = gameLeft + worldLength - camera
        if flagX > gameLeft && flagX < bounds.width + 10 {
            NSColor.white.setFill()
            NSRect(x: flagX, y: groundY, width: 1.5, height: 22).fill()
            NSColor(calibratedRed: 0.15, green: 0.85, blue: 0.25, alpha: 1).setFill()
            NSRect(x: flagX + 1.5, y: 19, width: 10, height: 6).fill()
        }

        let playerScreenX = gameLeft + playerX - camera
        if invulnerable <= 0 || Int(invulnerable * 12) % 2 == 0 {
            drawHero(at: NSPoint(x: playerScreenX, y: groundY + playerY))
        }

        let hud = wonUntil > 0 ? "COURSE CLEAR" : "C\(coins)  L\(lives)"
        (hud as NSString).draw(at: NSPoint(x: gameLeft + 4, y: 22), withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .bold),
            .foregroundColor: NSColor.white
        ])
    }

    private func drawHero(at point: NSPoint) {
        let red = NSColor(calibratedRed: 0.91, green: 0.10, blue: 0.08, alpha: 1)
        let skin = NSColor(calibratedRed: 0.96, green: 0.70, blue: 0.48, alpha: 1)
        let blue = NSColor(calibratedRed: 0.08, green: 0.28, blue: 0.82, alpha: 1)
        let dark = NSColor(calibratedRed: 0.20, green: 0.09, blue: 0.03, alpha: 1)
        let x = floor(point.x)
        let y = floor(point.y)
        red.setFill(); NSRect(x: x + 1, y: y + 9, width: 8, height: 3).fill(); NSRect(x: x + 3, y: y + 12, width: 5, height: 2).fill()
        skin.setFill(); NSRect(x: x + 2, y: y + 6, width: 6, height: 4).fill()
        blue.setFill(); NSRect(x: x + 2, y: y + 2, width: 6, height: 5).fill()
        dark.setFill()
        if facing > 0 {
            NSRect(x: x + 8, y: y + 7, width: 2, height: 2).fill()
        } else {
            NSRect(x: x, y: y + 7, width: 2, height: 2).fill()
        }
        NSRect(x: x + 1, y: y, width: 3, height: 2).fill()
        NSRect(x: x + 6, y: y, width: 3, height: 2).fill()
    }

    private func drawBrick(at point: NSPoint) {
        let brick = NSColor(calibratedRed: 0.78, green: 0.27, blue: 0.08, alpha: 1)
        let line = NSColor(calibratedRed: 0.35, green: 0.08, blue: 0.02, alpha: 1)
        brick.setFill(); NSRect(x: point.x, y: point.y, width: 18, height: 8).fill()
        line.setFill(); NSRect(x: point.x, y: point.y + 3.5, width: 18, height: 1).fill(); NSRect(x: point.x + 8, y: point.y, width: 1, height: 8).fill()
    }

    private func drawPipe(at point: NSPoint, height: CGFloat) {
        let green = NSColor(calibratedRed: 0.08, green: 0.68, blue: 0.16, alpha: 1)
        let dark = NSColor(calibratedRed: 0.02, green: 0.32, blue: 0.07, alpha: 1)
        green.setFill(); NSRect(x: point.x, y: point.y, width: 14, height: height).fill(); NSRect(x: point.x - 2, y: point.y + height - 4, width: 18, height: 5).fill()
        dark.setFill(); NSRect(x: point.x + 10, y: point.y, width: 2, height: height).fill()
    }

    private func drawEnemy(at point: NSPoint) {
        let brown = NSColor(calibratedRed: 0.52, green: 0.22, blue: 0.06, alpha: 1)
        let cream = NSColor(calibratedRed: 0.92, green: 0.72, blue: 0.42, alpha: 1)
        brown.setFill(); NSBezierPath(roundedRect: NSRect(x: point.x, y: point.y, width: 11, height: 8), xRadius: 4, yRadius: 4).fill()
        cream.setFill(); NSRect(x: point.x + 2, y: point.y + 2, width: 2, height: 2).fill(); NSRect(x: point.x + 7, y: point.y + 2, width: 2, height: 2).fill()
    }
}
