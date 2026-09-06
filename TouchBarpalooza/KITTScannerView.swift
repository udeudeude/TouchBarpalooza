import AppKit

final class KITTScannerView: NSView {
    private let lampCount = 8
    private var intensities = Array(repeating: CGFloat(0), count: 8)
    private var headIndex = 0
    private var direction = 1
    private var timer: Timer?
    private var accumulator: TimeInterval = 0
    private var lastTick = ProcessInfo.processInfo.systemUptime

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        intensities[0] = 1
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    deinit { timer?.invalidate() }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(0.1, now - lastTick)
        lastTick = now
        accumulator += dt

        // The television scanner is closer to a row of lamps with incandescent
        // persistence than to a single glowing rectangle bouncing around.
        // Every frame all lamps decay, while the current lamp is driven hard.
        let decay = CGFloat(pow(0.018, dt))
        for index in intensities.indices {
            intensities[index] *= decay
            if intensities[index] < 0.015 { intensities[index] = 0 }
        }

        if accumulator >= 0.095 {
            accumulator -= 0.095
            headIndex += direction
            if headIndex >= lampCount - 1 {
                headIndex = lampCount - 1
                direction = -1
            } else if headIndex <= 0 {
                headIndex = 0
                direction = 1
            }
        }

        intensities[headIndex] = 1.0
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        let totalWidth = min(bounds.width - 20, 620)
        let gap: CGFloat = 4
        let lampWidth = (totalWidth - gap * CGFloat(lampCount - 1)) / CGFloat(lampCount)
        let startX = (bounds.width - totalWidth) / 2
        let lampHeight: CGFloat = 16
        let y = bounds.midY - lampHeight / 2

        for index in 0..<lampCount {
            let intensity = intensities[index]
            let x = startX + CGFloat(index) * (lampWidth + gap)

            // A very faint red glass remains visible even when a lamp is off.
            NSColor(calibratedRed: 0.06, green: 0.0, blue: 0.0, alpha: 1).setFill()
            NSRect(x: x, y: y, width: lampWidth, height: lampHeight).fill()

            guard intensity > 0 else { continue }

            let red = min(1.0, 0.18 + intensity * 0.92)
            let green = intensity > 0.82 ? (intensity - 0.82) * 0.55 : 0
            NSColor(calibratedRed: red, green: green, blue: 0.0, alpha: 1).setFill()
            NSRect(x: x, y: y + 1, width: lampWidth, height: lampHeight - 2).fill()

            if intensity > 0.75 {
                NSColor(calibratedRed: 1.0, green: 0.18, blue: 0.08, alpha: 0.9).setFill()
                NSRect(x: x + 2, y: y + 3, width: max(1, lampWidth - 4), height: lampHeight - 6).fill()
            }
        }
    }
}
