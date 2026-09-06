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

        // A longer analysis window makes bass information much more useful.
        // 4096 frames is still responsive on a Touch Bar, but gives several
        // cycles even for ordinary bass notes instead of strongly favoring
        // whistles and other high-frequency sounds.
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.analyze(buffer: buffer, sampleRate: format.sampleRate)
        }

        do {
            engine.prepare()
            try engine.start()
            status = "MIC"
        } catch {
            status = "SPECTRUM ERROR"
        }
    }

    private func analyze(buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let count = min(Int(buffer.frameLength), 4096)
        guard count > 128 else { return }

        var mean: Double = 0
        for i in 0..<count { mean += Double(channel[i]) }
        mean /= Double(count)

        var sum: Double = 0
        for i in 0..<count {
            let sample = Double(channel[i]) - mean
            sum += sample * sample
        }
        let rms = sqrt(sum / Double(count))
        let rmsDB = 20.0 * log10(max(rms, 0.000001))
        let newLevel = CGFloat(min(1, max(0, (rmsDB + 62.0) / 56.0)))

        // Logarithmic centers from roughly 38 Hz through the upper treble.
        // Each center uses a Hann-windowed single-frequency DFT. The longer
        // window plus a mild bass compensation gives low notes enough visual
        // weight without making room rumble dominate the display.
        let minimumFrequency = 38.0
        let maximumFrequency = min(15000.0, sampleRate * 0.44)
        let ratio = pow(maximumFrequency / minimumFrequency, 1.0 / Double(spectrum.count - 1))
        var newSpectrum = Array(repeating: CGFloat(0), count: spectrum.count)

        for band in newSpectrum.indices {
            let frequency = minimumFrequency * pow(ratio, Double(band))
            let angular = 2.0 * Double.pi * frequency / sampleRate
            var real = 0.0
            var imag = 0.0

            for i in 0..<count {
                let window = 0.5 - 0.5 * cos(2.0 * Double.pi * Double(i) / Double(count - 1))
                let sample = (Double(channel[i]) - mean) * window
                let phase = angular * Double(i)
                real += sample * cos(phase)
                imag -= sample * sin(phase)
            }

            let magnitude = (2.0 * sqrt(real * real + imag * imag)) / Double(count)
            let db = 20.0 * log10(max(magnitude, 0.0000001))
            var normalized = min(1.0, max(0.0, (db + 72.0) / 54.0))

            if frequency < 180 {
                let bassBoost = 1.0 + (180.0 - frequency) / 360.0
                normalized = min(1.0, normalized * bassBoost)
            }
            newSpectrum[band] = CGFloat(normalized)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.level = self.level * 0.58 + newLevel * 0.42
            for index in self.spectrum.indices {
                self.spectrum[index] = max(newSpectrum[index], self.spectrum[index] * 0.72)
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()

        let meterWidth: CGFloat = 105
        let meterRect = NSRect(x: 4, y: 5, width: meterWidth - 12, height: 13)
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
        status.draw(at: NSPoint(x: 5, y: 20), withAttributes: attrs)

        let startX = meterWidth + 4
        let available = max(10, bounds.width - startX - 4)
        let gap: CGFloat = 2
        let barWidth = max(2, (available - gap * CGFloat(spectrum.count - 1)) / CGFloat(spectrum.count))
        let baseline: CGFloat = 1
        let maximumHeight = max(3, bounds.height - baseline - 2)

        for (index, value) in spectrum.enumerated() {
            let height = max(1, value * maximumHeight)
            let x = startX + CGFloat(index) * (barWidth + gap)
            NSColor(calibratedRed: 0.16 + 0.55 * value, green: 0.35 + 0.45 * value, blue: 0.95, alpha: 1).setFill()
            // AppKit's origin is at the bottom here, so anchoring at y=1
            // makes the spectrum grow upward instead of hanging from the top.
            NSRect(x: x, y: baseline, width: barWidth, height: height).fill()
        }
    }
}
