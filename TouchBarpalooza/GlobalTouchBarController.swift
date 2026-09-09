import AppKit
import ApplicationServices
import CoreGraphics

private extension NSTouchBarItem.Identifier {
    static let touchBarpaloozaTray = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.tray")
    static let touchBarpaloozaEscape = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.escape")
    static let touchBarpaloozaQuit = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.quit")
    static let touchBarpaloozaHome = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.home")

    static let touchBarpaloozaLemmings = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.lemmings")
    static let touchBarpaloozaClipboard = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.clipboard")
    static let touchBarpaloozaAudio = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.audio")
    static let touchBarpaloozaMIDI = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.midi")
    static let touchBarpaloozaGames = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.games")
    static let touchBarpaloozaKITT = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.kitt")
    static let touchBarpaloozaTokiPona = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.tokipona")
    static let touchBarpaloozaPond = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.pond")

    static let lemmingsPlay = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.lemmings.play")
    static let lemmingsDemo = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.lemmings.demo")
    static let lemmingsControls = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.lemmings.controls")

    static let gamesCompact = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.games.compact")
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
        case pitfall
        case et
        case adventure
        case kitt
        case tokiPona
        case pond
    }

    private var mode: Mode = .home
    private var touchBar = NSTouchBar()
    private var trayItem: NSCustomTouchBarItem?
    private var isStarted = false
    private weak var currentLemmingsView: LemmingsView?
    private var lemmingsSkillButtons: [NSButton] = []

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
        if let trayItem {
            NSTouchBarItem.removeSystemTrayItem(trayItem)
        }
        trayItem = nil
        isStarted = false
    }

    private func rebuildAndPresent() {
        currentLemmingsView = nil
        lemmingsSkillButtons.removeAll()

        let bar = NSTouchBar()
        bar.delegate = self
        bar.escapeKeyReplacementItemIdentifier = .touchBarpaloozaEscape

        switch mode {
        case .home:
            bar.defaultItemIdentifiers = [
                .touchBarpaloozaQuit,
                .touchBarpaloozaClipboard,
                .touchBarpaloozaAudio,
                .touchBarpaloozaMIDI,
                .touchBarpaloozaGames,
                .touchBarpaloozaKITT,
                .touchBarpaloozaTokiPona,
                .touchBarpaloozaPond
            ]
        case .lemmingsMenu:
            bar.defaultItemIdentifiers = [.touchBarpaloozaHome, .lemmingsPlay, .lemmingsDemo]
        case .lemmingsPlay:
            bar.defaultItemIdentifiers = [.touchBarpaloozaHome, .lemmingsControls, .content]
        case .lemmingsDemo:
            bar.defaultItemIdentifiers = [.touchBarpaloozaHome, .content]
        case .gamesMenu:
            bar.defaultItemIdentifiers = [.touchBarpaloozaHome, .gamesCompact]
        case .clipboard, .audio, .midi, .pong, .snake, .breakout, .life,
             .pitfall, .et, .adventure, .kitt, .tokiPona, .pond:
            bar.defaultItemIdentifiers = [.touchBarpaloozaHome, .content]
        }

        touchBar = bar
        presentCurrentBar()
    }

    @objc private func presentCurrentBar() {
        guard isStarted else { return }
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
        case .touchBarpaloozaEscape:
            let item = buttonItem(identifier: identifier, title: "esc", action: #selector(sendEscape))
            item.visibilityPriority = .high
            return item
        case .touchBarpaloozaQuit:
            let item = buttonItem(identifier: identifier, title: "ⓧ", action: #selector(quitTouchBarpalooza))
            item.visibilityPriority = .high
            item.view.toolTip = "Quit TouchBarpalooza"
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
        case .content:
            return contentItem(identifier: identifier)
        default:
            return nil
        }
    }

    private func preferredContentWidth() -> CGFloat {
        switch mode {
        case .lemmingsPlay:
            return 350
        case .clipboard, .midi:
            return 690
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
        case .adventure:
            content = AdventureTerminalViewV2(frame: frame)
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
        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 545, height: 30))
        stack.orientation = .horizontal
        stack.spacing = 2
        stack.distribution = .fillEqually

        let specs: [(String, Selector)] = [
            ("Life", #selector(showLife)),
            ("Pong", #selector(showPong)),
            ("Cave", #selector(showAdventure)),
            ("Break", #selector(showBreakout)),
            ("Snake", #selector(showSnake)),
            ("Pit", #selector(showPitfall)),
            ("E.T.", #selector(showET)),
            ("Lemmings", #selector(showLemmingsMenu))
        ]

        for (title, action) in specs {
            let button = NSButton(title: title, target: self, action: action)
            button.font = .systemFont(ofSize: 8)
            stack.addArrangedSubview(button)
        }

        item.view = stack
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
        case .touchBarpaloozaEscape:
            compactWidth = 34
        case .touchBarpaloozaQuit, .touchBarpaloozaHome:
            compactWidth = 28
        default:
            compactWidth = nil
        }

        if let compactWidth {
            let host = FixedTouchBarView(size: NSSize(width: compactWidth, height: 30))
            button.frame = NSRect(x: 0, y: 1, width: compactWidth, height: 28)
            button.font = .systemFont(ofSize: identifier == .touchBarpaloozaEscape ? 10 : 13)
            host.addSubview(button)
            item.view = host
        } else {
            item.view = button
        }
        return item
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

    @objc private func sendEscape() {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: false) else {
            return
        }
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }

    @objc private func quitTouchBarpalooza() {
        stop()
        NSApp.terminate(nil)
    }

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
    @objc private func showPitfall() { mode = .pitfall; rebuildAndPresent() }
    @objc private func showET() { mode = .et; rebuildAndPresent() }
    @objc private func showAdventure() { mode = .adventure; rebuildAndPresent() }
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

final class TokiPonaStudyView: NSView {
    private struct Entry {
        let word: String
        let meanings: String
    }

    private static let rawEntries = """
a|ah!; emotion, emphasis, confirmation
akesi|reptile, amphibian; non-cute animal
ala|no, not, nothing; zero
alasa|hunt, forage, seek, try to
ale|all, every, everything; universe; 100
anpa|low, below, bottom; humble, defeated
ante|different, changed, other; change
anu|or
awen|stay, remain, wait, continue; enduring
e|marks the direct object
en|joins multiple subjects
esun|market, shop, trade, exchange
ijo|thing, object, matter, phenomenon
ike|bad, negative, harmful, unnecessary
ilo|tool, device, machine, instrument
insa|inside, center, contents; internal
jaki|dirty, gross, toxic; waste
jan|person, human, somebody
jelo|yellow, yellowish
jo|have, carry, contain, hold
kala|fish; aquatic animal
kalama|sound, noise; make sound, speak aloud
kama|come, arrive, become; future, arriving
kasi|plant, vegetation, herb, leaf
ken|can, may, possible; ability
kepeken|use, using, by means of
kili|fruit, vegetable, mushroom; edible plant part
kiwen|hard object, stone, metal; solid, hard
ko|paste, powder, semi-solid substance
kon|air, breath, wind; spirit, essence
kule|color, pigment; colorful
kulupu|group, community, collection, company
kute|hear, listen; ear, auditory
la|context separator: given X, Y
lape|sleep, rest; sleeping
laso|blue, green, cyan
lawa|head, mind; control, lead, govern
len|cloth, clothing, cover, layer
lete|cold, cool; uncooked, raw
li|separates subject from predicate
lili|small, little, short, young; reduce
linja|line, cord, hair, rope, long flexible thing
lipu|flat object, paper, page, book, document
loje|red, reddish
lon|at, in, on; exist, be present, true
luka|hand, arm; five; touch, handle
lukin|look, see, examine, read; eye
lupa|hole, opening, door, window
ma|land, earth, country, place, outdoors
mama|parent, ancestor, creator, caretaker
mani|money, wealth, valuable possession
meli|woman, female, feminine
mi|I, me, we, us
mije|man, male, masculine
moku|eat, drink, consume; food
moli|dead, dying; kill, death
monsi|back, behind, rear
mu|animal sound; non-speech vocalization
mun|moon, star, night-sky object
musi|fun, play, game, art, entertainment
mute|many, much, several, very; quantity
nanpa|number; ordinal marker
nasa|strange, unusual, silly, drunk, altered
nasin|way, path, road, method, doctrine
nena|bump, hill, mountain, nose, protrusion
ni|this, that, these, those
nimi|word, name
noka|foot, leg; bottom, lower part
o|vocative; command, wish, request marker
olin|love, respect, deep affection
ona|he, she, it, they; him, her, them
open|open, begin, start, turn on
pakala|broken, damaged, mistake; break, harm
pali|work, do, make, build; activity
palisa|long hard object, rod, stick, branch
pan|grain, bread, cereal, starchy staple
pana|give, send, emit, provide, put
pi|regroups modifiers in a noun phrase
pilin|feel, think intuitively; heart, emotion
pimeja|black, dark, shadowy
pini|end, finish, past; closed, completed
pipi|bug, insect, spider, small crawling animal
poka|side, nearby, beside; with, proximity
poki|container, box, bowl, bag, vessel
pona|good, simple, positive, useful; improve, fix
pu|the official Toki Pona book; use/interact with pu
sama|same, similar, equal; like, as
seli|fire, heat, warmth; hot, cooked
selo|outer layer, skin, shell, boundary
seme|what? which? who?; question word
sewi|above, high, upper; sacred, divine
sijelo|body, physical state, torso
sike|circle, sphere, cycle, round object; year
sin|new, fresh, additional, again
sina|you
sinpin|front, face, wall, vertical surface
sitelen|image, symbol, writing; draw, write
sona|know, understand, skill, knowledge
soweli|land mammal; animal
suli|big, tall, long, important, adult; increase
suno|sun, light, brightness, lamp
supa|horizontal surface, table, floor, furniture
suwi|sweet, cute, pleasant, adorable
tan|from, because of, caused by; origin, cause
taso|only, solely; but, however
tawa|go, move; toward, to, for; moving
telo|water, liquid, fluid, beverage; wash
tenpo|time, duration, moment, event, period
toki|speech, language, communication; speak, say
tomo|building, room, house, indoor space
tu|two; divide, split
unpa|sex, sexual activity
uta|mouth, lips, oral opening
utala|fight, conflict, compete, challenge
walo|white, pale, light-colored
wan|one, unique; unite, combine
waso|bird, flying creature
wawa|strong, powerful, energetic, intense
weka|away, absent, removed; remove, discard
wile|want, need, must, should; desire
"""

    private lazy var entries: [Entry] = Self.rawEntries
        .split(separator: "\n")
        .compactMap { line in
            let pieces = line.split(separator: "|", maxSplits: 1).map(String.init)
            guard pieces.count == 2 else { return nil }
            return Entry(word: pieces[0], meanings: pieces[1])
        }

    private let wordLabel = NSTextField(labelWithString: "")
    private let pronunciationLabel = NSTextField(labelWithString: "")
    private let meaningLabel = NSTextField(labelWithString: "")
    private var timer: Timer?
    private var currentIndex: Int?

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
        showRandomWord()
        restartTimer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        buildUI()
        showRandomWord()
        restartTimer()
    }

    deinit { timer?.invalidate() }

    private func buildUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        wordLabel.font = .monospacedSystemFont(ofSize: 16, weight: .bold)
        wordLabel.textColor = .white
        wordLabel.alignment = .right

        pronunciationLabel.font = .monospacedSystemFont(ofSize: 8.5, weight: .medium)
        pronunciationLabel.textColor = NSColor(calibratedRed: 0.55, green: 0.85, blue: 1, alpha: 1)
        pronunciationLabel.alignment = .center

        meaningLabel.font = .systemFont(ofSize: 9.5)
        meaningLabel.textColor = NSColor(calibratedWhite: 0.88, alpha: 1)
        meaningLabel.lineBreakMode = .byTruncatingTail

        wordLabel.frame = NSRect(x: 8, y: 4, width: 118, height: 22)
        pronunciationLabel.frame = NSRect(x: 132, y: 7, width: 112, height: 16)
        meaningLabel.frame = NSRect(x: 258, y: 7, width: max(120, bounds.width - 266), height: 16)
        meaningLabel.autoresizingMask = [.width]

        addSubview(wordLabel)
        addSubview(pronunciationLabel)
        addSubview(meaningLabel)

        let hit = NSButton(frame: bounds)
        hit.title = ""
        hit.isBordered = false
        hit.alphaValue = 0.01
        hit.target = self
        hit.action = #selector(nextWord)
        hit.autoresizingMask = [.width, .height]
        addSubview(hit)
    }

    @objc private func nextWord() {
        showRandomWord()
        restartTimer()
    }

    private func restartTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.showRandomWord()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func showRandomWord() {
        guard !entries.isEmpty else { return }
        var next = Int.random(in: 0..<entries.count)
        while entries.count > 1 && next == currentIndex {
            next = Int.random(in: 0..<entries.count)
        }
        currentIndex = next

        let entry = entries[next]
        wordLabel.stringValue = entry.word
        pronunciationLabel.stringValue = pronunciation(for: entry.word)
        meaningLabel.stringValue = "•  " + entry.meanings
    }

    private func pronunciation(for word: String) -> String {
        let characters = Array(word)
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        var syllables: [String] = []
        var index = 0

        func consonant(_ character: Character) -> String {
            character == "j" ? "y" : String(character)
        }

        func vowel(_ character: Character) -> String {
            switch character {
            case "a": return "ah"
            case "e": return "eh"
            case "i": return "ee"
            case "o": return "oh"
            case "u": return "oo"
            default: return String(character)
            }
        }

        while index < characters.count {
            var syllable = ""
            if !vowels.contains(characters[index]) {
                syllable += consonant(characters[index])
                index += 1
            }

            guard index < characters.count, vowels.contains(characters[index]) else { break }
            syllable += vowel(characters[index])
            index += 1

            if index < characters.count, characters[index] == "n" {
                let followedByVowel = index + 1 < characters.count && vowels.contains(characters[index + 1])
                if !followedByVowel {
                    syllable += "n"
                    index += 1
                }
            }

            syllables.append(syllable)
        }

        return syllables.enumerated().map { pair in
            pair.offset == 0 ? pair.element.uppercased() : pair.element.lowercased()
        }.joined(separator: "-")
    }
}

final class ETPixelGameViewV4: NSView {
    private var playerX: CGFloat = 184
    private var collected = Set<Int>()
    private var score = 8975

    private let sprite: [String] = [
        "..##############",
        "############..##",
        "################",
        "################",
        "####........####",
        "####............",
        "########........",
        "##########......",
        "################",
        "############..##",
        "############....",
        "############....",
        "####..##..##....",
        "####......####..",
        "######....######"
    ]

    override var intrinsicContentSize: NSSize { NSSize(width: 700, height: 30) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        buildControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildControls() {
        let specs: [(String, Selector, NSRect)] = [
            ("◀", #selector(stepLeft), NSRect(x: 2, y: 2, width: 28, height: 26)),
            ("TAKE", #selector(takePressed), NSRect(x: 32, y: 2, width: 46, height: 26)),
            ("▶", #selector(stepRight), NSRect(x: 80, y: 2, width: 28, height: 26))
        ]

        for (title, action, frame) in specs {
            let button = NSButton(title: title, target: self, action: action)
            button.font = .systemFont(ofSize: 7)
            button.frame = frame
            addSubview(button)
        }
    }

    private func piecePositions() -> [CGPoint] {
        let left: CGFloat = 165
        let right = max(left + 120, bounds.width - 20)
        let span = right - left
        return [
            CGPoint(x: left + span * 0.25, y: 13),
            CGPoint(x: left + span * 0.55, y: 11),
            CGPoint(x: left + span * 0.84, y: 15)
        ]
    }

    @objc private func stepLeft() {
        playerX = max(122, playerX - 16)
        needsDisplay = true
    }

    @objc private func stepRight() {
        playerX = min(bounds.width - 26, playerX + 16)
        needsDisplay = true
    }

    @objc private func takePressed() { collectNearby() }

    private func collectNearby() {
        let pieces = piecePositions()
        for index in pieces.indices where !collected.contains(index) {
            if abs(pieces[index].x - playerX) < 25 {
                collected.insert(index)
                score += 25
            }
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let field = NSColor(calibratedRed: 90.0 / 255.0, green: 122.0 / 255.0, blue: 64.0 / 255.0, alpha: 1)
        field.setFill()
        dirtyRect.fill()

        NSColor(calibratedRed: 22.0 / 255.0, green: 59.0 / 255.0, blue: 11.0 / 255.0, alpha: 1).setFill()
        let gameStart: CGFloat = 120
        let gameWidth = max(1, bounds.width - gameStart)
        for (fraction, y, width) in [(0.24, 9.0, 0.10), (0.50, 18.0, 0.12), (0.76, 8.0, 0.10)] {
            NSRect(
                x: gameStart + gameWidth * fraction,
                y: y,
                width: max(28, gameWidth * width),
                height: 5
            ).fill()
        }

        let pieces = piecePositions()
        for index in pieces.indices where !collected.contains(index) {
            NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.20, alpha: 1).setFill()
            let point = pieces[index]
            if index == 0 {
                NSRect(x: point.x, y: point.y, width: 6, height: 3).fill()
                NSRect(x: point.x + 2, y: point.y - 2, width: 2, height: 2).fill()
            } else if index == 1 {
                NSRect(x: point.x, y: point.y, width: 3, height: 6).fill()
                NSRect(x: point.x + 3, y: point.y + 2, width: 3, height: 2).fill()
            } else {
                NSRect(x: point.x, y: point.y, width: 6, height: 2).fill()
                NSRect(x: point.x + 1, y: point.y + 2, width: 4, height: 3).fill()
            }
        }

        drawET(at: NSPoint(x: playerX, y: 7))

        let hud = collected.count == 3
            ? "CALL HOME"
            : String(format: "%04d  PHONE %d/3", score, collected.count)
        hud.draw(
            at: NSPoint(x: 120, y: 1),
            withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 6, weight: .bold),
                .foregroundColor: NSColor(calibratedRed: 0.04, green: 0.20, blue: 0.04, alpha: 1)
            ]
        )
    }

    private func drawET(at origin: NSPoint) {
        NSColor(
            calibratedRed: 149.0 / 255.0,
            green: 206.0 / 255.0,
            blue: 117.0 / 255.0,
            alpha: 1
        ).setFill()

        for (row, line) in sprite.enumerated() {
            for (column, character) in line.enumerated() where character == "#" {
                NSRect(
                    x: origin.x + CGFloat(column),
                    y: origin.y + CGFloat(sprite.count - 1 - row),
                    width: 1.05,
                    height: 1.05
                ).fill()
            }
        }
    }
}
