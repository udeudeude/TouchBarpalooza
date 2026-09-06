import AppKit

final class LemmingsView: NSView {
    private enum State {
        case waiting
        case falling
        case walking
        case entering
        case saved
    }

    private struct Walker {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var state: State = .waiting
        var spawnAt: TimeInterval
        var walkDistance: CGFloat = 0
        var stateTime: TimeInterval = 0
    }

    // The original walker uses an 8-frame cycle. These are newly drawn,
    // compact 8x10 homages to the 1991 silhouette rather than copied assets.
    private let walkerFrames: [[String]] = [
        [
            "........",
            "..GGGG..",
            ".GGSSS..",
            "..SS....",
            "..BBS...",
            ".SBBB...",
            "..BBB...",
            "..BB....",
            ".SS..S..",
            "..S..SS."
        ],
        [
            "........",
            "..GGGG..",
            ".GGSSS..",
            "..SSS...",
            "..BBB...",
            ".SBBB.S.",
            "..BBB...",
            "..BB....",
            ".S...SS.",
            "SS......"
        ],
        [
            "........",
            "..GGGG..",
            ".GGSSS..",
            "..SSS...",
            "..BBB...",
            "..BBBS..",
            ".SBBB...",
            "..B.....",
            ".S..SS..",
            "SS...S.."
        ],
        [
            "........",
            "..GGGG..",
            ".GGSSS..",
            "..SS....",
            "..BBB...",
            "..BBBS..",
            ".SBBB...",
            "...B....",
            ".SS..S..",
            ".....SS."
        ],
        [
            "........",
            "..GGGG..",
            ".GGSSS..",
            "..SS....",
            "..BBS...",
            "..BBB...",
            ".SBBB...",
            "...BB...",
            "..S..SS.",
            ".SS..S.."
        ],
        [
            "........",
            "..GGGG..",
            ".GGSSS..",
            "..SSS...",
            "..BBB...",
            ".SBBB...",
            "..BBBS..",
            "...BB...",
            "SS...S..",
            ".S..SS.."
        ],
        [
            "........",
            "..GGGG..",
            ".GGSSS..",
            "..SSS...",
            "..BBB...",
            "S.BBB...",
            "..BBBS..",
            "....B...",
            "SS..S...",
            ".S...SS."
        ],
        [
            "........",
            "..GGGG..",
            ".GGSSS..",
            "..SS....",
            ".SBBB...",
            "..BBB...",
            "..BBBS..",
            "...BB...",
            ".SS..S..",
            "..S..SS."
        ]
    ]

    private let pixel: CGFloat = 1.0
    private let walkSpeed: CGFloat = 24.0
    private let fallSpeed: CGFloat = 42.0
    private let spawnInterval: TimeInterval = 0.85
    private let lemmingCount = 8

    private var walkers: [Walker] = []
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var elapsed: TimeInterval = 0
    private var resetDelay: TimeInterval = 0

    override var isFlipped: Bool { true }

    private var spriteWidth: CGFloat { 8 * pixel }
    private var spriteHeight: CGFloat { 10 * pixel }
    private var groundY: CGFloat { bounds.height - 4 }
    private var walkY: CGFloat { groundY - spriteHeight }
    private var entranceX: CGFloat { 14 }
    private var entranceDropX: CGFloat { entranceX + 13 }
    private var exitX: CGFloat { max(120, bounds.width - 38) }
    private var exitDoorX: CGFloat { exitX + 12 }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        resetCycle()
        startAnimating()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        resetCycle()
        startAnimating()
    }

    deinit {
        timer?.invalidate()
    }

    private func resetCycle() {
        elapsed = 0
        resetDelay = 0
        walkers = (0..<lemmingCount).map { index in
            Walker(spawnAt: 1.0 + Double(index) * spawnInterval)
        }
    }

    private func startAnimating() {
        timer?.invalidate()
        lastTick = ProcessInfo.processInfo.systemUptime
        let newTimer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(now - lastTick, 0.1)
        lastTick = now
        elapsed += dt

        for index in walkers.indices {
            switch walkers[index].state {
            case .waiting:
                if elapsed >= walkers[index].spawnAt {
                    walkers[index].state = .falling
                    walkers[index].x = entranceDropX
                    walkers[index].y = 6
                    walkers[index].stateTime = 0
                }

            case .falling:
                walkers[index].y += fallSpeed * CGFloat(dt)
                if walkers[index].y >= walkY {
                    walkers[index].y = walkY
                    walkers[index].state = .walking
                    walkers[index].stateTime = 0
                }

            case .walking:
                let dx = walkSpeed * CGFloat(dt)
                walkers[index].x += dx
                walkers[index].walkDistance += dx

                // The trigger is inside the visible doorway. The lemming now
                // enters the exit instead of continuing behind the structure.
                if walkers[index].x + spriteWidth * 0.72 >= exitDoorX {
                    walkers[index].state = .entering
                    walkers[index].stateTime = 0
                }

            case .entering:
                walkers[index].stateTime += dt
                walkers[index].x += walkSpeed * 0.45 * CGFloat(dt)
                walkers[index].walkDistance += walkSpeed * 0.45 * CGFloat(dt)

                if walkers[index].stateTime >= 0.32 {
                    walkers[index].state = .saved
                }

            case .saved:
                break
            }
        }

        if walkers.allSatisfy({ $0.state == .saved }) {
            resetDelay += dt
            if resetDelay > 1.4 {
                resetCycle()
            }
        } else {
            resetDelay = 0
        }

        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Original Lemmings commonly used a very dark blue field rather than
        // neutral black behind the level graphics.
        NSColor(calibratedRed: 0.005, green: 0.01, blue: 0.11, alpha: 1).setFill()
        dirtyRect.fill()

        drawGround()
        drawEntrance()

        for walker in walkers where walker.state != .waiting && walker.state != .saved {
            drawWalker(walker)
        }

        // Draw the exit last. Its stonework masks an entering lemming, making
        // it visibly pass through the doorway rather than walk behind it.
        drawExit()
    }

    private func drawGround() {
        let dirtDark = NSColor(calibratedRed: 0.29, green: 0.10, blue: 0.04, alpha: 1)
        let dirt = NSColor(calibratedRed: 0.58, green: 0.24, blue: 0.06, alpha: 1)
        let dirtLight = NSColor(calibratedRed: 0.84, green: 0.43, blue: 0.08, alpha: 1)
        let grass = NSColor(calibratedRed: 0.10, green: 0.64, blue: 0.10, alpha: 1)
        let grassLight = NSColor(calibratedRed: 0.25, green: 0.86, blue: 0.14, alpha: 1)

        dirtDark.setFill()
        NSRect(x: 0, y: groundY, width: bounds.width, height: 4).fill()

        dirt.setFill()
        for x in stride(from: CGFloat(0), through: bounds.width, by: 7) {
            NSRect(x: x, y: groundY + 1, width: 4, height: 2).fill()
        }

        dirtLight.setFill()
        for x in stride(from: CGFloat(3), through: bounds.width, by: 13) {
            NSRect(x: x, y: groundY + 2, width: 2, height: 1).fill()
        }

        grass.setFill()
        NSRect(x: 0, y: groundY - 1, width: bounds.width, height: 2).fill()

        grassLight.setFill()
        for x in stride(from: CGFloat(1), through: bounds.width, by: 9) {
            NSRect(x: x, y: groundY - 2, width: 3, height: 1).fill()
        }
    }

    private func drawEntrance() {
        let woodDark = NSColor(calibratedRed: 0.30, green: 0.08, blue: 0.04, alpha: 1)
        let wood = NSColor(calibratedRed: 0.62, green: 0.18, blue: 0.07, alpha: 1)
        let rim = NSColor(calibratedRed: 0.88, green: 0.76, blue: 0.58, alpha: 1)
        let hatchBlue = NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.62, alpha: 1)
        let hatchLight = NSColor(calibratedRed: 0.30, green: 0.40, blue: 0.86, alpha: 1)

        let x = entranceX
        let y: CGFloat = 1

        // Brown suspension / side posts and pale metallic trim, matching the
        // recognisable dirt-set hatch silhouette.
        woodDark.setFill()
        NSRect(x: x, y: y + 3, width: 4, height: 8).fill()
        NSRect(x: x + 24, y: y + 3, width: 4, height: 8).fill()

        wood.setFill()
        NSRect(x: x + 1, y: y + 4, width: 2, height: 7).fill()
        NSRect(x: x + 25, y: y + 4, width: 2, height: 7).fill()

        rim.setFill()
        NSRect(x: x + 4, y: y + 2, width: 20, height: 2).fill()
        NSRect(x: x + 5, y: y + 4, width: 18, height: 1).fill()

        hatchBlue.setFill()
        NSRect(x: x + 6, y: y + 4, width: 16, height: 3).fill()
        hatchLight.setFill()
        NSRect(x: x + 8, y: y + 4, width: 12, height: 1).fill()

        // The classic entrance opens before the first lemming is released.
        let open = CGFloat(max(0, min(1, (elapsed - 0.25) / 0.45)))
        let center = x + 14
        let flapY = y + 7

        let left = NSBezierPath()
        left.move(to: NSPoint(x: center - 8, y: flapY))
        left.line(to: NSPoint(x: center, y: flapY))
        left.line(to: NSPoint(x: center - 1 - 3 * open, y: flapY + 1 + 5 * open))
        left.line(to: NSPoint(x: center - 8, y: flapY + 1))
        left.close()
        hatchBlue.setFill()
        left.fill()

        let right = NSBezierPath()
        right.move(to: NSPoint(x: center, y: flapY))
        right.line(to: NSPoint(x: center + 8, y: flapY))
        right.line(to: NSPoint(x: center + 8, y: flapY + 1))
        right.line(to: NSPoint(x: center + 1 + 3 * open, y: flapY + 1 + 5 * open))
        right.close()
        right.fill()
    }

    private func drawExit() {
        let x = exitX
        let baseY = groundY
        let stoneDark = NSColor(calibratedRed: 0.22, green: 0.24, blue: 0.28, alpha: 1)
        let stone = NSColor(calibratedRed: 0.43, green: 0.45, blue: 0.49, alpha: 1)
        let stoneLight = NSColor(calibratedRed: 0.67, green: 0.66, blue: 0.62, alpha: 1)
        let doorway = NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.26, alpha: 1)
        let blueGlow = NSColor(calibratedRed: 0.17, green: 0.28, blue: 0.66, alpha: 1)
        let flameRed = NSColor(calibratedRed: 0.95, green: 0.12, blue: 0.02, alpha: 1)
        let flameYellow = NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.05, alpha: 1)

        // Dark mouth of the exit.
        doorway.setFill()
        NSRect(x: x + 10, y: baseY - 10, width: 9, height: 10).fill()
        blueGlow.setFill()
        NSRect(x: x + 12, y: baseY - 9, width: 5, height: 2).fill()

        // Chunky grey stone arch, based on the dirt-set exit seen in the
        // original game. The doorway stays open at ground level.
        stoneDark.setFill()
        NSRect(x: x + 7, y: baseY - 12, width: 15, height: 3).fill()
        NSRect(x: x + 6, y: baseY - 9, width: 4, height: 9).fill()
        NSRect(x: x + 19, y: baseY - 9, width: 4, height: 9).fill()

        stone.setFill()
        NSRect(x: x + 9, y: baseY - 14, width: 11, height: 3).fill()
        NSRect(x: x + 7, y: baseY - 11, width: 4, height: 3).fill()
        NSRect(x: x + 18, y: baseY - 11, width: 4, height: 3).fill()
        NSRect(x: x + 7, y: baseY - 6, width: 3, height: 6).fill()
        NSRect(x: x + 20, y: baseY - 6, width: 3, height: 6).fill()

        stoneLight.setFill()
        NSRect(x: x + 11, y: baseY - 13, width: 7, height: 1).fill()
        NSRect(x: x + 8, y: baseY - 9, width: 2, height: 2).fill()
        NSRect(x: x + 20, y: baseY - 9, width: 2, height: 2).fill()

        // Twin flaming torches.
        stoneLight.setFill()
        NSRect(x: x + 2, y: baseY - 10, width: 1, height: 8).fill()
        NSRect(x: x + 27, y: baseY - 10, width: 1, height: 8).fill()

        let flicker = Int(elapsed * 9) % 2 == 0
        flameRed.setFill()
        NSRect(x: x + 1, y: baseY - 14, width: 3, height: 4).fill()
        NSRect(x: x + 26, y: baseY - 14, width: 3, height: 4).fill()
        flameYellow.setFill()
        NSRect(x: x + (flicker ? 2 : 1), y: baseY - 15, width: 1, height: 3).fill()
        NSRect(x: x + (flicker ? 27 : 28), y: baseY - 15, width: 1, height: 3).fill()
    }

    private func drawWalker(_ walker: Walker) {
        let frameIndex: Int
        switch walker.state {
        case .walking, .entering:
            // Tie animation to distance travelled so every lemming has the
            // same gait and speed while remaining naturally out of phase.
            frameIndex = Int(floor(walker.walkDistance / 2.4)) % walkerFrames.count
        case .falling:
            frameIndex = 1
        default:
            return
        }

        let frame = walkerFrames[frameIndex]
        let hair = NSColor(calibratedRed: 0.03, green: 0.82, blue: 0.10, alpha: 1)
        let skin = NSColor(calibratedRed: 0.98, green: 0.82, blue: 0.81, alpha: 1)
        let blue = NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.84, alpha: 1)

        for (rowIndex, row) in frame.enumerated() {
            for (columnIndex, symbol) in row.enumerated() {
                let color: NSColor?
                switch symbol {
                case "G": color = hair
                case "S": color = skin
                case "B": color = blue
                default: color = nil
                }

                guard let color else { continue }
                color.setFill()
                NSRect(
                    x: floor(walker.x) + CGFloat(columnIndex) * pixel,
                    y: floor(walker.y) + CGFloat(rowIndex) * pixel,
                    width: pixel,
                    height: pixel
                ).fill()
            }
        }
    }
}
