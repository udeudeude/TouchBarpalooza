import AppKit

private extension NSTouchBarItem.Identifier {
    static let touchBarpaloozaTray = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.tray")
    static let touchBarpaloozaHome = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.home")

    static let touchBarpaloozaLemmings = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.lemmings")
    static let touchBarpaloozaClipboard = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.clipboard")
    static let touchBarpaloozaAudio = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.audio")
    static let touchBarpaloozaMIDI = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.midi")
    static let touchBarpaloozaGames = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.games")
    static let touchBarpaloozaKITT = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.kitt")

    static let lemmingsPlay = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.lemmings.play")
    static let lemmingsDemo = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.lemmings.demo")
    static let lemmingsControls = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.lemmings.controls")

    static let pong = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.games.pong")
    static let snake = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.games.snake")
    static let breakout = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.games.breakout")
    static let life = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.games.life")

    static let content = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.content")
}

final class GlobalTouchBarController: NSObject, NSTouchBarDelegate {
    private enum Mode {
        case home
        case lemmingsMenu
        case lemmingsPlay
        case lemmingsDemo
        case clipboard
        case audio
        case midi
        case gamesMenu
        case pong
        case snake
        case breakout
        case life
        case kitt
    }

    private var mode: Mode = .home
    private var touchBar = NSTouchBar()
    private var trayItem: NSCustomTouchBarItem?
    private var isStarted = false
    private weak var currentLemmingsView: LemmingsView?

    func start() {
        guard !isStarted else { return }
        isStarted = true

        DFRSystemModalShowsCloseBoxWhenFrontMost(false)

        let trayItem = NSCustomTouchBarItem(identifier: .touchBarpaloozaTray)
        let trayButton = NSButton(title: "TP", target: self, action: #selector(presentCurrentBar))
        trayButton.toolTip = "Show TouchBarpalooza"
        trayItem.view = trayButton
        self.trayItem = trayItem

        NSTouchBarItem.addSystemTrayItem(trayItem)
        DFRElementSetControlStripPresenceForIdentifier(.touchBarpaloozaTray, true)

        rebuildAndPresent()
    }

    func stop() {
        guard isStarted else { return }
        NSTouchBar.dismissSystemModalTouchBar(touchBar)
        DFRElementSetControlStripPresenceForIdentifier(.touchBarpaloozaTray, false)
        if let trayItem { NSTouchBarItem.removeSystemTrayItem(trayItem) }
        trayItem = nil
        isStarted = false
    }

    private func rebuildAndPresent() {
        currentLemmingsView = nil
        let bar = NSTouchBar()
        bar.delegate = self

        switch mode {
        case .home:
            bar.defaultItemIdentifiers = [
                .touchBarpaloozaLemmings,
                .touchBarpaloozaClipboard,
                .touchBarpaloozaAudio,
                .touchBarpaloozaMIDI,
                .touchBarpaloozaGames,
                .touchBarpaloozaKITT
            ]

        case .lemmingsMenu:
            bar.escapeKeyReplacementItemIdentifier = .touchBarpaloozaHome
            bar.defaultItemIdentifiers = [.lemmingsPlay, .lemmingsDemo]

        case .lemmingsPlay:
            bar.escapeKeyReplacementItemIdentifier = .touchBarpaloozaHome
            bar.defaultItemIdentifiers = [.lemmingsControls, .content]

        case .lemmingsDemo:
            bar.escapeKeyReplacementItemIdentifier = .touchBarpaloozaHome
            bar.defaultItemIdentifiers = [.content]

        case .gamesMenu:
            bar.escapeKeyReplacementItemIdentifier = .touchBarpaloozaHome
            bar.defaultItemIdentifiers = [.pong, .snake, .breakout, .life]

        case .clipboard, .audio, .midi, .pong, .snake, .breakout, .life, .kitt:
            bar.escapeKeyReplacementItemIdentifier = .touchBarpaloozaHome
            bar.defaultItemIdentifiers = [.content]
        }

        touchBar = bar
        presentCurrentBar()
    }

    @objc private func presentCurrentBar() {
        guard isStarted else { return }
        NSTouchBar.presentSystemModalTouchBar(touchBar, systemTrayItemIdentifier: .touchBarpaloozaTray)
        DFRElementSetControlStripPresenceForIdentifier(.touchBarpaloozaTray, true)
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .touchBarpaloozaHome:
            return buttonItem(identifier: identifier, title: "⌂", action: #selector(showHome))

        case .touchBarpaloozaLemmings:
            return buttonItem(identifier: identifier, title: "Lemmings", action: #selector(showLemmingsMenu))
        case .touchBarpaloozaClipboard:
            return buttonItem(identifier: identifier, title: "Clipboard", action: #selector(showClipboard))
        case .touchBarpaloozaAudio:
            return buttonItem(identifier: identifier, title: "Audio", action: #selector(showAudio))
        case .touchBarpaloozaMIDI:
            return buttonItem(identifier: identifier, title: "MIDI", action: #selector(showMIDI))
        case .touchBarpaloozaGames:
            return buttonItem(identifier: identifier, title: "Games", action: #selector(showGames))
        case .touchBarpaloozaKITT:
            return buttonItem(identifier: identifier, title: "KITT", action: #selector(showKITT))

        case .lemmingsPlay:
            return buttonItem(identifier: identifier, title: "PLAY", action: #selector(startLemmingsPlay))
        case .lemmingsDemo:
            return buttonItem(identifier: identifier, title: "DEMO", action: #selector(startLemmingsDemo))
        case .lemmingsControls:
            return lemmingsControlItem(identifier: identifier)

        case .pong:
            return buttonItem(identifier: identifier, title: "Pong", action: #selector(showPong))
        case .snake:
            return buttonItem(identifier: identifier, title: "Snake", action: #selector(showSnake))
        case .breakout:
            return buttonItem(identifier: identifier, title: "Breakout", action: #selector(showBreakout))
        case .life:
            return buttonItem(identifier: identifier, title: "Life", action: #selector(showLife))

        case .content:
            return contentItem(identifier: identifier)

        default:
            return nil
        }
    }

    private func contentItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let frame = NSRect(x: 0, y: 0, width: 900, height: 30)
        let view: NSView

        switch mode {
        case .lemmingsPlay:
            let game = LemmingsView(frame: frame, mode: .interactive)
            currentLemmingsView = game
            view = game
        case .lemmingsDemo:
            let game = LemmingsView(frame: frame, mode: .demo)
            currentLemmingsView = game
            view = game
        case .clipboard:
            view = ClipboardShelfView(frame: frame)
        case .audio:
            view = AudioVisualizerView(frame: frame)
        case .midi:
            view = MIDIControlView(frame: frame)
        case .pong:
            view = MiniGameView(frame: frame, game: .pong)
        case .snake:
            view = MiniGameView(frame: frame, game: .snake)
        case .breakout:
            view = MiniGameView(frame: frame, game: .breakout)
        case .life:
            view = MiniGameView(frame: frame, game: .life)
        case .kitt:
            view = KITTScannerView(frame: frame)
        default:
            view = NSView(frame: frame)
        }

        view.autoresizingMask = [.width, .height]
        item.view = view
        return item
    }

    private func lemmingsControlItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 3
        stack.frame = NSRect(x: 0, y: 0, width: 390, height: 30)

        let skillControl = NSSegmentedControl(
            labels: LemmingsView.Skill.allCases.map { $0.shortName },
            trackingMode: .selectOne,
            target: self,
            action: #selector(skillChanged(_:))
        )
        skillControl.selectedSegment = LemmingsView.Skill.builder.rawValue
        skillControl.font = .monospacedSystemFont(ofSize: 7, weight: .medium)
        stack.addArrangedSubview(skillControl)

        stack.addArrangedSubview(compactButton("⏯", #selector(toggleLemmingsPause)))
        stack.addArrangedSubview(compactButton("−", #selector(releaseSlower)))
        stack.addArrangedSubview(compactButton("+", #selector(releaseFaster)))
        stack.addArrangedSubview(compactButton("☠", #selector(nukeLemmings)))

        item.view = stack
        return item
    }

    private func compactButton(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.font = .systemFont(ofSize: 9)
        return button
    }

    private func buttonItem(identifier: NSTouchBarItem.Identifier, title: String, action: Selector) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.view = NSButton(title: title, target: self, action: action)
        return item
    }

    @objc private func skillChanged(_ sender: NSSegmentedControl) {
        guard let skill = LemmingsView.Skill(rawValue: sender.selectedSegment) else { return }
        currentLemmingsView?.selectSkill(skill)
    }

    @objc private func toggleLemmingsPause() { currentLemmingsView?.togglePause() }
    @objc private func releaseSlower() { currentLemmingsView?.adjustReleaseRate(by: -10) }
    @objc private func releaseFaster() { currentLemmingsView?.adjustReleaseRate(by: 10) }
    @objc private func nukeLemmings() { currentLemmingsView?.nuke() }

    @objc private func showHome() { mode = .home; rebuildAndPresent() }
    @objc private func showLemmingsMenu() { mode = .lemmingsMenu; rebuildAndPresent() }
    @objc private func startLemmingsPlay() { mode = .lemmingsPlay; rebuildAndPresent() }
    @objc private func startLemmingsDemo() { mode = .lemmingsDemo; rebuildAndPresent() }
    @objc private func showClipboard() { mode = .clipboard; rebuildAndPresent() }
    @objc private func showAudio() { mode = .audio; rebuildAndPresent() }
    @objc private func showMIDI() { mode = .midi; rebuildAndPresent() }
    @objc private func showGames() { mode = .gamesMenu; rebuildAndPresent() }
    @objc private func showPong() { mode = .pong; rebuildAndPresent() }
    @objc private func showSnake() { mode = .snake; rebuildAndPresent() }
    @objc private func showBreakout() { mode = .breakout; rebuildAndPresent() }
    @objc private func showLife() { mode = .life; rebuildAndPresent() }
    @objc private func showKITT() { mode = .kitt; rebuildAndPresent() }
}
