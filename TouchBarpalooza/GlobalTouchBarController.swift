import AppKit
import CoreGraphics

private extension NSTouchBarItem.Identifier {
    static let touchBarpaloozaTray = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.tray")
    static let touchBarpaloozaForegroundClose = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.foregroundClose")
    static let touchBarpaloozaHome = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.home")

    static let touchBarpaloozaLemmings = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.lemmings")
    static let touchBarpaloozaClipboard = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.clipboard")
    static let touchBarpaloozaAudio = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.audio")
    static let touchBarpaloozaMIDI = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.midi")
    static let touchBarpaloozaGames = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.games")
    static let touchBarpaloozaSavers = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.savers")
    static let touchBarpaloozaKITT = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.kitt")
    static let touchBarpaloozaTokiPona = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.tokipona")
    static let touchBarpaloozaPond = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.pond")

    static let lemmingsPlay = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.lemmings.play")
    static let lemmingsDemo = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.lemmings.demo")
    static let lemmingsControls = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.lemmings.controls")

    static let gamesCompact = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.games.compact")
    static let saversCompact = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.savers.compact")
    static let homeCompact = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.home.compact")
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
        case saversMenu
        case pong
        case snake
        case breakout
        case life
        case pitfall
        case et
        case mario
        case adventure
        case dvdSaver
        case pipesSaver
        case toastersSaver
        case kitt
        case tokiPona
        case pond
    }

    private var mode: Mode = .home
    private var touchBar = NSTouchBar()
    private var trayItem: NSCustomTouchBarItem?
    private var isStarted = false
    private var activationObservers: [NSObjectProtocol] = []
    private weak var currentLemmingsView: LemmingsView?
    private var lemmingsSkillButtons: [NSButton] = []

    func start() {
        guard !isStarted else { return }
        isStarted = true
        DFRSystemModalShowsCloseBoxWhenFrontMost(true)

        let trayItem = NSCustomTouchBarItem(identifier: .touchBarpaloozaTray)
        let trayButton = NSButton(title: "⌂", target: self, action: #selector(presentCurrentBar))
        trayButton.toolTip = "Show TouchBarpalooza"
        trayItem.view = trayButton
        self.trayItem = trayItem

        NSTouchBarItem.addSystemTrayItem(trayItem)
        DFRElementSetControlStripPresenceForIdentifier(.touchBarpaloozaTray, true)

        let center = NotificationCenter.default
        activationObservers = [
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: NSApp,
                queue: .main
            ) { [weak self] _ in
                self?.rebuildAndPresent()
            },
            center.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: NSApp,
                queue: .main
            ) { [weak self] _ in
                self?.rebuildAndPresent()
            }
        ]

        rebuildAndPresent()
    }

    func showTouchBar() {
        presentCurrentBar()
    }

    func stop() {
        guard isStarted else { return }
        NSTouchBar.dismissSystemModalTouchBar(touchBar)
        DFRElementSetControlStripPresenceForIdentifier(.touchBarpaloozaTray, false)
        if let trayItem {
            NSTouchBarItem.removeSystemTrayItem(trayItem)
        }
        trayItem = nil

        for observer in activationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        activationObservers.removeAll()

        isStarted = false
    }

    private func rebuildAndPresent() {
        currentLemmingsView = nil
        lemmingsSkillButtons.removeAll()

        let bar = NSTouchBar()
        bar.delegate = self
        // When another app is frontmost, macOS supplies the native system-
        // modal X. When TouchBarpalooza itself is frontmost that native X
        // disappears, so occupy the special left slot with our own dismiss
        // button only for that state.
        bar.escapeKeyReplacementItemIdentifier = NSApp.isActive
            ? .touchBarpaloozaForegroundClose
            : nil

        switch mode {
        case .home:
            // Treat the launcher as one compact item so macOS cannot evict the
            // last button (Pond) when it inserts the native modal close box.
            bar.defaultItemIdentifiers = [.homeCompact]
        case .lemmingsMenu:
            bar.defaultItemIdentifiers = [.touchBarpaloozaHome, .lemmingsPlay, .lemmingsDemo]
        case .lemmingsPlay:
            bar.defaultItemIdentifiers = [.touchBarpaloozaHome, .lemmingsControls, .content]
        case .lemmingsDemo:
            bar.defaultItemIdentifiers = [.touchBarpaloozaHome, .content]
        case .gamesMenu:
            // Keep navigation and all game buttons inside one host item. If Home
            // is a separate item, macOS may evict the entire games item once the
            // native modal close box and Control Strip are accounted for.
            bar.defaultItemIdentifiers = [.gamesCompact]
        case .saversMenu:
            bar.defaultItemIdentifiers = [.saversCompact]
        case .clipboard, .audio, .midi, .pong, .snake, .breakout, .life,
             .pitfall, .et, .mario, .adventure, .dvdSaver, .pipesSaver,
             .toastersSaver, .kitt, .tokiPona, .pond:
            bar.defaultItemIdentifiers = [.touchBarpaloozaHome, .content]
        }

        // The private presenter stacks system-modal bars. Dismiss the current
        // layer before replacing it, otherwise every navigation tap adds another
        // layer and the native close box has to be tapped once per layer.
        NSTouchBar.dismissSystemModalTouchBar(touchBar)
        touchBar = bar
        presentCurrentBar()
    }

    @objc private func presentCurrentBar() {
        guard isStarted else { return }

        // Re-presenting an already visible bar stacks another modal layer too.
        // Normalize to exactly one layer whether this came from navigation or
        // the Control Strip launcher.
        NSTouchBar.dismissSystemModalTouchBar(touchBar)
        NSTouchBar.presentSystemModalTouchBar(
            touchBar,
            systemTrayItemIdentifier: .touchBarpaloozaTray
        )
        DFRElementSetControlStripPresenceForIdentifier(.touchBarpaloozaTray, true)
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        switch identifier {
        case .touchBarpaloozaForegroundClose:
            let item = buttonItem(
                identifier: identifier,
                title: "×",
                action: #selector(dismissForRealEscape)
            )
            item.visibilityPriority = .high
            item.view.toolTip = "Close TouchBarpalooza and reveal the normal Touch Bar"
            return item
        case .touchBarpaloozaHome:
            let item = buttonItem(identifier: identifier, title: "⌂", action: #selector(showHome))
            item.visibilityPriority = .high
            return item
        case .touchBarpaloozaLemmings:
            return buttonItem(identifier: identifier, title: "Lemmings", action: #selector(showLemmingsMenu))
        case .touchBarpaloozaClipboard:
            return buttonItem(identifier: identifier, title: "Clipboard", action: #selector(showClipboard))
        case .touchBarpaloozaAudio:
            return buttonItem(identifier: identifier, title: "Spectrum", action: #selector(showAudio))
        case .touchBarpaloozaMIDI:
            return buttonItem(identifier: identifier, title: "MIDI", action: #selector(showMIDI))
        case .touchBarpaloozaGames:
            return buttonItem(identifier: identifier, title: "Games", action: #selector(showGames))
        case .touchBarpaloozaSavers:
            return buttonItem(identifier: identifier, title: "Savers", action: #selector(showSavers))
        case .touchBarpaloozaKITT:
            return buttonItem(identifier: identifier, title: "KITT", action: #selector(showKITT))
        case .touchBarpaloozaTokiPona:
            return buttonItem(identifier: identifier, title: "Toki Pona", action: #selector(showTokiPona))
        case .touchBarpaloozaPond:
            return buttonItem(identifier: identifier, title: "Pond", action: #selector(showPond))
        case .lemmingsPlay:
            return buttonItem(identifier: identifier, title: "PLAY", action: #selector(startLemmingsPlay))
        case .lemmingsDemo:
            return buttonItem(identifier: identifier, title: "DEMO", action: #selector(startLemmingsDemo))
        case .lemmingsControls:
            return lemmingsControlItem(identifier: identifier)
        case .gamesCompact:
            return gamesMenuItem(identifier: identifier)
        case .saversCompact:
            return saversMenuItem(identifier: identifier)
        case .homeCompact:
            return homeMenuItem(identifier: identifier)
        case .content:
            return contentItem(identifier: identifier)
        default:
            return nil
        }
    }

    private func homeMenuItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let host = FixedTouchBarView(size: NSSize(width: 650, height: 30))
        let stack = NSStackView(frame: host.bounds)
        stack.orientation = .horizontal
        stack.spacing = 2
        stack.distribution = .fillEqually
        stack.autoresizingMask = [.width, .height]

        let specs: [(String, Selector)] = [
            ("Clipboard", #selector(showClipboard)),
            ("Spectrum", #selector(showAudio)),
            ("MIDI", #selector(showMIDI)),
            ("Games", #selector(showGames)),
            ("Savers", #selector(showSavers)),
            ("KITT", #selector(showKITT)),
            ("Toki Pona", #selector(showTokiPona)),
            ("Pond", #selector(showPond))
        ]

        for (title, action) in specs {
            let button = NSButton(title: title, target: self, action: action)
            button.font = .systemFont(ofSize: 10)
            stack.addArrangedSubview(button)
        }

        host.addSubview(stack)
        item.view = host
        item.visibilityPriority = .high
        return item
    }

    private func preferredContentWidth() -> CGFloat {
        switch mode {
        case .lemmingsPlay:
            return 350
        case .clipboard, .midi:
            return 690
        case .dvdSaver, .pipesSaver, .toastersSaver, .mario:
            return 660
        default:
            return 700
        }
    }

    private func contentItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let width = preferredContentWidth()
        let frame = NSRect(x: 0, y: 0, width: width, height: 30)
        let content: NSView

        switch mode {
        case .lemmingsPlay:
            let view = LemmingsView(frame: frame, mode: .interactive)
            currentLemmingsView = view
            content = view
        case .lemmingsDemo:
            let view = LemmingsView(frame: frame, mode: .demo)
            currentLemmingsView = view
            content = view
        case .clipboard:
            content = ClipboardShelfView(frame: frame)
        case .audio:
            content = AudioVisualizerView(frame: frame)
        case .midi:
            content = MIDIControlView(frame: frame)
        case .pong:
            content = MiniGameView(frame: frame, game: .pong)
        case .snake:
            content = MiniGameView(frame: frame, game: .snake)
        case .breakout:
            content = MiniGameView(frame: frame, game: .breakout)
        case .life:
            content = LifeGameViewV4(frame: frame)
        case .pitfall:
            content = PitfallGameViewV3(frame: frame)
        case .et:
            content = ETPixelGameViewV4(frame: frame)
        case .mario:
            content = TouchBarPlatformerView(frame: frame)
        case .adventure:
            content = AdventureTerminalViewV2(frame: frame)
        case .dvdSaver:
            content = DVDBounceSaverView(frame: frame)
        case .pipesSaver:
            content = PipesSaverView(frame: frame)
        case .toastersSaver:
            content = FlyingToastersSaverView(frame: frame)
        case .kitt:
            content = KITTScannerView(frame: frame)
        case .tokiPona:
            content = TokiPonaStudyView(frame: frame)
        case .pond:
            content = KoiPondView(frame: frame)
        default:
            content = NSView(frame: frame)
        }

        item.view = TouchBarContentHostView(content: content, preferredWidth: width)
        item.visibilityPriority = mode == .lemmingsPlay ? .normal : .high
        return item
    }

    private func lemmingsControlItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let view = FixedTouchBarView(size: NSSize(width: 236, height: 30))
        lemmingsSkillButtons.removeAll()

        var x: CGFloat = 0
        for skill in LemmingsView.Skill.allCases {
            let button = NSButton(frame: NSRect(x: x, y: 2, width: 26, height: 26))
            button.target = self
            button.action = #selector(skillButtonPressed(_:))
            button.tag = skill.rawValue
            button.image = skillIcon(for: skill)
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = skill.shortName
            button.setButtonType(.toggle)
            button.state = skill == .builder ? .on : .off
            view.addSubview(button)
            lemmingsSkillButtons.append(button)
            x += 26
        }

        let nuke = NSButton(title: "☠", target: self, action: #selector(nukeLemmings))
        nuke.font = .systemFont(ofSize: 11)
        nuke.frame = NSRect(x: x + 2, y: 2, width: 24, height: 26)
        nuke.toolTip = "Nuke"
        view.addSubview(nuke)

        item.view = view
        item.visibilityPriority = .high
        return item
    }

    private func skillIcon(for skill: LemmingsView.Skill) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        return NSImage(size: size, flipped: false) { _ in
            NSGraphicsContext.current?.imageInterpolation = .none

            let hair = NSColor(calibratedRed: 0.18, green: 0.98, blue: 0.18, alpha: 1)
            let skin = NSColor(calibratedRed: 0.98, green: 0.76, blue: 0.58, alpha: 1)
            let blue = NSColor(calibratedRed: 0.10, green: 0.35, blue: 0.98, alpha: 1)
            let tool = NSColor(calibratedWhite: 0.92, alpha: 1)

            hair.setFill()
            NSRect(x: 8, y: 15, width: 7, height: 4).fill()
            skin.setFill()
            NSRect(x: 9, y: 12, width: 5, height: 4).fill()
            blue.setFill()
            NSRect(x: 8, y: 7, width: 7, height: 6).fill()
            skin.setFill()
            NSRect(x: 7, y: 2, width: 3, height: 6).fill()
            NSRect(x: 13, y: 2, width: 3, height: 6).fill()

            tool.setFill()
            tool.setStroke()

            switch skill {
            case .climber:
                NSRect(x: 18, y: 2, width: 2, height: 18).fill()
                NSRect(x: 14, y: 12, width: 5, height: 2).fill()
            case .floater:
                let umbrella = NSBezierPath()
                umbrella.move(to: NSPoint(x: 3, y: 18))
                umbrella.curve(
                    to: NSPoint(x: 20, y: 18),
                    controlPoint1: NSPoint(x: 7, y: 23),
                    controlPoint2: NSPoint(x: 16, y: 23)
                )
                umbrella.lineWidth = 1.5
                umbrella.stroke()
                NSRect(x: 11, y: 13, width: 1.5, height: 6).fill()
            case .bomber:
                NSColor(calibratedRed: 0.95, green: 0.2, blue: 0.08, alpha: 1).setFill()
                NSBezierPath(ovalIn: NSRect(x: 15, y: 8, width: 6, height: 6)).fill()
                NSRect(x: 18, y: 14, width: 1, height: 3).fill()
            case .blocker:
                skin.setFill()
                NSRect(x: 2, y: 10, width: 7, height: 2).fill()
                NSRect(x: 14, y: 10, width: 7, height: 2).fill()
            case .builder:
                NSColor(calibratedRed: 0.9, green: 0.64, blue: 0.18, alpha: 1).setFill()
                NSRect(x: 15, y: 7, width: 6, height: 2).fill()
                NSRect(x: 17, y: 9, width: 5, height: 2).fill()
                NSRect(x: 19, y: 11, width: 3, height: 2).fill()
            case .basher:
                NSRect(x: 15, y: 11, width: 7, height: 2).fill()
                NSRect(x: 20, y: 7, width: 2, height: 10).fill()
            case .miner:
                let pick = NSBezierPath()
                pick.move(to: NSPoint(x: 14, y: 12))
                pick.line(to: NSPoint(x: 20, y: 4))
                pick.lineWidth = 1.8
                pick.stroke()
                NSRect(x: 16, y: 12, width: 5, height: 1.5).fill()
            case .digger:
                NSRect(x: 11, y: 0, width: 2, height: 7).fill()
                NSRect(x: 8, y: 0, width: 8, height: 2).fill()
            }

            return true
        }
    }

    private func gamesMenuItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)

        // Use explicit compact widths instead of equal-width stack cells. The
        // standard Touch Bar button chrome has generous horizontal insets, so
        // equal distribution wastes enough room to clip the final game.
        let specs: [(String, CGFloat, Selector)] = [
            ("⌂", 32, #selector(showHome)),
            ("Life", 44, #selector(showLife)),
            ("Pong", 48, #selector(showPong)),
            ("Cave", 48, #selector(showAdventure)),
            ("Break", 50, #selector(showBreakout)),
            ("Snake", 52, #selector(showSnake)),
            ("Pit", 38, #selector(showPitfall)),
            ("E.T.", 40, #selector(showET)),
            ("Mario", 50, #selector(showMario)),
            ("Lemmings", 66, #selector(showLemmingsMenu))
        ]

        let spacing: CGFloat = 2
        let totalWidth = specs.reduce(CGFloat.zero) { $0 + $1.1 }
            + spacing * CGFloat(specs.count - 1)
        let host = FixedTouchBarView(size: NSSize(width: totalWidth, height: 30))

        var x: CGFloat = 0
        for (title, width, action) in specs {
            let button = NSButton(
                frame: NSRect(x: x, y: 1, width: width, height: 28)
            )
            button.title = title
            button.target = self
            button.action = action
            button.controlSize = .mini
            button.font = .systemFont(ofSize: title == "⌂" ? 11 : 8)
            host.addSubview(button)
            x += width + spacing
        }

        item.view = host
        item.visibilityPriority = .high
        return item
    }

    private func saversMenuItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let host = FixedTouchBarView(size: NSSize(width: 320, height: 30))
        let stack = NSStackView(frame: host.bounds)
        stack.orientation = .horizontal
        stack.spacing = 2
        stack.distribution = .fillEqually
        stack.autoresizingMask = [.width, .height]

        let specs: [(String, Selector)] = [
            ("⌂", #selector(showHome)),
            ("DVD", #selector(showDVD)),
            ("Pipes", #selector(showPipes)),
            ("Toasters", #selector(showToasters))
        ]

        for (title, action) in specs {
            let button = NSButton(title: title, target: self, action: action)
            button.font = .systemFont(ofSize: title == "⌂" ? 12 : 8)
            stack.addArrangedSubview(button)
        }

        host.addSubview(stack)
        item.view = host
        item.visibilityPriority = .high
        return item
    }

    private func buttonItem(
        identifier: NSTouchBarItem.Identifier,
        title: String,
        action: Selector
    ) -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let button = NSButton(title: title, target: self, action: action)

        let compactWidth: CGFloat?
        switch identifier {
        case .touchBarpaloozaForegroundClose:
            compactWidth = 34
        case .touchBarpaloozaHome:
            compactWidth = 28
        default:
            compactWidth = nil
        }

        if let compactWidth {
            let host = FixedTouchBarView(size: NSSize(width: compactWidth, height: 30))
            button.frame = NSRect(x: 0, y: 1, width: compactWidth, height: 28)
            button.font = .systemFont(ofSize: 13)
            host.addSubview(button)
            item.view = host
        } else {
            item.view = button
        }
        return item
    }

    @objc private func dismissForRealEscape() {
        NSTouchBar.dismissSystemModalTouchBar(touchBar)

        // Keep the Control Strip launcher available so the persistent bar can
        // be restored with one tap after using the real system Escape key.
        DFRElementSetControlStripPresenceForIdentifier(.touchBarpaloozaTray, true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard self?.isStarted == true else { return }
            DFRElementSetControlStripPresenceForIdentifier(.touchBarpaloozaTray, true)
        }
    }

    @objc private func skillButtonPressed(_ sender: NSButton) {
        guard let skill = LemmingsView.Skill(rawValue: sender.tag) else { return }
        for button in lemmingsSkillButtons {
            button.state = button === sender ? .on : .off
        }
        currentLemmingsView?.selectSkill(skill)
    }

    @objc private func nukeLemmings() {
        currentLemmingsView?.nuke()
    }

    @objc private func showHome() { mode = .home; rebuildAndPresent() }
    @objc private func showLemmingsMenu() { mode = .lemmingsMenu; rebuildAndPresent() }
    @objc private func startLemmingsPlay() { mode = .lemmingsPlay; rebuildAndPresent() }
    @objc private func startLemmingsDemo() { mode = .lemmingsDemo; rebuildAndPresent() }
    @objc private func showClipboard() { mode = .clipboard; rebuildAndPresent() }
    @objc private func showAudio() { mode = .audio; rebuildAndPresent() }
    @objc private func showMIDI() { mode = .midi; rebuildAndPresent() }
    @objc private func showGames() { mode = .gamesMenu; rebuildAndPresent() }
    @objc private func showSavers() { mode = .saversMenu; rebuildAndPresent() }
    @objc private func showPong() { mode = .pong; rebuildAndPresent() }
    @objc private func showSnake() { mode = .snake; rebuildAndPresent() }
    @objc private func showBreakout() { mode = .breakout; rebuildAndPresent() }
    @objc private func showLife() { mode = .life; rebuildAndPresent() }
    @objc private func showPitfall() { mode = .pitfall; rebuildAndPresent() }
    @objc private func showET() { mode = .et; rebuildAndPresent() }
    @objc private func showMario() {
        // Mario is the only feature that needs global keyboard events.
        // Ask for Input Monitoring only when the user actually chooses it,
        // instead of presenting a privacy prompt on first launch.
        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
        mode = .mario
        rebuildAndPresent()
    }
    @objc private func showAdventure() { mode = .adventure; rebuildAndPresent() }
    @objc private func showDVD() { mode = .dvdSaver; rebuildAndPresent() }
    @objc private func showPipes() { mode = .pipesSaver; rebuildAndPresent() }
    @objc private func showToasters() { mode = .toastersSaver; rebuildAndPresent() }
    @objc private func showKITT() { mode = .kitt; rebuildAndPresent() }
    @objc private func showTokiPona() { mode = .tokiPona; rebuildAndPresent() }
    @objc private func showPond() { mode = .pond; rebuildAndPresent() }
}

private final class TouchBarContentHostView: NSView {
    init(content: NSView, preferredWidth: CGFloat) {
        let size = NSSize(width: preferredWidth, height: 30)
        super.init(frame: NSRect(origin: .zero, size: size))
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class FixedTouchBarView: NSView {
    private let fixedSize: NSSize

    init(size: NSSize) {
        fixedSize = size
        super.init(frame: NSRect(origin: .zero, size: size))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize { fixedSize }
}
