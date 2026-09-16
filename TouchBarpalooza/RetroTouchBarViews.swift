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

// MARK: - DVD VIDEO idle screen

final class DVDBounceSaverView: NSView {
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var position = NSPoint(x: 31, y: 3)
    // Preserve the classic diagonal drift without making the ultra-wide, 30 pt
    // Touch Bar ricochet vertically several times per second.
    private var velocity = NSPoint(x: 52, y: 7.5)
    private var colorIndex = 0
    private let logoSize = NSSize(width: 36, height: 21.6)

    private let colors: [NSColor] = [
        NSColor(calibratedRed: 0.22, green: 0.85, blue: 0.95, alpha: 1),
        NSColor(calibratedRed: 0.93, green: 0.35, blue: 0.80, alpha: 1),
        NSColor(calibratedRed: 0.97, green: 0.81, blue: 0.22, alpha: 1),
        NSColor(calibratedRed: 0.46, green: 0.93, blue: 0.34, alpha: 1),
        NSColor(calibratedRed: 0.58, green: 0.44, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.46, blue: 0.29, alpha: 1)
    ]

    // DVD FLLC logo geometry, from the public-domain DVD-Video logo on
    // Wikimedia Commons. macOS 14+ loads SVG directly through NSImage.
    private lazy var exactLogo: NSImage? = {
        let path = "M469.9 212.1h-14.7l-.4 2.2h6.2l-2.2 17.3h2.6l2.3-17.3h5.7zM480.1 224.9l-3.1-12.8h-1.8l-6.7 19.5h2.2l5.4-15.1 3.1 15.1 8-15.1v15.1h2.6v-19.5h-2.6zM76.2 282.1 59 249.7H44.3l27.1 49.7h8.4l27.5-49.7H92.2zM141 275.4v24h13.3v-49.7H141zM285 299.4h36.8V291h-23v-13.3h21.7v-8.5h-21.7v-11h23v-8.5H285zM472 188.1c0-18.6-105.6-33.7-236-33.7S0 169.5 0 188.1s105.7 33.7 236 33.7 236-15 236-33.7zm-298.7.5c0-6.2 24.2-11.1 54.1-11.1s54 5 54 11-24.1 11.1-54 11.1-54-5-54-11zM392.3 249.5c-19.3 0-35 11.1-35 24.8s15.7 24.8 35 24.8 35-11 35-24.8c0-13.7-15.7-24.8-35-24.8zm0 40.6c-11.5 0-20.8-7-20.8-15.8 0-8.7 9.3-15.7 20.8-15.7s20.8 7 20.8 15.7-9.3 15.8-20.8 15.8zM214.8 249.7h-21v49.7h21s33.4 0 33.4-24.6-33.4-25-33.4-25zm-7 41.2v-32.7s26.2-1.7 26.2 16.5c0 18.1-26.1 16.2-26.1 16.2zM192 54.3a78 78 0 0 0-4-26.2h1.7L234.5 154 344.5 28h59.3S450 26.8 450 56.5s-38.4 41.2-63 41.2h-10.6l13.8-59.4h-48.3l-20.4 86.4h65.8c63 0 112.8-34.6 112.8-70.4C500 1.3 418.9.6 418.9.6h-102l-64.7 81.6L227 .6H43l-6.7 27.5h61.5c8.7.2 44 2.4 44 28.4 0 29.7-38.4 41.2-62.9 41.2H68.3L82 38.3H33.7l-20.4 86.4h65.8c63 0 112.8-34.6 112.8-70.4z"
        let svg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 500 307'><path fill='white' fill-rule='evenodd' d='\(path)'/></svg>"
        guard let data = svg.data(using: .utf8) else { return nil }
        return NSImage(data: data)
    }()

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
        var hit = false

        if position.x < 0 {
            position.x = -position.x
            velocity.x = abs(velocity.x)
            hit = true
        } else if position.x > maxX {
            position.x = maxX - (position.x - maxX)
            velocity.x = -abs(velocity.x)
            hit = true
        }

        if position.y < 0 {
            position.y = -position.y
            velocity.y = abs(velocity.y)
            hit = true
        } else if position.y > maxY {
            position.y = maxY - (position.y - maxY)
            velocity.y = -abs(velocity.y)
            hit = true
        }

        if hit {
            colorIndex = (colorIndex + 1) % colors.count
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        let rect = NSRect(origin: position, size: logoSize)
        let color = colors[colorIndex]

        if let exactLogo {
            let tinted = NSImage(size: logoSize)
            tinted.lockFocus()
            exactLogo.draw(in: NSRect(origin: .zero, size: logoSize))
            color.set()
            NSRect(origin: .zero, size: logoSize).fill(using: .sourceAtop)
            tinted.unlockFocus()
            tinted.draw(in: rect)
        } else {
            drawFallbackLogo(in: rect, color: color)
        }
    }

    private func drawFallbackLogo(in rect: NSRect, color: NSColor) {
        let font = NSFont(name: "HelveticaNeue-CondensedBlackItalic", size: 13)
            ?? NSFont.systemFont(ofSize: 13, weight: .black)
        ("DVD" as NSString).draw(
            at: NSPoint(x: rect.minX + 1, y: rect.minY + 12),
            withAttributes: [.font: font, .foregroundColor: color]
        )

        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: rect.minX, y: rect.minY + 3, width: rect.width, height: 8)).fill()
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: rect.midX - 5, y: rect.minY + 6, width: 10, height: 2)).fill()
        ("VIDEO" as NSString).draw(
            at: NSPoint(x: rect.minX + 13, y: rect.minY + 3.5),
            withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 4.8, weight: .bold),
                .foregroundColor: NSColor.black
            ]
        )
    }
}

// MARK: - Windows 3D Pipes

final class PipesSaverView: NSView {
    private struct Point3: Hashable {
        var x: Int
        var y: Int
        var z: Int
    }

    private enum JointKind {
        case elbow
        case ball
        case teapot
    }

    private struct Segment {
        var a: Point3
        var b: Point3
        var colorIndex: Int
        var jointAtA: JointKind?
    }

    private struct Head {
        var point: Point3
        var direction: Int
        var colorIndex: Int
    }

    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var stepAccumulator: TimeInterval = 0
    private var sceneAge: TimeInterval = 0
    private var segments: [Segment] = []
    private var heads: [Head] = []
    private var starts: [(Point3, Int)] = []
    private var occupied = Set<Point3>()
    private var dissolving = false
    private var dissolveProgress: CGFloat = 0

    private let colors: [NSColor] = [
        NSColor(calibratedRed: 0.05, green: 0.63, blue: 0.53, alpha: 1),
        NSColor(calibratedRed: 0.92, green: 0.70, blue: 0.09, alpha: 1),
        NSColor(calibratedRed: 0.89, green: 0.14, blue: 0.11, alpha: 1),
        NSColor(calibratedRed: 0.73, green: 0.82, blue: 0.72, alpha: 1),
        NSColor(calibratedRed: 0.91, green: 0.39, blue: 0.11, alpha: 1),
        NSColor(calibratedWhite: 0.78, alpha: 1)
    ]

    private let directions = [
        Point3(x: 1, y: 0, z: 0), Point3(x: -1, y: 0, z: 0),
        Point3(x: 0, y: 1, z: 0), Point3(x: 0, y: -1, z: 0),
        Point3(x: 0, y: 0, z: 1), Point3(x: 0, y: 0, z: -1)
    ]

    override var intrinsicContentSize: NSSize { NSSize(width: 660, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        resetScene()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func resetScene() {
        segments.removeAll(keepingCapacity: true)
        heads.removeAll(keepingCapacity: true)
        starts.removeAll(keepingCapacity: true)
        occupied.removeAll(keepingCapacity: true)
        dissolving = false
        dissolveProgress = 0
        sceneAge = 0

        let pipeCount = Int.random(in: 4...6)
        for index in 0..<pipeCount {
            var point = Point3(
                x: Int.random(in: -10...10),
                y: Int.random(in: -2...2),
                z: Int.random(in: -8...8)
            )
            var tries = 0
            while occupied.contains(point) && tries < 20 {
                point = Point3(
                    x: Int.random(in: -10...10),
                    y: Int.random(in: -2...2),
                    z: Int.random(in: -8...8)
                )
                tries += 1
            }
            occupied.insert(point)
            heads.append(Head(point: point, direction: Int.random(in: 0..<directions.count), colorIndex: index % colors.count))
            starts.append((point, index % colors.count))
        }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick)
        lastTick = now
        sceneAge += dt

        if dissolving {
            dissolveProgress += CGFloat(dt) / 0.82
            if dissolveProgress >= 1 {
                resetScene()
            }
            needsDisplay = true
            return
        }

        stepAccumulator += dt
        while stepAccumulator >= 0.085 {
            stepAccumulator -= 0.085
            for index in heads.indices {
                extendPipe(index)
            }
        }

        if segments.count > 235 || sceneAge > 22 || heads.isEmpty {
            dissolving = true
        }
        needsDisplay = true
    }

    private func extendPipe(_ index: Int) {
        guard heads.indices.contains(index) else { return }
        let head = heads[index]
        let reverse = opposite(of: head.direction)

        var choices = Array(0..<directions.count)
        choices.removeAll { $0 == reverse }

        if Int.random(in: 0..<100) < 56,
           let currentIndex = choices.firstIndex(of: head.direction) {
            let current = choices.remove(at: currentIndex)
            choices.shuffle()
            choices.insert(current, at: 0)
        } else {
            choices.shuffle()
        }

        var chosenDirection: Int?
        var nextPoint: Point3?
        for direction in choices {
            let candidate = moved(head.point, direction: direction)
            if inside(candidate) && !occupied.contains(candidate) {
                chosenDirection = direction
                nextPoint = candidate
                break
            }
        }

        guard let newDirection = chosenDirection, let next = nextPoint else {
            let newStart = Point3(
                x: Int.random(in: -10...10),
                y: Int.random(in: -2...2),
                z: Int.random(in: -8...8)
            )
            if !occupied.contains(newStart) {
                heads[index].point = newStart
                heads[index].direction = Int.random(in: 0..<directions.count)
                occupied.insert(newStart)
                starts.append((newStart, head.colorIndex))
            }
            return
        }

        let turned = newDirection != head.direction
        var joint: JointKind?
        if turned {
            // Windows' mixed-joint mode: 1/1000 Utah teapot; otherwise,
            // Windows NT 4+ uses 1/3 ball joints and 2/3 elbows.
            if Int.random(in: 0..<1000) == 0 {
                joint = .teapot
            } else if Int.random(in: 0..<3) == 0 {
                joint = .ball
            } else {
                joint = .elbow
            }
        }

        segments.append(Segment(a: head.point, b: next, colorIndex: head.colorIndex, jointAtA: joint))
        occupied.insert(next)
        heads[index].point = next
        heads[index].direction = newDirection
    }

    private func moved(_ point: Point3, direction: Int) -> Point3 {
        let step = directions[direction]
        return Point3(x: point.x + step.x, y: point.y + step.y, z: point.z + step.z)
    }

    private func opposite(of direction: Int) -> Int {
        switch direction {
        case 0: return 1
        case 1: return 0
        case 2: return 3
        case 3: return 2
        case 4: return 5
        default: return 4
        }
    }

    private func inside(_ point: Point3) -> Bool {
        (-11...11).contains(point.x) && (-3...3).contains(point.y) && (-9...9).contains(point.z)
    }

    private func projected(_ point: Point3) -> (point: NSPoint, scale: CGFloat, depth: CGFloat) {
        let angle: CGFloat = 0.54
        let x = CGFloat(point.x)
        let z = CGFloat(point.z)
        let rotatedX = x * cos(angle) + z * sin(angle)
        let rotatedZ = -x * sin(angle) + z * cos(angle)
        let scale = 1.0 / max(0.58, 1.0 + (rotatedZ + 11) * 0.025)
        return (
            NSPoint(
                x: bounds.midX + rotatedX * 24 * scale,
                y: bounds.midY + CGFloat(point.y) * 5.5 * scale + rotatedZ * 0.10
            ),
            scale,
            rotatedZ
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        let ordered = segments.sorted {
            let d0 = (projected($0.a).depth + projected($0.b).depth) * 0.5
            let d1 = (projected($1.a).depth + projected($1.b).depth) * 0.5
            return d0 > d1
        }

        for segment in ordered {
            drawSegment(segment)
        }

        for (point, colorIndex) in starts {
            drawBall(at: point, color: colors[colorIndex % colors.count], multiplier: 1.0)
        }
        for head in heads {
            drawBall(at: head.point, color: colors[head.colorIndex % colors.count], multiplier: 1.0)
        }

        if dissolving {
            drawDissolveOverlay()
        }
    }

    private func drawSegment(_ segment: Segment) {
        let pa = projected(segment.a)
        let pb = projected(segment.b)
        let scale = (pa.scale + pb.scale) * 0.5
        let color = colors[segment.colorIndex % colors.count]

        let shadow = NSBezierPath()
        shadow.move(to: NSPoint(x: pa.point.x + 1.1, y: pa.point.y - 1.1))
        shadow.line(to: NSPoint(x: pb.point.x + 1.1, y: pb.point.y - 1.1))
        shadow.lineWidth = 7.2 * scale
        NSColor(calibratedWhite: 0.05, alpha: 1).setStroke()
        shadow.stroke()

        let pipe = NSBezierPath()
        pipe.move(to: pa.point)
        pipe.line(to: pb.point)
        pipe.lineWidth = 5.4 * scale
        color.setStroke()
        pipe.stroke()

        let highlight = NSBezierPath()
        highlight.move(to: NSPoint(x: pa.point.x - 0.8, y: pa.point.y + 0.8))
        highlight.line(to: NSPoint(x: pb.point.x - 0.8, y: pb.point.y + 0.8))
        highlight.lineWidth = max(0.7, 1.0 * scale)
        NSColor(calibratedWhite: 1.0, alpha: 0.60).setStroke()
        highlight.stroke()

        guard let joint = segment.jointAtA else { return }
        switch joint {
        case .elbow:
            drawBall(at: segment.a, color: color, multiplier: 0.78)
        case .ball:
            drawBall(at: segment.a, color: color, multiplier: 1.35)
        case .teapot:
            drawTeapot(at: segment.a, color: color)
        }
    }

    private func drawBall(at point: Point3, color: NSColor, multiplier: CGFloat) {
        let projection = projected(point)
        let diameter = 6.2 * projection.scale * multiplier
        let rect = NSRect(
            x: projection.point.x - diameter / 2,
            y: projection.point.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        NSColor(calibratedWhite: 0.05, alpha: 1).setFill()
        NSBezierPath(ovalIn: rect.offsetBy(dx: 0.9, dy: -0.9)).fill()
        color.setFill()
        NSBezierPath(ovalIn: rect).fill()
        NSColor(calibratedWhite: 1, alpha: 0.52).setFill()
        NSBezierPath(ovalIn: NSRect(x: rect.minX + diameter * 0.17, y: rect.maxY - diameter * 0.38, width: diameter * 0.28, height: diameter * 0.22)).fill()
    }

    private func drawTeapot(at point: Point3, color: NSColor) {
        let projection = projected(point)
        let s = max(0.7, projection.scale)
        let center = projection.point
        color.setFill()
        color.setStroke()

        NSBezierPath(ovalIn: NSRect(x: center.x - 5.2 * s, y: center.y - 3.0 * s, width: 10.4 * s, height: 6.0 * s)).fill()
        NSRect(x: center.x - 2.3 * s, y: center.y + 2.6 * s, width: 4.6 * s, height: 1.2 * s).fill()
        NSRect(x: center.x - 0.8 * s, y: center.y + 3.7 * s, width: 1.6 * s, height: 1.0 * s).fill()

        let spout = NSBezierPath()
        spout.move(to: NSPoint(x: center.x + 3.5 * s, y: center.y + 1.0 * s))
        spout.line(to: NSPoint(x: center.x + 8.0 * s, y: center.y + 3.0 * s))
        spout.line(to: NSPoint(x: center.x + 5.5 * s, y: center.y - 0.5 * s))
        spout.close()
        spout.fill()

        let handle = NSBezierPath()
        handle.appendArc(
            withCenter: NSPoint(x: center.x - 4.5 * s, y: center.y + 0.4 * s),
            radius: 3.1 * s,
            startAngle: 70,
            endAngle: 290,
            clockwise: true
        )
        handle.lineWidth = 1.4 * s
        handle.stroke()

        NSColor(calibratedWhite: 1, alpha: 0.55).setFill()
        NSRect(x: center.x - 2.8 * s, y: center.y + 1.5 * s, width: 3.4 * s, height: 0.8 * s).fill()
    }

    private func drawDissolveOverlay() {
        NSColor.black.setFill()
        let columns = 33
        let rows = 3
        let total = columns * rows
        let visibleCount = min(total, Int(CGFloat(total) * dissolveProgress))
        let cellWidth = bounds.width / CGFloat(columns)
        let cellHeight = bounds.height / CGFloat(rows)

        for index in 0..<visibleCount {
            let scrambled = (index * 37 + 11) % total
            let x = scrambled % columns
            let y = scrambled / columns
            NSRect(
                x: CGFloat(x) * cellWidth,
                y: CGFloat(y) * cellHeight,
                width: ceil(cellWidth) + 1,
                height: ceil(cellHeight) + 1
            ).fill()
        }
    }
}

// MARK: - After Dark 2.0 Flying Toasters

final class FlyingToastersSaverView: NSView {
    private enum Kind {
        case toaster
        case toast
    }

    private struct Flyer {
        var kind: Kind
        var x: CGFloat
        var y: CGFloat
        var speed: CGFloat
        var scale: CGFloat
        var phase: CGFloat
    }

    private var flyers: [Flyer] = []
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var elapsed: CGFloat = 0

    override var intrinsicContentSize: NSSize { NSSize(width: 660, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        seedFlyers()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func seedFlyers() {
        flyers.removeAll()
        for index in 0..<8 {
            flyers.append(Flyer(
                kind: .toaster,
                x: CGFloat(index) * 104 + 30,
                y: CGFloat(8 + (index * 5) % 20),
                speed: CGFloat(34 + (index * 7) % 35),
                scale: [0.70, 0.82, 0.94, 1.05][index % 4],
                phase: CGFloat(index) * 0.57
            ))
        }
        for index in 0..<4 {
            flyers.append(Flyer(
                kind: .toast,
                x: CGFloat(index) * 170 + 105,
                y: CGFloat(5 + (index * 7) % 22),
                speed: CGFloat(30 + index * 8),
                scale: CGFloat(0.72 + Double(index) * 0.08),
                phase: CGFloat(index) * 0.83
            ))
        }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick)
        lastTick = now
        elapsed += CGFloat(dt)

        let slope = max(0.035, min(0.075, bounds.height / max(1, bounds.width)))
        for index in flyers.indices {
            flyers[index].x -= flyers[index].speed * CGFloat(dt)
            flyers[index].y -= flyers[index].speed * slope * CGFloat(dt)

            if flyers[index].x < -45 || flyers[index].y < -18 {
                flyers[index].x = bounds.width + CGFloat.random(in: 10...180)
                flyers[index].y = bounds.height + CGFloat.random(in: 0...12)
                flyers[index].speed = CGFloat.random(in: 32...72)
                flyers[index].scale = CGFloat.random(in: 0.68...1.08)
                flyers[index].phase = CGFloat.random(in: 0...(CGFloat.pi * 2))
            }
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        for flyer in flyers.sorted(by: { $0.scale < $1.scale }) {
            switch flyer.kind {
            case .toaster:
                drawToaster(flyer)
            case .toast:
                drawToast(flyer)
            }
        }
    }

    private func drawToaster(_ flyer: Flyer) {
        let s = flyer.scale
        let x = floor(flyer.x)
        let y = floor(flyer.y)
        let frame = Int((elapsed * 9 + flyer.phase).rounded(.down)) % 4

        let dark = NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.18, alpha: 1)
        let side = NSColor(calibratedRed: 0.39, green: 0.47, blue: 0.39, alpha: 1)
        let metal = NSColor(calibratedRed: 0.78, green: 0.80, blue: 0.78, alpha: 1)
        let shine = NSColor(calibratedWhite: 0.98, alpha: 1)
        let red = NSColor(calibratedRed: 0.86, green: 0.13, blue: 0.08, alpha: 1)

        dark.setFill()
        NSRect(x: x + 2 * s, y: y + 8 * s, width: 15 * s, height: 2 * s).fill()
        metal.setFill()
        NSBezierPath(roundedRect: NSRect(x: x + 1 * s, y: y + 1 * s, width: 17 * s, height: 10 * s), xRadius: 2.5 * s, yRadius: 2.5 * s).fill()
        side.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: y + 2 * s, width: 5 * s, height: 8 * s), xRadius: 1.6 * s, yRadius: 1.6 * s).fill()
        shine.setFill()
        NSRect(x: x + 5 * s, y: y + 8.3 * s, width: 10 * s, height: 1.0 * s).fill()
        dark.setFill()
        NSRect(x: x + 6 * s, y: y + 9.5 * s, width: 8 * s, height: 0.8 * s).fill()
        NSRect(x: x + 7 * s, y: y + 7.4 * s, width: 7 * s, height: 0.7 * s).fill()
        red.setFill()
        NSRect(x: x + 1.0 * s, y: y + 5.8 * s, width: 1.6 * s, height: 1.6 * s).fill()

        dark.setFill()
        NSRect(x: x + 3 * s, y: y, width: 3 * s, height: 1.3 * s).fill()
        NSRect(x: x + 13 * s, y: y, width: 3 * s, height: 1.3 * s).fill()
        let cord = NSBezierPath()
        cord.move(to: NSPoint(x: x + 17 * s, y: y + 2 * s))
        cord.curve(
            to: NSPoint(x: x + 23 * s, y: y - 1 * s),
            controlPoint1: NSPoint(x: x + 19 * s, y: y + 1 * s),
            controlPoint2: NSPoint(x: x + 20 * s, y: y - 2 * s)
        )
        cord.lineWidth = max(0.7, 0.9 * s)
        NSColor(calibratedWhite: 0.60, alpha: 1).setStroke()
        cord.stroke()

        drawWing(at: NSPoint(x: x + 16 * s, y: y + 5 * s), scale: s, frame: frame)
    }

    private func drawWing(at root: NSPoint, scale s: CGFloat, frame: Int) {
        let wing = NSColor(calibratedWhite: 0.96, alpha: 1)
        wing.setFill()

        let lifts: [CGFloat] = [0, 3.2, 0.8, -2.2]
        let lift = lifts[frame]
        let path = NSBezierPath()
        path.move(to: root)
        path.line(to: NSPoint(x: root.x + 8 * s, y: root.y + (4 + lift) * s))
        path.line(to: NSPoint(x: root.x + 13 * s, y: root.y + (3 + lift) * s))
        path.line(to: NSPoint(x: root.x + 9 * s, y: root.y + (1 + lift * 0.6) * s))
        path.line(to: NSPoint(x: root.x + 13 * s, y: root.y - (1 - lift * 0.25) * s))
        path.line(to: NSPoint(x: root.x + 7 * s, y: root.y - 2 * s))
        path.line(to: root)
        path.close()
        path.fill()

        NSColor(calibratedWhite: 0.70, alpha: 1).setStroke()
        let feather = NSBezierPath()
        feather.move(to: root)
        feather.line(to: NSPoint(x: root.x + 9 * s, y: root.y + (1.5 + lift * 0.55) * s))
        feather.lineWidth = max(0.6, 0.7 * s)
        feather.stroke()
    }

    private func drawToast(_ flyer: Flyer) {
        let s = flyer.scale
        let x = floor(flyer.x)
        let y = floor(flyer.y)
        let crust = NSColor(calibratedRed: 0.56, green: 0.28, blue: 0.08, alpha: 1)
        let bread = NSColor(calibratedRed: 0.92, green: 0.69, blue: 0.31, alpha: 1)
        crust.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 10 * s, height: 7 * s), xRadius: 2.7 * s, yRadius: 2.7 * s).fill()
        bread.setFill()
        NSBezierPath(roundedRect: NSRect(x: x + 1.2 * s, y: y + 1.1 * s, width: 7.6 * s, height: 4.8 * s), xRadius: 2.0 * s, yRadius: 2.0 * s).fill()
    }
}

// MARK: - Super Mario Bros. World 1-1 miniature

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

    private let keyMonitor = RetroKeyMonitor()
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

    private let controlsWidth: CGFloat = 132
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
        NSPoint(x: 1232, y: 136), NSPoint(x: 1264, y: 136),
        NSPoint(x: 1280, y: 72), NSPoint(x: 1296, y: 72), NSPoint(x: 1312, y: 72),
        NSPoint(x: 1328, y: 72), NSPoint(x: 1344, y: 72), NSPoint(x: 1360, y: 72),
        NSPoint(x: 1376, y: 72), NSPoint(x: 1392, y: 72), NSPoint(x: 1456, y: 72),
        NSPoint(x: 1472, y: 72), NSPoint(x: 1488, y: 72), NSPoint(x: 1504, y: 136),
        NSPoint(x: 1600, y: 136), NSPoint(x: 1616, y: 136), NSPoint(x: 1888, y: 136),
        NSPoint(x: 1936, y: 72), NSPoint(x: 1952, y: 72), NSPoint(x: 1968, y: 72),
        NSPoint(x: 2048, y: 72), NSPoint(x: 2096, y: 72), NSPoint(x: 2064, y: 136),
        NSPoint(x: 2080, y: 136), NSPoint(x: 2688, y: 136), NSPoint(x: 2704, y: 136),
        NSPoint(x: 2736, y: 136)
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

    override var intrinsicContentSize: NSSize { NSSize(width: 660, height: 30) }

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

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func resetEnemies() {
        let goombaStarts: [CGFloat] = [
            352, 640, 864, 872, 1536, 1568, 1856, 1864,
            2384, 2392, 2544, 2552, 2608, 2616, 3088, 3096
        ]
        enemies = goombaStarts.map { Enemy(kind: .goomba, x: $0, direction: -1, alive: true) }
        enemies.append(Enemy(kind: .koopa, x: 2224, direction: -1, alive: true))
    }

    private func buildControls() {
        let left = NSButton(title: "◀", target: self, action: #selector(stepLeft))
        left.frame = NSRect(x: 2, y: 2, width: 27, height: 26)
        left.isContinuous = true
        left.periodicDelay = 0.18
        left.periodicInterval = 0.055
        addSubview(left)

        let jump = NSButton(title: "JUMP", target: self, action: #selector(jumpPressed))
        jump.font = .systemFont(ofSize: 7)
        jump.frame = NSRect(x: 31, y: 2, width: 43, height: 26)
        addSubview(jump)

        let right = NSButton(title: "▶", target: self, action: #selector(stepRight))
        right.frame = NSRect(x: 76, y: 2, width: 27, height: 26)
        right.isContinuous = true
        right.periodicDelay = 0.18
        right.periodicInterval = 0.055
        addSubview(right)

        let run = NSButton(title: "RUN", target: self, action: #selector(toggleRun(_:)))
        run.font = .systemFont(ofSize: 7)
        run.frame = NSRect(x: 105, y: 2, width: 26, height: 26)
        run.setButtonType(.pushOnPushOff)
        addSubview(run)
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

    @objc private func jumpPressed() { jump() }

    @objc private func toggleRun(_ sender: NSButton) {
        runLatched = sender.state == .on
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
            let right = pipe.x + 32 + 7
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
            let fill = NSColor(calibratedRed: 0.78, green: 0.34, blue: 0.10, alpha: 1)
            let line = NSColor(calibratedRed: 0.43, green: 0.13, blue: 0.03, alpha: 1)
            fill.setFill()
            NSRect(x: x, y: y, width: width, height: height).fill()
            line.setFill()
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
            let green = NSColor(calibratedRed: 0.07, green: 0.69, blue: 0.12, alpha: 1)
            let dark = NSColor(calibratedRed: 0.01, green: 0.30, blue: 0.04, alpha: 1)
            green.setFill()
            NSRect(x: x + 2, y: 4, width: 12, height: height).fill()
            NSRect(x: x, y: 4 + height - 3.2, width: 16, height: 3.5).fill()
            dark.setFill()
            NSRect(x: x + 10, y: 4, width: 2.2, height: height).fill()
            NSRect(x: x + 12.8, y: 4 + height - 3.2, width: 2, height: 3.5).fill()
        }
    }

    private func drawEnemies(camera: CGFloat, gameLeft: CGFloat) {
        for enemy in enemies where enemy.alive {
            let x = gameLeft + (enemy.x - camera) * xScale
            if x < gameLeft - 20 || x > bounds.width + 20 { continue }
            switch enemy.kind {
            case .goomba:
                drawGoomba(at: NSPoint(x: x, y: 4))
            case .koopa:
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
            let brick = NSColor(calibratedRed: 0.70, green: 0.26, blue: 0.08, alpha: 1)
            let dark = NSColor(calibratedRed: 0.20, green: 0.08, blue: 0.03, alpha: 1)
            brick.setFill()
            NSRect(x: castleX, y: 4, width: 34, height: 15).fill()
            NSRect(x: castleX + 5, y: 19, width: 7, height: 5).fill()
            NSRect(x: castleX + 22, y: 19, width: 7, height: 5).fill()
            dark.setFill()
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
        let fill = NSColor(calibratedRed: 0.77, green: 0.31, blue: 0.09, alpha: 1)
        let line = NSColor(calibratedRed: 0.38, green: 0.10, blue: 0.02, alpha: 1)
        fill.setFill()
        NSRect(x: point.x, y: point.y, width: 8.8, height: 3.1).fill()
        line.setFill()
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
        let brown = NSColor(calibratedRed: 0.50, green: 0.20, blue: 0.05, alpha: 1)
        let tan = NSColor(calibratedRed: 0.90, green: 0.63, blue: 0.30, alpha: 1)
        let black = NSColor.black
        brown.setFill()
        NSBezierPath(roundedRect: NSRect(x: point.x, y: point.y + 2, width: 8, height: 6), xRadius: 3, yRadius: 3).fill()
        tan.setFill()
        NSRect(x: point.x + 1, y: point.y, width: 2.5, height: 2.5).fill()
        NSRect(x: point.x + 4.5, y: point.y, width: 2.5, height: 2.5).fill()
        black.setFill()
        NSRect(x: point.x + 2, y: point.y + 5, width: 1, height: 1.5).fill()
        NSRect(x: point.x + 5, y: point.y + 5, width: 1, height: 1.5).fill()
    }

    private func drawKoopa(at point: NSPoint) {
        let green = NSColor(calibratedRed: 0.08, green: 0.63, blue: 0.13, alpha: 1)
        let skin = NSColor(calibratedRed: 0.93, green: 0.73, blue: 0.39, alpha: 1)
        green.setFill()
        NSBezierPath(ovalIn: NSRect(x: point.x + 1, y: point.y + 3, width: 7, height: 8)).fill()
        skin.setFill()
        NSRect(x: point.x + 3, y: point.y + 10, width: 4, height: 3).fill()
        NSRect(x: point.x, y: point.y, width: 3, height: 2).fill()
        NSRect(x: point.x + 6, y: point.y, width: 3, height: 2).fill()
    }
}
