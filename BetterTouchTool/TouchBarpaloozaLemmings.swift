// BTT-Plugin-Name: TouchBarpalooza Lemmings
// BTT-Plugin-Identifier: com.udeudeude.touchbarpalooza.lemmings
// BTT-Plugin-Type: TouchBar
// BTT-Plugin-Icon: figure.walk

import Cocoa

class TouchBarpaloozaLemmingsPlugin: NSObject, BTTPluginInterface {
    weak var delegate: (any BTTTouchBarPluginDelegate)?

    static func configurationFormItems() -> BTTPluginFormItem? { nil }

    private lazy var viewController: NSViewController = {
        let controller = NSViewController()
        let view = BTTLemmingsView(frame: NSRect(x: 0, y: 0, width: 650, height: 30))
        view.autoresizingMask = [.width, .height]
        controller.view = view
        controller.preferredContentSize = NSSize(width: 650, height: 30)
        return controller
    }()

    func touchBarViewController() -> NSViewController? {
        return viewController
    }
}

private final class BTTLemmingsView: NSView {
    private struct Walker {
        var x: CGFloat
        var speed: CGFloat
        var phase: CGFloat
    }

    private var walkers: [Walker] = [
        Walker(x: 14, speed: 28, phase: 0.0),
        Walker(x: 118, speed: 31, phase: 0.9),
        Walker(x: 238, speed: 25, phase: 1.8),
        Walker(x: 360, speed: 30, phase: 2.7),
        Walker(x: 492, speed: 27, phase: 3.6)
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
        let newTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(now - lastTick, 0.1)
        lastTick = now

        for index in walkers.indices {
            walkers[index].x += walkers[index].speed * CGFloat(dt)
            walkers[index].phase += CGFloat(dt) * 9.0
            if walkers[index].x > bounds.width + 16 {
                walkers[index].x = -18
            }
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()
        drawGround()
        for walker in walkers {
            drawWalker(walker)
        }
    }

    private func drawGround() {
        let y = bounds.height - 3
        NSColor(calibratedWhite: 0.20, alpha: 1).setFill()
        NSRect(x: 0, y: y, width: bounds.width, height: 3).fill()

        NSColor(calibratedWhite: 0.38, alpha: 1).setFill()
        for x in stride(from: CGFloat(0), through: bounds.width, by: 14) {
            NSRect(x: x, y: y, width: 7, height: 1).fill()
        }
    }

    private func drawWalker(_ walker: Walker) {
        let pixel: CGFloat = 2
        let step = sin(walker.phase)
        let frame = step >= 0
        let bob: CGFloat = abs(step) > 0.72 ? 1 : 0
        let originX = floor(walker.x)
        let originY = bounds.height - 24 - bob

        func block(_ x: Int, _ y: Int, _ w: Int = 1, _ h: Int = 1, color: NSColor) {
            color.setFill()
            NSRect(
                x: originX + CGFloat(x) * pixel,
                y: originY + CGFloat(y) * pixel,
                width: CGFloat(w) * pixel,
                height: CGFloat(h) * pixel
            ).fill()
        }

        let hair = NSColor(calibratedRed: 0.20, green: 0.96, blue: 0.20, alpha: 1)
        let skin = NSColor(calibratedRed: 0.98, green: 0.73, blue: 0.55, alpha: 1)
        let shirt = NSColor(calibratedRed: 0.12, green: 0.36, blue: 0.98, alpha: 1)
        let shoe = NSColor(calibratedWhite: 0.90, alpha: 1)

        block(1, 0, 4, 1, color: hair)
        block(0, 1, 6, 1, color: hair)
        block(1, 2, 5, 1, color: hair)
        block(2, 3, 3, 2, color: skin)
        block(5, 3, 1, 1, color: skin)

        block(2, 5, 3, 3, color: shirt)
        block(1, 6, 1, 2, color: shirt)
        block(5, 6, 1, 2, color: shirt)

        if frame {
            block(0, 6, 2, 1, color: skin)
            block(5, 7, 2, 1, color: skin)
            block(2, 8, 1, 2, color: skin)
            block(4, 8, 1, 1, color: skin)
            block(5, 9, 1, 1, color: skin)
            block(1, 10, 2, 1, color: shoe)
            block(5, 10, 2, 1, color: shoe)
        } else {
            block(0, 7, 2, 1, color: skin)
            block(5, 6, 2, 1, color: skin)
            block(2, 8, 1, 1, color: skin)
            block(1, 9, 1, 1, color: skin)
            block(4, 8, 1, 2, color: skin)
            block(0, 10, 2, 1, color: shoe)
            block(4, 10, 2, 1, color: shoe)
        }
    }
}
