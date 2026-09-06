import AppKit

final class KITTScannerView: NSView {
    private var position: CGFloat = 0
    private var direction: CGFloat = 1
    private var timer: Timer?

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
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    deinit { timer?.invalidate() }

    private func tick() {
        let edge = max(1, bounds.width - 24)
        position += direction * 7.0
        if position >= edge {
            position = edge
            direction = -1
        } else if position <= 0 {
            position = 0
            direction = 1
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        let centerY = bounds.midY
        let segments = 16
        let segmentWidth: CGFloat = 15
        for i in 0..<segments {
            let x = position + CGFloat(i - segments / 2) * segmentWidth
            guard x > -segmentWidth && x < bounds.width else { continue }
            let distance = abs(CGFloat(i - segments / 2)) / CGFloat(segments / 2)
            let intensity = max(0.03, 1.0 - distance)
            NSColor(calibratedRed: intensity, green: 0.0, blue: 0.0, alpha: 1).setFill()
            NSRect(x: x, y: centerY - 7, width: segmentWidth - 2, height: 14).fill()
        }

        NSColor(calibratedRed: 1, green: 0.12, blue: 0.12, alpha: 1).setFill()
        NSRect(x: position + CGFloat(segments / 2) * segmentWidth - 2, y: centerY - 9, width: 4, height: 18).fill()
    }
}
