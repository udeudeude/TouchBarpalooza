import AppKit

final class LemmingsView: NSView {
    private struct Walker {
        var x: CGFloat
        var speed: CGFloat
        var phase: CGFloat
    }

    private var walkers: [Walker] = [
        Walker(x: 16, speed: 26, phase: 0.0),
        Walker(x: 126, speed: 31, phase: 0.7),
        Walker(x: 258, speed: 23, phase: 1.4),
        Walker(x: 390, speed: 29, phase: 2.1),
        Walker(x: 532, speed: 25, phase: 2.8)
    ]

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

    private func startAnimating() {
        timer?.invalidate()
        lastTick = ProcessInfo.processInfo.systemUptime
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(now - lastTick, 0.1)
        lastTick = now

        for index in walkers.indices {
            walkers[index].x += walkers[index].speed * CGFloat(dt)
            walkers[index].phase += CGFloat(dt) * 8
            if walkers[index].x > bounds.width + 14 {
                walkers[index].x = -18
            }
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.black.setFill()
        dirtyRect.fill()

        drawGround()
        for walker in walkers {
            drawWalker(walker)
        }
    }

    private func drawGround() {
        let y = bounds.height - 4
        NSColor(calibratedWhite: 0.22, alpha: 1).setFill()
        NSRect(x: 0, y: y, width: bounds.width, height: 4).fill()

        NSColor(calibratedWhite: 0.38, alpha: 1).setFill()
        for x in stride(from: CGFloat(0), through: bounds.width, by: 14) {
            NSRect(x: x, y: y, width: 7, height: 1).fill()
        }
    }

    private func drawWalker(_ walker: Walker) {
        let pixel: CGFloat = 2
        let originX = floor(walker.x)
        let originY = bounds.height - 22
        let step = sin(walker.phase)
        let armForward = step > 0

        func block(_ x: Int, _ y: Int, _ w: Int = 1, _ h: Int = 1, color: NSColor) {
            color.setFill()
            NSRect(
                x: originX + CGFloat(x) * pixel,
                y: originY + CGFloat(y) * pixel,
                width: CGFloat(w) * pixel,
                height: CGFloat(h) * pixel
            ).fill()
        }

        let hair = NSColor(calibratedRed: 0.25, green: 0.95, blue: 0.22, alpha: 1)
        let skin = NSColor(calibratedRed: 0.96, green: 0.72, blue: 0.56, alpha: 1)
        let shirt = NSColor(calibratedRed: 0.16, green: 0.35, blue: 0.95, alpha: 1)
        let shoe = NSColor(calibratedWhite: 0.84, alpha: 1)

        // Wild green hair
        block(2, 0, 3, 1, color: hair)
        block(1, 1, 5, 1, color: hair)
        block(2, 2, 4, 1, color: hair)

        // Face
        block(2, 3, 3, 2, color: skin)
        block(5, 3, 1, 1, color: skin)

        // Blue tunic/body
        block(2, 5, 3, 3, color: shirt)
        block(1, 6, 1, 2, color: shirt)
        block(5, 6, 1, 2, color: shirt)

        // Arms swing opposite the legs
        if armForward {
            block(0, 7, 2, 1, color: skin)
            block(5, 5, 2, 1, color: skin)
        } else {
            block(0, 5, 2, 1, color: skin)
            block(5, 7, 2, 1, color: skin)
        }

        // Two-frame-ish walking gait
        if step > 0 {
            block(2, 8, 1, 2, color: skin)
            block(4, 8, 1, 1, color: skin)
            block(5, 9, 1, 1, color: skin)
            block(1, 10, 2, 1, color: shoe)
            block(5, 10, 2, 1, color: shoe)
        } else {
            block(2, 8, 1, 1, color: skin)
            block(1, 9, 1, 1, color: skin)
            block(4, 8, 1, 2, color: skin)
            block(0, 10, 2, 1, color: shoe)
            block(4, 10, 2, 1, color: shoe)
        }
    }
}
