import AppKit

final class LemmingsView: NSView {
    enum Skill: Int, CaseIterable {
        case climber, floater, bomber, blocker, builder, basher, miner, digger

        var shortName: String {
            switch self {
            case .climber: return "CL"
            case .floater: return "FL"
            case .bomber: return "BO"
            case .blocker: return "BL"
            case .builder: return "BU"
            case .basher: return "BA"
            case .miner: return "MI"
            case .digger: return "DI"
            }
        }
    }

    enum GameMode {
        case interactive
        case demo
    }

    private enum State {
        case falling, walking, entering, blocking, building, bashing, mining, digging, bombing, saved, dead
    }

    private struct Walker {
        var x: CGFloat
        var y: CGFloat
        var direction: CGFloat = 1
        var state: State = .falling
        var walkDistance: CGFloat = 0
        var stateTime: TimeInterval = 0
        var isClimber = false
        var isFloater = false
        var fallDistance: CGFloat = 0
        var nukeDelay: TimeInterval? = nil
    }

    private let gameMode: GameMode

    private let walkerFrames: [[String]] = [
        ["........","..GGGG..",".GGSSS..","..SS....","..BBS...",".SBBB...","..BBB...","..BB....",".SS..S..","..S..SS."],
        ["........","..GGGG..",".GGSSS..","..SSS...","..BBB...",".SBBB.S.","..BBB...","..BB....",".S...SS.","SS......"],
        ["........","..GGGG..",".GGSSS..","..SSS...","..BBB...","..BBBS..",".SBBB...","..B.....",".S..SS..","SS...S.."],
        ["........","..GGGG..",".GGSSS..","..SS....","..BBB...","..BBBS..",".SBBB...","...B....",".SS..S..",".....SS."],
        ["........","..GGGG..",".GGSSS..","..SS....","..BBS...","..BBB...",".SBBB...","...BB...","..S..SS.",".SS..S.."],
        ["........","..GGGG..",".GGSSS..","..SSS...","..BBB...",".SBBB...","..BBBS..","...BB...","SS...S..",".S..SS.."],
        ["........","..GGGG..",".GGSSS..","..SSS...","..BBB...","S.BBB...","..BBBS..","....B...","SS..S...",".S...SS."],
        ["........","..GGGG..",".GGSSS..","..SS....",".SBBB...","..BBB...","..BBBS..","...BB...",".SS..S..","..S..SS."]
    ]

    private let pixel: CGFloat = 1.55
    private let walkSpeed: CGFloat = 25.0
    private let baseFallSpeed: CGFloat = 44.0
    private let lemmingCount = 12

    private var walkers: [Walker] = []
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var elapsed: TimeInterval = 0
    private var nextSpawnTime: TimeInterval = 0.8
    private var spawnedCount = 0
    private var savedCount = 0
    private var deadCount = 0
    private var selectedSkill: Skill = .builder
    private var paused = false
    private var releaseRate = 50

    private var bridgeProgress: CGFloat = 0
    private var wallBashProgress: CGFloat = 0
    private var trenchDug = false
    private var demoGapFailureObserved = false
    private var demoWallFailureObserved = false
    private var demoAssignedBuilder = false
    private var demoAssignedBasher = false

    override var isFlipped: Bool { true }

    private var spriteWidth: CGFloat { 8 * pixel }
    private var spriteHeight: CGFloat { 10 * pixel }
    private var groundY: CGFloat { bounds.height - 3 }
    private var walkY: CGFloat { groundY - spriteHeight }
    private var entranceX: CGFloat { 10 }
    private var entranceDropX: CGFloat { entranceX + 19 }
    private var exitX: CGFloat { max(150, bounds.width - 47) }
    private var exitDoorRect: NSRect { NSRect(x: exitX + 13, y: groundY - 15, width: 12, height: 15) }
    private var gapStart: CGFloat { max(145, bounds.width * 0.34) }
    private var gapEnd: CGFloat { gapStart + 38 }
    private var wallStart: CGFloat { max(gapEnd + 70, bounds.width * 0.62) }
    private var wallEnd: CGFloat { wallStart + 18 }

    init(frame frameRect: NSRect, mode: GameMode = .interactive) {
        self.gameMode = mode
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        self.gameMode = .interactive
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        if gameMode == .demo { releaseRate = 20 }
        startAnimating()
    }

    deinit { timer?.invalidate() }

    func selectSkill(_ skill: Skill) {
        selectedSkill = skill
        needsDisplay = true
    }

    func togglePause() {
        paused.toggle()
        needsDisplay = true
    }

    func adjustReleaseRate(by amount: Int) {
        releaseRate = min(99, max(1, releaseRate + amount))
        needsDisplay = true
    }

    func nuke() {
        var delay: TimeInterval = 0
        for index in walkers.indices where walkers[index].state != .saved && walkers[index].state != .dead {
            walkers[index].nukeDelay = delay
            delay += 0.18
        }
    }

    private var spawnInterval: TimeInterval {
        1.55 - (Double(releaseRate) / 99.0) * 1.15
    }

    private func demoMaySpawnNext() -> Bool {
        guard gameMode == .demo else { return true }
        if spawnedCount == 0 { return true }
        if !demoGapFailureObserved { return false }
        if !demoAssignedBuilder { return spawnedCount < 2 }
        if bridgeProgress < 1 { return false }
        return true
    }

    private func startAnimating() {
        lastTick = ProcessInfo.processInfo.systemUptime
        let newTimer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(now - lastTick, 0.1)
        lastTick = now
        guard !paused else { return }
        elapsed += dt

        if spawnedCount < lemmingCount && elapsed >= nextSpawnTime && demoMaySpawnNext() {
            walkers.append(Walker(x: entranceDropX, y: 6))
            spawnedCount += 1
            nextSpawnTime = elapsed + spawnInterval
        }

        for index in walkers.indices {
            if var delay = walkers[index].nukeDelay {
                delay -= dt
                walkers[index].nukeDelay = delay
                if delay <= 0 && walkers[index].state != .dead && walkers[index].state != .saved {
                    walkers[index].state = .bombing
                    walkers[index].stateTime = 0
                    walkers[index].nukeDelay = nil
                }
            }
            updateWalker(index, dt: dt)
        }

        if gameMode == .demo { runDemoAI() }
        needsDisplay = true
    }

    private func updateWalker(_ index: Int, dt: TimeInterval) {
        switch walkers[index].state {
        case .falling:
            let fallSpeed = walkers[index].isFloater ? baseFallSpeed * 0.34 : baseFallSpeed
            let dy = fallSpeed * CGFloat(dt)
            walkers[index].y += dy
            walkers[index].fallDistance += dy
            let surface = surfaceY(at: walkers[index].x + spriteWidth / 2)
            if walkers[index].y + spriteHeight >= surface {
                let hardFall = walkers[index].fallDistance > 22 && !walkers[index].isFloater
                walkers[index].y = surface - spriteHeight
                walkers[index].state = hardFall ? .dead : .walking
                walkers[index].stateTime = 0
                if hardFall { deadCount += 1 }
            }

        case .walking:
            let dx = walkers[index].direction * walkSpeed * CGFloat(dt)
            let nextX = walkers[index].x + dx
            let currentSurface = surfaceY(at: walkers[index].x + spriteWidth / 2)
            let nextSurface = surfaceY(at: nextX + spriteWidth / 2)

            if isBlockedByBlocker(index: index, nextX: nextX) {
                walkers[index].direction *= -1
                return
            }

            if nextSurface < currentSurface - 6 {
                if walkers[index].isClimber {
                    walkers[index].x = nextX
                    walkers[index].y = nextSurface - spriteHeight
                    walkers[index].walkDistance += abs(dx)
                } else {
                    if gameMode == .demo,
                       bridgeProgress >= 1,
                       wallBashProgress < 1,
                       walkers[index].direction > 0,
                       nextX + spriteWidth >= wallStart {
                        demoWallFailureObserved = true
                    }
                    walkers[index].direction *= -1
                }
                return
            }

            walkers[index].x = nextX
            walkers[index].walkDistance += abs(dx)

            if nextSurface > currentSurface + 5 {
                if gameMode == .demo,
                   bridgeProgress < 1,
                   walkers[index].direction > 0,
                   nextX + spriteWidth >= gapStart,
                   nextX <= gapEnd {
                    demoGapFailureObserved = true
                }
                walkers[index].state = .falling
                walkers[index].fallDistance = 0
                return
            }

            walkers[index].y = nextSurface - spriteHeight

            if walkers[index].direction > 0 && walkers[index].x + spriteWidth >= exitDoorRect.minX {
                walkers[index].state = .entering
                walkers[index].stateTime = 0
                walkers[index].x = exitDoorRect.minX - spriteWidth * 0.62
                walkers[index].y = groundY - spriteHeight
            }

        case .entering:
            walkers[index].stateTime += dt
            walkers[index].x += walkSpeed * 0.42 * CGFloat(dt)
            walkers[index].walkDistance += walkSpeed * 0.42 * CGFloat(dt)
            if walkers[index].stateTime >= 0.38 {
                walkers[index].state = .saved
                savedCount += 1
            }

        case .blocking:
            break

        case .building:
            walkers[index].stateTime += dt
            bridgeProgress = min(1, CGFloat(walkers[index].stateTime / 1.35))
            let span = gapEnd - gapStart
            walkers[index].x = gapStart - spriteWidth * 0.55 + span * bridgeProgress
            walkers[index].y = groundY - spriteHeight - sin(bridgeProgress * .pi) * 2
            walkers[index].walkDistance += walkSpeed * CGFloat(dt)
            if bridgeProgress >= 1 {
                walkers[index].x = gapEnd + 1
                walkers[index].y = walkY
                walkers[index].state = .walking
                walkers[index].stateTime = 0
            }

        case .bashing:
            walkers[index].stateTime += dt
            wallBashProgress = min(1, CGFloat(walkers[index].stateTime / 0.95))
            let span = wallEnd - wallStart
            walkers[index].x = wallStart - spriteWidth * 0.4 + span * wallBashProgress
            walkers[index].y = walkY
            walkers[index].walkDistance += walkSpeed * CGFloat(dt)
            if wallBashProgress >= 1 {
                walkers[index].x = wallEnd + 1
                walkers[index].state = .walking
                walkers[index].stateTime = 0
            }

        case .mining:
            walkers[index].stateTime += dt
            if walkers[index].stateTime > 0.75 {
                wallBashProgress = 1
                walkers[index].state = .walking
                walkers[index].stateTime = 0
            }

        case .digging:
            walkers[index].stateTime += dt
            if walkers[index].stateTime > 0.65 {
                trenchDug = true
                walkers[index].state = .falling
                walkers[index].fallDistance = 0
                walkers[index].stateTime = 0
            }

        case .bombing:
            walkers[index].stateTime += dt
            if walkers[index].stateTime > 1.6 {
                if abs(walkers[index].x - wallStart) < 35 { wallBashProgress = 1 }
                if walkers[index].x > gapStart - 20 && walkers[index].x < gapEnd + 20 { bridgeProgress = 1 }
                walkers[index].state = .dead
                deadCount += 1
            }

        case .saved, .dead:
            break
        }
    }

    private func isBlockedByBlocker(index: Int, nextX: CGFloat) -> Bool {
        for (otherIndex, other) in walkers.enumerated() where otherIndex != index && other.state == .blocking {
            if abs(nextX - other.x) < 11 { return true }
        }
        return false
    }

    private func surfaceY(at x: CGFloat) -> CGFloat {
        if x >= gapStart && x <= gapEnd {
            let builtTo = gapStart + (gapEnd - gapStart) * bridgeProgress
            return x <= builtTo ? groundY : bounds.height + 20
        }

        let clearedTo = wallStart + (wallEnd - wallStart) * wallBashProgress
        if x >= clearedTo && x <= wallEnd && wallBashProgress < 1 {
            return groundY - 11
        }

        if trenchDug && x >= gapStart - 75 && x <= gapStart - 52 {
            return bounds.height + 14
        }
        return groundY
    }

    private func runDemoAI() {
        if demoGapFailureObserved,
           !demoAssignedBuilder,
           let index = walkers.indices.first(where: {
               walkers[$0].state == .walking && walkers[$0].direction > 0 && walkers[$0].x > gapStart - 24
           }) {
            apply(.builder, to: index)
            demoAssignedBuilder = true
        }

        if bridgeProgress >= 1,
           demoWallFailureObserved,
           !demoAssignedBasher,
           let index = walkers.indices.first(where: {
               walkers[$0].state == .walking && walkers[$0].direction > 0 && walkers[$0].x > wallStart - 24
           }) {
            apply(.basher, to: index)
            demoAssignedBasher = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard gameMode == .interactive else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard let index = walkers.indices
            .filter({ walkers[$0].state != .saved && walkers[$0].state != .dead })
            .min(by: { abs(walkers[$0].x - point.x) < abs(walkers[$1].x - point.x) }),
              abs(walkers[index].x + spriteWidth / 2 - point.x) < 22 else { return }
        apply(selectedSkill, to: index)
    }

    private func apply(_ skill: Skill, to index: Int) {
        guard walkers.indices.contains(index) else { return }
        switch skill {
        case .climber:
            walkers[index].isClimber = true
        case .floater:
            walkers[index].isFloater = true
        case .bomber:
            walkers[index].state = .bombing
            walkers[index].stateTime = 0
        case .blocker:
            walkers[index].state = .blocking
        case .builder:
            walkers[index].state = .building
            walkers[index].stateTime = 0
        case .basher:
            walkers[index].state = .bashing
            walkers[index].stateTime = 0
        case .miner:
            walkers[index].state = .mining
            walkers[index].stateTime = 0
        case .digger:
            walkers[index].state = .digging
            walkers[index].stateTime = 0
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor(calibratedRed: 0.005, green: 0.01, blue: 0.11, alpha: 1).setFill()
        dirtyRect.fill()

        drawTerrain()
        drawEntrance()
        drawHUD()
        drawExitBackground()

        for walker in walkers where walker.state != .saved && walker.state != .dead {
            if walker.state == .entering {
                drawEnteringWalker(walker)
            } else {
                drawWalker(walker)
            }
        }

        drawExitForeground()
    }

    private func drawHUD() {
        let text = "OUT \(spawnedCount - savedCount - deadCount)  IN \(savedCount)  RR \(releaseRate)\(paused ? "  PAUSE" : "")\(gameMode == .demo ? "  DEMO" : "")"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 6.5, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.78, alpha: 1)
        ]
        text.draw(at: NSPoint(x: 84, y: 1), withAttributes: attrs)
    }

    private func drawTerrain() {
        let dirtDark = NSColor(calibratedRed: 0.29, green: 0.10, blue: 0.04, alpha: 1)
        let dirt = NSColor(calibratedRed: 0.58, green: 0.24, blue: 0.06, alpha: 1)
        let grass = NSColor(calibratedRed: 0.10, green: 0.64, blue: 0.10, alpha: 1)

        for x in stride(from: CGFloat(0), through: bounds.width, by: 2) {
            let top = surfaceY(at: x)
            if top <= bounds.height {
                dirtDark.setFill()
                NSRect(x: x, y: top, width: 2, height: max(0, bounds.height - top)).fill()
                dirt.setFill()
                NSRect(x: x, y: top + 1, width: 1, height: max(0, bounds.height - top - 1)).fill()
                grass.setFill()
                NSRect(x: x, y: top - 1, width: 2, height: 1).fill()
            }
        }

        if bridgeProgress > 0 {
            let bridge = NSColor(calibratedRed: 0.78, green: 0.52, blue: 0.16, alpha: 1)
            let builtWidth = (gapEnd - gapStart) * bridgeProgress
            bridge.setFill()
            let stepCount = max(1, Int(bridgeProgress * 8))
            for step in 0..<stepCount {
                let w = (gapEnd - gapStart) / 8
                NSRect(x: gapStart + CGFloat(step) * w, y: groundY - 2 - CGFloat(step % 2), width: w + 1, height: 2).fill()
            }
            if builtWidth < 1 { _ = builtWidth }
        }

        if wallBashProgress < 1 {
            let remainingStart = wallStart + (wallEnd - wallStart) * wallBashProgress
            let wall = NSColor(calibratedRed: 0.43, green: 0.17, blue: 0.05, alpha: 1)
            let wallLight = NSColor(calibratedRed: 0.72, green: 0.34, blue: 0.08, alpha: 1)
            wall.setFill()
            NSRect(x: remainingStart, y: groundY - 11, width: max(0, wallEnd - remainingStart), height: 11).fill()
            wallLight.setFill()
            NSRect(x: remainingStart, y: groundY - 11, width: max(0, wallEnd - remainingStart), height: 2).fill()
        }
    }

    private func drawEntrance() {
        let x = entranceX
        let y: CGFloat = 1
        let wood = NSColor(calibratedRed: 0.58, green: 0.18, blue: 0.07, alpha: 1)
        let rim = NSColor(calibratedRed: 0.87, green: 0.75, blue: 0.56, alpha: 1)
        let blue = NSColor(calibratedRed: 0.18, green: 0.24, blue: 0.68, alpha: 1)
        wood.setFill()
        NSRect(x: x, y: y + 3, width: 5, height: 10).fill()
        NSRect(x: x + 31, y: y + 3, width: 5, height: 10).fill()
        rim.setFill()
        NSRect(x: x + 5, y: y + 2, width: 26, height: 2).fill()
        blue.setFill()
        NSRect(x: x + 7, y: y + 4, width: 22, height: 4).fill()
        let open = CGFloat(max(0, min(1, (elapsed - 0.25) / 0.45)))
        let center = x + 18
        NSColor.black.setFill()
        NSRect(x: center - 3 * open, y: y + 7, width: 6 * open, height: 5).fill()
    }

    private func drawExitBackground() {
        let doorway = NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.24, alpha: 1)
        doorway.setFill()
        exitDoorRect.fill()
        NSColor(calibratedRed: 0.12, green: 0.22, blue: 0.62, alpha: 1).setFill()
        NSRect(x: exitDoorRect.minX + 2, y: exitDoorRect.minY + 2, width: exitDoorRect.width - 4, height: 2).fill()
    }

    private func drawExitForeground() {
        let x = exitX
        let base = groundY
        let stoneDark = NSColor(calibratedRed: 0.22, green: 0.24, blue: 0.28, alpha: 1)
        let stone = NSColor(calibratedRed: 0.48, green: 0.49, blue: 0.50, alpha: 1)

        stoneDark.setFill()
        NSRect(x: x + 9, y: base - 19, width: 20, height: 4).fill()
        NSRect(x: x + 7, y: base - 15, width: 6, height: 15).fill()
        NSRect(x: x + 25, y: base - 15, width: 6, height: 15).fill()
        stone.setFill()
        NSRect(x: x + 12, y: base - 21, width: 14, height: 3).fill()
        NSRect(x: x + 9, y: base - 17, width: 5, height: 4).fill()
        NSRect(x: x + 24, y: base - 17, width: 5, height: 4).fill()

        drawTorch(at: x + 4, base: base, phase: 0)
        drawTorch(at: x + 33, base: base, phase: .pi)
    }

    private func drawTorch(at x: CGFloat, base: CGFloat, phase: CGFloat) {
        let pulse = sin(CGFloat(elapsed) * 17 + phase)
        let height: CGFloat = pulse > 0 ? 6 : 4
        let red = NSColor(calibratedRed: 0.95, green: 0.10, blue: 0.02, alpha: 1)
        let yellow = NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.05, alpha: 1)
        let holder = NSColor(calibratedRed: 0.32, green: 0.22, blue: 0.12, alpha: 1)
        holder.setFill(); NSRect(x: x, y: base - 11, width: 2, height: 4).fill()
        red.setFill(); NSRect(x: x - 1, y: base - 11 - height, width: 4, height: height).fill()
        yellow.setFill(); NSRect(x: x, y: base - 10 - height, width: 2, height: max(2, height - 2)).fill()
    }

    private func drawEnteringWalker(_ walker: Walker) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: exitDoorRect.insetBy(dx: 1, dy: 0)).addClip()
        drawWalker(walker)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawWalker(_ walker: Walker) {
        let frameIndex = min(7, Int(floor(walker.walkDistance / 2.3)) % 8)
        let frame = walkerFrames[frameIndex]
        let originX = floor(walker.x)
        let originY = floor(walker.y)

        let hair = NSColor(calibratedRed: 0.18, green: 0.98, blue: 0.18, alpha: 1)
        let skin = NSColor(calibratedRed: 0.98, green: 0.76, blue: 0.58, alpha: 1)
        let blue = NSColor(calibratedRed: 0.10, green: 0.35, blue: 0.98, alpha: 1)

        for (row, line) in frame.enumerated() {
            for (column, character) in line.enumerated() {
                let color: NSColor?
                switch character {
                case "G": color = hair
                case "S": color = skin
                case "B": color = blue
                default: color = nil
                }
                guard let color else { continue }
                color.setFill()
                let sourceX = walker.direction > 0 ? column : 7 - column
                NSRect(
                    x: originX + CGFloat(sourceX) * pixel,
                    y: originY + CGFloat(row) * pixel,
                    width: pixel + 0.2,
                    height: pixel + 0.2
                ).fill()
            }
        }

        if walker.state == .bombing {
            let remaining = max(0, 1.6 - walker.stateTime)
            let text = String(Int(ceil(remaining)))
            text.draw(at: NSPoint(x: walker.x + 2, y: max(0, walker.y - 7)), withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .bold),
                .foregroundColor: NSColor.white
            ])
        }
    }
}
