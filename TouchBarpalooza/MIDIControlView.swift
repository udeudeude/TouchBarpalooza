import AppKit
import CoreMIDI

final class MIDIControlView: NSView {
    private var midiClient = MIDIClientRef()
    private var outputPort = MIDIPortRef()
    private var destination = MIDIEndpointRef()
    private var sliders: [NSSlider] = []
    private var statusLabel = NSTextField(labelWithString: "MIDI")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupMIDI()
        buildUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMIDI()
        buildUI()
    }

    deinit {
        if outputPort != 0 { MIDIPortDispose(outputPort) }
        if midiClient != 0 { MIDIClientDispose(midiClient) }
    }

    private func setupMIDI() {
        MIDIClientCreate("TouchBarpalooza" as CFString, nil, nil, &midiClient)
        MIDIOutputPortCreate(midiClient, "TouchBarpalooza Out" as CFString, &outputPort)
        if MIDIGetNumberOfDestinations() > 0 {
            destination = MIDIGetDestination(0)
        }
    }

    private func buildUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        statusLabel.font = .monospacedSystemFont(ofSize: 8, weight: .medium)
        statusLabel.alignment = .center
        statusLabel.stringValue = destination == 0 ? "MIDI: none" : "MIDI"
        statusLabel.frame.size.width = 62
        stack.addArrangedSubview(statusLabel)

        let names = ["1", "2", "3", "4"]
        for index in 0..<4 {
            let container = NSView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 115).isActive = true

            let label = NSTextField(labelWithString: names[index])
            label.font = .monospacedSystemFont(ofSize: 7, weight: .bold)
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false

            let slider = NSSlider(value: 64, minValue: 0, maxValue: 127, target: self, action: #selector(sliderChanged(_:)))
            slider.tag = index
            slider.translatesAutoresizingMaskIntoConstraints = false
            sliders.append(slider)

            container.addSubview(label)
            container.addSubview(slider)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                label.widthAnchor.constraint(equalToConstant: 12),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                slider.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 2),
                slider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                slider.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
            stack.addArrangedSubview(container)
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let value = UInt8(max(0, min(127, Int(sender.doubleValue.rounded()))))
        sendCC(controller: UInt8(20 + sender.tag), value: value)
    }

    private func sendCC(controller: UInt8, value: UInt8) {
        guard destination != 0, outputPort != 0 else {
            statusLabel.stringValue = "MIDI: none"
            return
        }

        var packetList = MIDIPacketList()
        let packet = MIDIPacketListInit(&packetList)
        let bytes: [UInt8] = [0xB0, controller, value]
        let result: UnsafeMutablePointer<MIDIPacket>? = bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return nil }
            return MIDIPacketListAdd(
                &packetList,
                MemoryLayout<MIDIPacketList>.size,
                packet,
                0,
                buffer.count,
                base
            )
        }
        if result != nil {
            MIDISend(outputPort, destination, &packetList)
            statusLabel.stringValue = "CC\(controller) \(value)"
        }
    }
}
