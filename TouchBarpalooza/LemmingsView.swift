import AppKit

final class LemmingsView: NSView {
    private enum WalkerState {
        case falling
        case walking
        case entering
        case done
    }

    private struct Walker {
        var x: CGFloat
        var y: CGFloat
        var phase: CGFloat
        var state: WalkerState
        var exitProgress: CGFloat = 0
    }

    // Classic Lemmings walk as a procession, not as individuals with different speeds.
    private let walkSpeed: CGFloat = 31
    private let fallSpeed: CGFloat = 68
    private let spawnInterval: TimeInterval = 0.82
    private let maxWalkers = 14
    private let spriteWidth: CGFloat = 14
    private let spriteHeight: CGFloat = 18

    private var walkers: [Walker] = []
    private var spawnClock: TimeInterval = 0
    private var doorOpenTimer: TimeInterval = 0
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        startAnimating()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        startAnimating()
    }

    deinit {
        timer?.invalidate()
    }

    private var groundY: CGFloat {
        bounds.height - 4
    }

    private var standingY: CGFloat {
        groundY - spriteHeight
    }

    private var trapdoorCenterX: CGFloat {
        min(72, max(42, bounds.width * 0.10))
    }

    private var exitFrameX: CGFloat {
        max(trapdoorCenterX + 120, bounds.width - 42)
    }

    private func startAnimating() {
        timer?.invalidate()
        lastTick = ProcessInfo.processInfo.systemUptime
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func spawnWalker() {
        walkers.append(
            Walker(
                x: trapdoorCenterX - spriteWidth / 2,
                y: -spriteHeight + 5,
                phase: 0,
                state: .falling
            )
        )
        doorOpenTimer = 0.34
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(now - lastTick, 0.1)
        lastTick = now

        spawnClock -= dt
        doorOpenTimer = max(0, doorOpenTimer - dt)

        if spawnClock <= 0, walkers.count < maxWalkers {
            spawnWalker()
            spawnClock += spawnInterval
        }

        for index in walkers.indices {
            walkers[index].phase += CGFloat(dt) * 9.5

            switch walkers[index].state {
            case .falling:
                walkers[index].y += fallSpeed * CGFloat(dt)
                if walkers[index].y >= standingY {
                    walkers[index].y = standingY
                    walkers[index].phase = 0
                    walkers[index].state = .walking
                }

            case .walking:
                // Every walker advances at exactly the same speed.
                walkers[index].x += walkSpeed * CGFloat(dt)

                // Enter the dark opening in the exit rather than simply wrapping.
                if walkers[index].x >= exitFrameX + 7 {
                    walkers[index].state = .entering
                    walkers[index].exitProgress = 0
                }

            case .entering:
                walkers[index].x += walkSpeed * 0.38 * CGFloat(dt)
                walkers[index].exitProgress += CGFloat(dt) / 0.42
                if walkers[index].exitProgress >= 1 {
                    walkers[index].state = .done
                }

            case .done:
                break
            }
        }

        walkers.removeAll { $0.state == .done }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.setFill()
        dirtyRect.fill()

        drawGround()
        drawTrapdoor()
        drawExitBack()

        for walker in walkers {
            drawWalker(walker)
        }

        // Draw the front of the exit last so lemmings visibly disappear into it.
        drawExitForeground()
    }

    private func drawGround() {
        let dirt = NSColor(calibratedRed: 0.24, green: 0.18, blue: 0.11, alpha: 1)
        let grass = NSColor(calibratedRed: 0.20, green: 0.62, blue: 0.17, alpha: 1)
        let highlight = NSColor(calibratedRed: 0.36, green: 0.28, blue: 0.16, alpha: 1)

        dirt.setFill()
        NSRect(x: 0, y: groundY, width: bounds.width, height: 4).fill()

        grass.setFill()
        for x in stride(from: CGFloat(0), through: bounds.width, by: 8) {
            NSRect(x: x, y: groundY, width: 5, height: 1).fill()
        }

        highlight.setFill()
        for x in stride(from: CGFloat(5), through: bounds.width, by: 19) {
            NSRect(x: x, y: groundY + 2, width: 5, height: 1).fill()
        }
    }

    private func drawTrapdoor() {
        let cx = trapdoorCenterX
        let metal = NSColor(calibratedWhite: 0.42, alpha: 1)
        let bright = NSColor(calibratedWhite: 0.68, alpha: 1)
        let dark = NSColor(calibratedWhite: 0.16, alpha: 1)
        let lamp = NSColor(calibratedRed: 0.32, green: 0.95, blue: 0.28, alpha: 1)

        // Black shaft behind the hatch.
        dark.setFill()
        NSRect(x: cx - 12, y: 0, width: 24, height: 6).fill()

        let open = doorOpenTimer > 0
        let gap: CGFloat = open ? 5 : 0

        metal.setFill()
        NSRect(x: cx - 13 - gap, y: 1, width: 12, height: 4).fill()
        NSRect(x: cx + 1 + gap, y: 1, width: 12, height: 4).fill()

        bright.setFill()
        NSRect(x: cx - 12 - gap, y: 1, width: 10, height: 1).fill()
        NSRect(x: cx + 2 + gap, y: 1, width: 10, height: 1).fill()

        lamp.setFill()
        NSRect(x: cx - 1, y: 0, width: 2, height: 2).fill()
    }

    private func drawExitBack() {
        let x = exitFrameX
        let top = groundY - 23
        let stone = NSColor(calibratedWhite: 0.33, alpha: 1)
        let stoneLight = NSColor(calibratedWhite: 0.53, alpha: 1)
        let doorway = NSColor(calibratedWhite: 0.03, alpha: 1)
        let glow = NSColor(calibratedRed: 0.24, green: 0.95, blue: 0.24, alpha: 1)

        stone.setFill()
        NSRect(x: x, y: top + 5, width: 30, height: 18).fill()
        NSRect(x: x + 4, y: top + 2, width: 22, height: 5).fill()
        NSRect(x: x + 8, y: top, width: 14, height: 3).fill()

        doorway.setFill()
        NSRect(x: x + 9, y: top + 8, width: 12, height: 15).fill()

        stoneLight.setFill()
        NSRect(x: x + 5, y: top + 4, width: 20, height: 1).fill()

        // Tiny green beacon gives the destination the familiar Lemmings readability.
        glow.setFill()
        NSRect(x: x + 13, y: top + 3, width: 4, height: 2).fill()
    }

    private func drawExitForeground() {
        let x = exitFrameX
        let top = groundY - 23
        let stone = NSColor(calibratedWhite: 0.29, alpha: 1)
        let edge = NSColor(calibratedWhite: 0.48, alpha: 1)

        stone.setFill()
        NSRect(x: x, y: top + 7, width: 8, height: 16).fill()
        NSRect(x: x + 22, y: top + 7, width: 8, height: 16).fill()
        NSRect(x: x + 5, y: top + 5, width: 20, height: 4).fill()

        edge.setFill()
        NSRect(x: x + 7, y: top + 8, width: 1, height: 14).fill()
        NSRect(x: x + 22, y: top + 8, width: 1, height: 14).fill()
    }

    private func drawWalker(_ walker: Walker) {
        let pixel: CGFloat = 2
        let originX = floor(walker.x)
        let originY = floor(walker.y)
        let frame = Int(floor(walker.phase)) & 3
        let alpha: CGFloat = walker.state == .entering ? max(0, 1 - walker.exitProgress) : 1

        func block(_ x: Int, _ y: Int, _ w: Int = 1, _ h: Int = 1, color: NSColor) {
            color.withAlphaComponent(alpha).setFill()
            NSRect(
                x: originX + CGFloat(x) * pixel,
                y: originY + CGFloat(y) * pixel,
                width: CGFloat(w) * pixel,
                height: CGFloat(h) * pixel
            ).fill()
        }

        let hair = NSColor(calibratedRed: 0.20, green: 0.98, blue: 0.18, alpha: 1)
        let skin = NSColor(calibratedRed: 0.98, green: 0.78, blue: 0.60, alpha: 1)
        let blue = NSColor(calibratedRed: 0.08, green: 0.32, blue: 0.96, alpha: 1)
        let shoe = NSColor(calibratedWhite: 0.94, alpha: 1)
        let eye = NSColor.black

        // A compact side-on silhouette: wild green hair, nose to the right,
        // blue overalls, pale limbs, white shoes. It is intentionally original
        // pixel art rather than copied game sprites.
        block(1, 0, 3, 1, color: hair)
        block(0, 1, 5, 1, color: hair)
        block(1, 2, 4, 1, color: hair)
        block(3, 2, 2, 2, color: skin)
        block(5, 3, 1, 1, color: skin)

        // Single-pixel eye inside the larger 2-point grid.
        eye.withAlphaComponent(alpha).setFill()
        NSRect(x: originX + 8, y: originY + 6, width: 1, height: 1).fill()

        block(2, 4, 3, 2, color: blue)
        block(2, 6, 3, 1, color: blue)

        if walker.state == .falling {
            // Arms and legs slightly splayed while dropping from the hatch.
            block(0, 4, 2, 1, color: skin)
            block(5, 4, 2, 1, color: skin)
            block(1, 7, 2, 1, color: skin)
            block(4, 7, 2, 1, color: skin)
            block(0, 8, 2, 1, color: shoe)
            block(5, 8, 2, 1, color: shoe)
            return
        }

        // Four-frame walk cycle. The body keeps moving continuously while arms
        // and legs alternate, producing a much more legible 1990s-style gait.
        switch frame {
        case 0:
            block(0, 5, 2, 1, color: skin)
            block(5, 4, 2, 1, color: skin)
            block(2, 7, 1, 1, color: skin)
            block(4, 7, 1, 1, color: skin)
            block(1, 8, 2, 1, color: shoe)
            block(4, 8, 2, 1, color: shoe)

        case 1:
            block(1, 5, 1, 2, color: skin)
            block(5, 5, 1, 2, color: skin)
            block(2, 7, 1, 2, color: skin)
            block(4, 7, 1, 1, color: skin)
            block(2, 8, 2, 1, color: shoe)
            block(5, 8, 2, 1, color: shoe)

        case 2:
            block(0, 4, 2, 1, color: skin)
            block(5, 5, 2, 1, color: skin)
            block(2, 7, 1, 1, color: skin)
            block(4, 7, 1, 1, color: skin)
            block(0, 8, 2, 1, color: shoe)
            block(4, 8, 2, 1, color: shoe)

        default:
            block(1, 5, 1, 2, color: skin)
            block(5, 5, 1, 2, color: skin)
            block(2, 7, 1, 1, color: skin)
            block(4, 7, 1, 2, color: skin)
            block(1, 8, 2, 1, color: shoe)
            block(4, 8, 2, 1, color: shoe)
        }
    }
}
