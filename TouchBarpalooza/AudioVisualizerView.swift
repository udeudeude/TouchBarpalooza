import AppKit
import AVFoundation

final class AudioVisualizerView: NSView {
    private let engine = AVAudioEngine()
    private var level: CGFloat = 0
    private var spectrum = Array(repeating: CGFloat(0), count: 20)
    private var displayTimer: Timer?
    private var status = "MIC"

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        startDisplayTimer()
        requestAndStartAudio()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        startDisplayTimer()
        requestAndStartAudio()
    }

    deinit {
        displayTimer?.invalidate()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    private func startDisplayTimer() {
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.needsDisplay = true }
        displayTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func requestAndStartAudio() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted {
                    self.startAudio()
                } else {
                    self.status = "MIC PERMISSION"
                }
            }
        }
    }

    private func startAudio() {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            status = "NO INPUT"
            return
        }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.analyze(buffer: buffer, sampleRate: format.sampleRate)
        }

        do {
            engine.prepare()
            try engine.start()
            status = "MIC"
        } catch {
            status = "AUDIO ERROR"
        }
    }

    private func analyze(buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let count = min(Int(buffer.frameLength), 1024)
        guard count > 16 else { return }

        var sum: Float = 0
        for i in 0..<count { sum += channel[i] * channel[i] }
        let rms = sqrt(sum / Float(count))
        let newLevel = CGFloat(min(1, max(0, (20 * log10(max(rms, 0.00001)) + 60) / 60)))

        var newSpectrum = Array(repeating: CGFloat(0), count: spectrum.count)
        for band in newSpectrum.indices {
            let frequency = min(sampleRate * 0.45, 55.0 * pow(1.34, Double(band)))
            let angular = 2.0 * Double.pi * frequency / sampleRate
            var real = 0.0
            var imag = 0.0
            for i in 0..<count {
                let sample = Double(channel[i])
                let phase = angular * Double(i)
                real += sample * cos(phase)
                imag -= sample * sin(phase)
            }
            let magnitude = sqrt(real * real + imag * imag) / Double(count)
            newSpectrum[band] = CGFloat(min(1, magnitude * 18.0))
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.level = self.level * 0.60 + newLevel * 0.40
            for index in self.spectrum.indices {
                self.spectrum[index] = max(newSpectrum[index], self.spectrum[index] * 0.78)
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        let meterWidth: CGFloat = 105
        let meterRect = NSRect(x: 4, y: 8, width: meterWidth - 12, height: 14)
        NSColor(calibratedWhite: 0.15, alpha: 1).setFill()
        meterRect.fill()

        let activeWidth = meterRect.width * level
        NSColor(calibratedRed: 0.15, green: 0.85, blue: 0.28, alpha: 1).setFill()
        NSRect(x: meterRect.minX, y: meterRect.minY, width: activeWidth * 0.72, height: meterRect.height).fill()
        if level > 0.72 {
            NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.08, alpha: 1).setFill()
            NSRect(x: meterRect.minX + meterRect.width * 0.72, y: meterRect.minY, width: max(0, activeWidth - meterRect.width * 0.72), height: meterRect.height).fill()
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 7, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.78, alpha: 1)
        ]
        status.draw(at: NSPoint(x: 5, y: 1), withAttributes: attrs)

        let startX = meterWidth + 4
        let available = max(10, bounds.width - startX - 4)
        let gap: CGFloat = 2
        let barWidth = max(2, (available - gap * CGFloat(spectrum.count - 1)) / CGFloat(spectrum.count))
        for (index, value) in spectrum.enumerated() {
            let height = max(1, value * 25)
            let x = startX + CGFloat(index) * (barWidth + gap)
            NSColor(calibratedRed: 0.16 + 0.55 * value, green: 0.35 + 0.45 * value, blue: 0.95, alpha: 1).setFill()
            NSRect(x: x, y: bounds.height - height, width: barWidth, height: height).fill()
        }
    }
}
