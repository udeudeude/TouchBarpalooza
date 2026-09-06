import AppKit

final class KITTScannerView: NSView {
    private let lampCount = 8
    private var intensities = Array(repeating: CGFloat(0), count: 8)
    private var headIndex = 0
    private var direction = 1
    private var timer: Timer?
    private var accumulator: TimeInterval = 0
    private var lastTick = ProcessInfo.processInfo.systemUptime

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }

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

        // The original scanner used eight incandescent lamps. The active lamp
        // advances 1-2-3-4-5-6-7-8-7-6-5-4-3-2 without dwelling at either end,
        // while the previous lamps decay into a soft trailing glow.
        let decay = CGFloat(pow(0.026, dt))
        for index in intensities.indices {
            intensities[index] *= decay
            if intensities[index] < 0.012 { intensities[index] = 0 }
        }

        if accumulator >= 0.092 {
            accumulator -= 0.092
            headIndex += direction
            if headIndex >= lampCount - 1 {
                headIndex = lampCount - 1
                direction = -1
            } else if headIndex <= 0 {
                headIndex = 0
                direction = 1
            }
        }

        intensities[headIndex] = 1
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill(); dirtyRect.fill()

        let totalWidth = min(bounds.width - 10, 650)
        let gap: CGFloat = 3
        let lampWidth = (totalWidth - gap * CGFloat(lampCount - 1)) / CGFloat(lampCount)
        let startX = (bounds.width - totalWidth) / 2

        // On the car the scanner is a shallow slot, but on the Touch Bar the
        // whole display is effectively that slot. Filling almost the full OLED
        // height preserves the proportions of the individual lenses better.
        let lampHeight = max(18, bounds.height - 2)
        let y = (bounds.height - lampHeight) / 2

        for index in 0..<lampCount {
            let intensity = intensities[index]
            let x = startX + CGFloat(index) * (lampWidth + gap)

            NSColor(calibratedRed: 0.055, green: 0.0, blue: 0.0, alpha: 1).setFill()
            NSRect(x: x, y: y, width: lampWidth, height: lampHeight).fill()

            guard intensity > 0 else { continue }
            let red = min(1, 0.16 + intensity * 0.94)
            let green = intensity > 0.84 ? (intensity - 0.84) * 0.45 : 0
            NSColor(calibratedRed: red, green: green, blue: 0, alpha: 1).setFill()
            NSRect(x: x + 1, y: y + 1, width: max(1, lampWidth - 2), height: max(1, lampHeight - 2)).fill()

            if intensity > 0.80 {
                NSColor(calibratedRed: 1, green: 0.12, blue: 0.04, alpha: 0.9).setFill()
                NSRect(x: x + 3, y: y + 3, width: max(1, lampWidth - 6), height: max(1, lampHeight - 6)).fill()
            }
        }
    }
}
