import AppKit

final class LemmingsView: NSView {
    enum Skill: Int, CaseIterable {
        case climber, floater, bomber, blocker, builder, basher, miner, digger

        var shortName: String {
            switch self {
            case .climber: return "CLIMB"
            case .floater: return "FLOAT"
            case .bomber: return "BOMB"
            case .blocker: return "BLOCK"
            case .builder: return "BUILD"
            case .basher: return "BASH"
            case .miner: return "MINE"
            case .digger: return "DIG"
            }
        }
    }

    enum GameMode {
        case interactive
        case demo
    }

    private enum State {
        case falling, walking, entering, blocking, building, bashing, mining, digging, bombing, exploding, saved, dead
    }

    private enum BuildKind {
        case gap, wall
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
        var nukeDelay: TimeInterval?
        var buildKind: BuildKind?
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
    private let walkSpeed: CGFloat = 25
    private let baseFallSpeed: CGFloat = 44
    private let lemmingCount = 12
    private let bombCountdown: TimeInterval = 5.0

    private var walkers: [Walker] = []
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var elapsed: TimeInterval = 0
    private var nextSpawnTime: TimeInterval = 0.55
    private var spawnedCount = 0
    private var savedCount = 0
    private var deadCount = 0
    private var selectedSkill: Skill = .builder
    private var paused = false
    private var releaseRate = 50

    private let builderBrickCount = 12
    private let builderBrickDuration: TimeInterval = 0.18
    private var bridgeSteps = 0
    private var wallRampSteps = 0
    private var wallBashProgress: CGFloat = 0
    private var trenchDug = false

    private var demoGapFailureSeen = false
    private var demoAssignedBuilder = false
    private var demoWallFailureSeen = false
    private var demoAssignedBasher = false
    private var demoNuked = false

    private var walkerTouchButtons: [NSButton] = []
    private var demoNukeButton: NSButton?

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize {
        NSSize(width: gameMode == .interactive ? 410 : 700, height: 30)
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var spriteWidth: CGFloat { 8 * pixel }
    private var spriteHeight: CGFloat { 10 * pixel }
    private var groundY: CGFloat { bounds.height - 3 }
    private var entranceX: CGFloat { 7 }
    private var entranceDropX: CGFloat { entranceX + 19 }

    private var gapStart: CGFloat { max(118, bounds.width * 0.31) }
    private var gapEnd: CGFloat { gapStart + 52 }
    private var gapStepWidth: CGFloat { (gapEnd - gapStart) / CGFloat(builderBrickCount) }
    private let gapStepRise: CGFloat = 0.72

    private var wallStart: CGFloat { max(gapEnd + 56, bounds.width * 0.61) }
    private var wallEnd: CGFloat { wallStart + 20 }
    private let wallHeight: CGFloat = 11
    private var wallRampStart: CGFloat { wallStart - 30 }
    private var wallRampEnd: CGFloat { wallEnd + 3 }
    private var wallRampStepWidth: CGFloat { (wallRampEnd - wallRampStart) / 8 }
    private let wallRampRise: CGFloat = 1.55

    private var exitX: CGFloat { max(wallEnd + 55, bounds.width - 48) }
    private var exitDoorRect: NSRect {
        NSRect(x: exitX + 13, y: groundY - 15, width: 12, height: 15)
    }

    init(frame frameRect: NSRect, mode: GameMode = .interactive) {
        gameMode = mode
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        gameMode = .interactive
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        if gameMode == .demo { releaseRate = 45 }
        buildTouchTargets()
        startAnimating()
    }

    private func buildTouchTargets() {
        if gameMode == .demo {
            let button = NSButton(title: "", target: self, action: #selector(demoPressed))
            button.isBordered = false
            button.focusRingType = .none
            button.alphaValue = 0.01
            button.frame = bounds
            button.autoresizingMask = [.width, .height]
            addSubview(button)
            demoNukeButton = button
        } else {
            for index in 0..<lemmingCount {
                let button = NSButton(title: "", target: self, action: #selector(lemmingPressed(_:)))
                button.isBordered = false
                button.focusRingType = .none
                button.alphaValue = 0.01
                button.tag = index
                button.isHidden = true
                addSubview(button)
                walkerTouchButtons.append(button)
            }
        }
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
        guard !demoNuked || gameMode == .interactive else { return }
        if gameMode == .demo { demoNuked = true }
        var delay: TimeInterval = 0
        for index in walkers.indices where walkers[index].state != .saved && walkers[index].state != .dead && walkers[index].state != .exploding {
            walkers[index].nukeDelay = delay
            delay += 0.20
        }
        needsDisplay = true
    }

    @objc private func demoPressed() {
        nuke()
    }

    @objc private func lemmingPressed(_ sender: NSButton) {
        let index = sender.tag
        guard walkers.indices.contains(index),
              walkers[index].state != .saved,
              walkers[index].state != .dead,
              walkers[index].state != .exploding else { return }
        apply(selectedSkill, to: index)
    }

    private var spawnInterval: TimeInterval {
        1.50 - (Double(releaseRate) / 99.0) * 1.05
    }

    private func startAnimating() {
        lastTick = ProcessInfo.processInfo.systemUptime
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick)
        lastTick = now
        guard !paused else { return }
        elapsed += dt

        if spawnedCount < lemmingCount,
           !(gameMode == .demo && demoNuked),
           elapsed >= nextSpawnTime {
            walkers.append(Walker(x: entranceDropX, y: 6))
            spawnedCount += 1
            nextSpawnTime = elapsed + spawnInterval
        }

        for index in walkers.indices {
            if var delay = walkers[index].nukeDelay {
                delay -= dt
                walkers[index].nukeDelay = delay
                if delay <= 0 && walkers[index].state != .dead && walkers[index].state != .saved && walkers[index].state != .exploding {
                    walkers[index].state = .bombing
                    walkers[index].stateTime = 0
                    walkers[index].nukeDelay = nil
                }
            }
            updateWalker(index, dt: dt)
        }

        if gameMode == .demo && !demoNuked { runDemoAI() }
        updateWalkerTouchTargets()
        needsDisplay = true
    }

    private func updateWalkerTouchTargets() {
        guard gameMode == .interactive else { return }
        for (index, button) in walkerTouchButtons.enumerated() {
            guard walkers.indices.contains(index) else {
                button.isHidden = true
                continue
            }
            let walker = walkers[index]
            let active = walker.state != .saved && walker.state != .dead && walker.state != .exploding
            button.isHidden = !active
            if active {
                button.frame = NSRect(
                    x: max(0, walker.x - 6),
                    y: max(0, walker.y - 4),
                    width: spriteWidth + 12,
                    height: min(bounds.height, spriteHeight + 8)
                )
            }
        }
    }

    private func updateWalker(_ index: Int, dt: TimeInterval) {
        switch walkers[index].state {
        case .falling:
            let speed = walkers[index].isFloater ? baseFallSpeed * 0.34 : baseFallSpeed
            let dy = speed * CGFloat(dt)
            walkers[index].y += dy
            walkers[index].fallDistance += dy

            if walkers[index].y > bounds.height + 7 {
                walkers[index].state = .dead
                deadCount += 1
                if gameMode == .demo && !demoGapFailureSeen && walkers[index].x >= gapStart - 8 && walkers[index].x <= gapEnd + 8 {
                    demoGapFailureSeen = true
                }
                return
            }

            let surface = surfaceY(at: walkers[index].x + spriteWidth / 2)
            if surface <= bounds.height + 2 && walkers[index].y + spriteHeight >= surface {
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
                    if gameMode == .demo && nextX >= wallStart - 4 && nextX <= wallEnd + 4 {
                        demoWallFailureSeen = true
                    }
                    walkers[index].direction *= -1
                }
                return
            }

            walkers[index].x = nextX
            walkers[index].walkDistance += abs(dx)

            if nextSurface > currentSurface + 5 {
                walkers[index].state = .falling
                walkers[index].fallDistance = 0
                return
            }

            walkers[index].y = nextSurface - spriteHeight

            if walkers[index].direction > 0,
               walkers[index].x + spriteWidth * 0.56 >= exitDoorRect.minX + 1 {
                walkers[index].state = .entering
                walkers[index].stateTime = 0
            }

        case .entering:
            walkers[index].stateTime += dt
            walkers[index].x += walkSpeed * 0.34 * CGFloat(dt)
            walkers[index].walkDistance += walkSpeed * 0.34 * CGFloat(dt)
            if walkers[index].stateTime >= 0.48 {
                walkers[index].state = .saved
                savedCount += 1
            }

        case .blocking:
            break

        case .building:
            walkers[index].stateTime += dt
            let kind = walkers[index].buildKind ?? .gap
            let total = kind == .gap ? builderBrickCount : 8
            let completed = min(total, Int(walkers[index].stateTime / builderBrickDuration))

            if kind == .gap {
                bridgeSteps = max(bridgeSteps, completed)
                walkers[index].x = gapStart - spriteWidth * 0.45 + CGFloat(completed) * gapStepWidth
                walkers[index].y = groundY - spriteHeight - CGFloat(completed) * gapStepRise
            } else {
                wallRampSteps = max(wallRampSteps, completed)
                walkers[index].x = wallRampStart - spriteWidth * 0.35 + CGFloat(completed) * wallRampStepWidth
                walkers[index].y = groundY - spriteHeight - CGFloat(completed) * wallRampRise
            }
            walkers[index].walkDistance += walkSpeed * 0.28 * CGFloat(dt)

            if completed >= total {
                walkers[index].state = .walking
                walkers[index].stateTime = 0
                if kind == .gap {
                    walkers[index].x = gapEnd + 1
                    walkers[index].y = groundY - spriteHeight - CGFloat(builderBrickCount) * gapStepRise
                } else {
                    walkers[index].x = wallRampEnd + 1
                    walkers[index].y = groundY - spriteHeight - CGFloat(8) * wallRampRise
                }
                walkers[index].buildKind = nil
            }

        case .bashing:
            walkers[index].stateTime += dt
            wallBashProgress = min(1, CGFloat(walkers[index].stateTime / 1.15))
            let span = wallEnd - wallStart
            walkers[index].x = wallStart - spriteWidth * 0.35 + span * wallBashProgress
            walkers[index].y = groundY - spriteHeight
            walkers[index].walkDistance += walkSpeed * CGFloat(dt)
            if wallBashProgress >= 1 {
                walkers[index].x = wallEnd + 1
                walkers[index].state = .walking
                walkers[index].stateTime = 0
            }

        case .mining:
            walkers[index].stateTime += dt
            wallBashProgress = min(1, CGFloat(walkers[index].stateTime / 1.25))
            walkers[index].x += walkSpeed * 0.32 * CGFloat(dt)
            walkers[index].y += 3 * CGFloat(dt)
            if wallBashProgress >= 1 {
                walkers[index].x = wallEnd + 1
                walkers[index].y = groundY - spriteHeight
                walkers[index].state = .walking
                walkers[index].stateTime = 0
            }

        case .digging:
            walkers[index].stateTime += dt
            if walkers[index].x >= wallStart - 10 && walkers[index].x <= wallEnd + 10 {
                wallBashProgress = min(1, CGFloat(walkers[index].stateTime / 1.15))
                if wallBashProgress >= 1 {
                    walkers[index].x = wallEnd + 1
                    walkers[index].y = groundY - spriteHeight
                    walkers[index].state = .walking
                    walkers[index].stateTime = 0
                }
            } else if walkers[index].stateTime > 0.65 {
                trenchDug = true
                walkers[index].state = .falling
                walkers[index].fallDistance = 0
                walkers[index].stateTime = 0
            }

        case .bombing:
            walkers[index].stateTime += dt
            if walkers[index].stateTime >= bombCountdown {
                if abs(walkers[index].x - wallStart) < 34 { wallBashProgress = 1 }
                walkers[index].state = .exploding
                walkers[index].stateTime = 0
            }

        case .exploding:
            walkers[index].stateTime += dt
            if walkers[index].stateTime >= 0.34 {
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
            let step = max(0, min(builderBrickCount - 1, Int((x - gapStart) / max(0.1, gapStepWidth))))
            if step < bridgeSteps {
                return groundY - CGFloat(step + 1) * gapStepRise
            }
            return bounds.height + 30
        }

        if wallRampSteps > 0 && x >= wallRampStart && x <= wallRampEnd {
            let step = max(0, min(7, Int((x - wallRampStart) / max(0.1, wallRampStepWidth))))
            if step < wallRampSteps {
                return groundY - CGFloat(step + 1) * wallRampRise
            }
        }

        let clearedTo = wallStart + (wallEnd - wallStart) * wallBashProgress
        if x >= clearedTo && x <= wallEnd && wallBashProgress < 1 {
            return groundY - wallHeight
        }

        if trenchDug && x >= gapStart - 72 && x <= gapStart - 52 {
            return bounds.height + 18
        }
        return groundY
    }

    private func runDemoAI() {
        if demoGapFailureSeen && !demoAssignedBuilder,
           let index = walkers.indices.first(where: {
               walkers[$0].state == .walking && walkers[$0].direction > 0 && walkers[$0].x > gapStart - 26
           }) {
            apply(.builder, to: index)
            demoAssignedBuilder = true
        }

        if bridgeSteps >= builderBrickCount && demoWallFailureSeen && !demoAssignedBasher,
           let index = walkers.indices.first(where: {
               walkers[$0].state == .walking && walkers[$0].direction > 0 && walkers[$0].x > wallStart - 25
           }) {
            apply(.basher, to: index)
            demoAssignedBasher = true
        }
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
            if walkers[index].x > wallRampStart - 18 && walkers[index].x < wallEnd + 5 {
                walkers[index].buildKind = .wall
            } else {
                walkers[index].buildKind = .gap
            }
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
        NSColor(calibratedRed: 0.005, green: 0.01, blue: 0.11, alpha: 1).setFill()
        dirtyRect.fill()

        drawTerrain()
        drawEntrance()
        drawHUD()
        drawExitBackgroundAndLeftPost()

        for walker in walkers where walker.state != .saved && walker.state != .dead {
            if walker.state == .exploding {
                drawExplosion(walker)
            } else if walker.state == .entering {
                drawEnteringWalker(walker)
            } else {
                drawWalker(walker)
            }
        }

        drawExitFrontAndRightPost()
    }

    private func drawHUD() {
        var text = "OUT \(spawnedCount - savedCount - deadCount)  IN \(savedCount)  RR \(releaseRate)"
        if paused { text += "  PAUSE" }
        if gameMode == .interactive { text += "  \(selectedSkill.shortName): TAP LEMMING" }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 5.7, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.78, alpha: 1)
        ]
        text.draw(at: NSPoint(x: 74, y: 1), withAttributes: attrs)
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

        drawGapBridge()
        drawWallRamp()

        if wallBashProgress < 1 {
            let remainingStart = wallStart + (wallEnd - wallStart) * wallBashProgress
            let wall = NSColor(calibratedRed: 0.43, green: 0.17, blue: 0.05, alpha: 1)
            let wallLight = NSColor(calibratedRed: 0.72, green: 0.34, blue: 0.08, alpha: 1)
            wall.setFill()
            NSRect(x: remainingStart, y: groundY - wallHeight, width: max(0, wallEnd - remainingStart), height: wallHeight).fill()
            wallLight.setFill()
            NSRect(x: remainingStart, y: groundY - wallHeight, width: max(0, wallEnd - remainingStart), height: 2).fill()
        }
    }

    private func drawGapBridge() {
        let dark = NSColor(calibratedRed: 0.55, green: 0.31, blue: 0.07, alpha: 1)
        let light = NSColor(calibratedRed: 0.88, green: 0.63, blue: 0.20, alpha: 1)
        for step in 0..<bridgeSteps {
            let x = gapStart + CGFloat(step) * gapStepWidth
            let y = groundY - CGFloat(step + 1) * gapStepRise
            dark.setFill(); NSRect(x: x, y: y - 1.5, width: gapStepWidth + 0.7, height: 2.3).fill()
            light.setFill(); NSRect(x: x + 0.5, y: y - 1.5, width: max(1, gapStepWidth - 1), height: 0.7).fill()
        }
    }

    private func drawWallRamp() {
        guard wallRampSteps > 0 else { return }
        let dark = NSColor(calibratedRed: 0.55, green: 0.31, blue: 0.07, alpha: 1)
        let light = NSColor(calibratedRed: 0.88, green: 0.63, blue: 0.20, alpha: 1)
        for step in 0..<wallRampSteps {
            let x = wallRampStart + CGFloat(step) * wallRampStepWidth
            let y = groundY - CGFloat(step + 1) * wallRampRise
            dark.setFill(); NSRect(x: x, y: y - 1.5, width: wallRampStepWidth + 0.8, height: 2.3).fill()
            light.setFill(); NSRect(x: x + 0.4, y: y - 1.5, width: max(1, wallRampStepWidth - 0.8), height: 0.7).fill()
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
        rim.setFill(); NSRect(x: x + 5, y: y + 2, width: 26, height: 2).fill()
        blue.setFill(); NSRect(x: x + 7, y: y + 4, width: 22, height: 4).fill()
        let open = CGFloat(max(0, min(1, (elapsed - 0.18) / 0.42)))
        NSColor.black.setFill()
        NSRect(x: x + 18 - 4 * open, y: y + 7, width: 8 * open, height: 5).fill()
    }

    private func drawExitBackgroundAndLeftPost() {
        let x = exitX
        let base = groundY
        let stoneDark = NSColor(calibratedRed: 0.22, green: 0.24, blue: 0.28, alpha: 1)
        let stone = NSColor(calibratedRed: 0.48, green: 0.49, blue: 0.50, alpha: 1)
        let doorway = NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.24, alpha: 1)

        doorway.setFill(); exitDoorRect.fill()
        stoneDark.setFill(); NSRect(x: x + 7, y: base - 15, width: 6, height: 15).fill()
        stone.setFill(); NSRect(x: x + 9, y: base - 17, width: 5, height: 4).fill()
    }

    private func drawExitFrontAndRightPost() {
        let x = exitX
        let base = groundY
        let stoneDark = NSColor(calibratedRed: 0.22, green: 0.24, blue: 0.28, alpha: 1)
        let stone = NSColor(calibratedRed: 0.48, green: 0.49, blue: 0.50, alpha: 1)

        stoneDark.setFill()
        NSRect(x: x + 9, y: base - 19, width: 20, height: 4).fill()
        NSRect(x: x + 25, y: base - 15, width: 6, height: 15).fill()
        stone.setFill()
        NSRect(x: x + 12, y: base - 21, width: 14, height: 3).fill()
        NSRect(x: x + 24, y: base - 17, width: 5, height: 4).fill()

        drawTorch(at: x + 4, base: base, phase: 0)
        drawTorch(at: x + 33, base: base, phase: .pi)
    }

    private func drawTorch(at x: CGFloat, base: CGFloat, phase: CGFloat) {
        let pulse = sin(CGFloat(elapsed) * 17 + phase)
        let height: CGFloat = pulse > 0.35 ? 6 : (pulse < -0.35 ? 4 : 5)
        let holder = NSColor(calibratedRed: 0.32, green: 0.22, blue: 0.12, alpha: 1)
        let red = NSColor(calibratedRed: 0.95, green: 0.10, blue: 0.02, alpha: 1)
        let yellow = NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.05, alpha: 1)
        holder.setFill(); NSRect(x: x, y: base - 11, width: 2, height: 4).fill()
        red.setFill(); NSRect(x: x - 1, y: base - 11 - height, width: 4, height: height).fill()
        yellow.setFill(); NSRect(x: x, y: base - 10 - height, width: 2, height: max(2, height - 2)).fill()
    }

    private func drawEnteringWalker(_ walker: Walker) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: exitDoorRect.insetBy(dx: 0.5, dy: 0)).addClip()
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
                guard let color = color else { continue }
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

        if walker.state == .building {
            drawBuilderBrick(walker)
        }

        if walker.state == .bombing {
            let remaining = max(0, bombCountdown - walker.stateTime)
            let text = String(Int(ceil(remaining)))
            text.draw(at: NSPoint(x: walker.x + 2, y: max(0, walker.y - 7)), withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .bold),
                .foregroundColor: NSColor.white
            ])
        }
    }

    private func drawExplosion(_ walker: Walker) {
        let center = NSPoint(x: walker.x + spriteWidth / 2, y: walker.y + spriteHeight / 2)
        let phase = CGFloat(min(1, walker.stateTime / 0.34))
        let radius = 3 + phase * 10
        NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.18, alpha: 1 - phase * 0.35).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - radius * 0.45, y: center.y - radius * 0.45, width: radius * 0.9, height: radius * 0.9)).fill()
        NSColor(calibratedRed: 1.0, green: 0.18, blue: 0.03, alpha: 1 - phase * 0.55).setStroke()
        for angle in stride(from: CGFloat(0), to: CGFloat.pi * 2, by: CGFloat.pi / 4) {
            let path = NSBezierPath()
            path.move(to: center)
            path.line(to: NSPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
            path.lineWidth = 1.3
            path.stroke()
        }
    }

    private func drawBuilderBrick(_ walker: Walker) {
        let phase = walker.stateTime.truncatingRemainder(dividingBy: builderBrickDuration) / builderBrickDuration
        let wood = NSColor(calibratedRed: 0.90, green: 0.66, blue: 0.22, alpha: 1)
        wood.setFill()
        if phase < 0.45 {
            NSRect(x: walker.x - 3, y: walker.y + 7, width: 5, height: 1.5).fill()
        } else {
            NSRect(x: walker.x + spriteWidth - 1, y: walker.y + 8, width: 6, height: 1.5).fill()
        }
    }
}
