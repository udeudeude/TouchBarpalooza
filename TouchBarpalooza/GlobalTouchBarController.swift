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
    static let touchBarpaloozaTokiPona = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.global.tokipona")

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
        case caveFlyer
        case adventure
        case kitt
        case tokiPona
    }

    private var mode: Mode = .home
    private var touchBar = NSTouchBar()
    private var trayItem: NSCustomTouchBarItem?
    private var isStarted = false
    private weak var currentLemmingsView: LemmingsView?

    func start() {
        guard !isStarted else { return }
        isStarted = true

        // Keep the system Escape key. The private system-modal host may still
        // show its own X in some contexts; Home is our navigation control.
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
        if let item = trayItem { NSTouchBarItem.removeSystemTrayItem(item) }
        trayItem = nil
        isStarted = false
    }

    private func rebuildAndPresent() {
        currentLemmingsView = nil
        let bar = NSTouchBar()
        bar.delegate = self
        // Explicitly leave the Escape slot alone. Home is a normal item.
        bar.escapeKeyReplacementItemIdentifier = nil

        switch mode {
        case .home:
            bar.defaultItemIdentifiers = [
                .touchBarpaloozaLemmings,
                .touchBarpaloozaClipboard,
                .touchBarpaloozaAudio,
                .touchBarpaloozaMIDI,
                .touchBarpaloozaGames,
                .touchBarpaloozaKITT,
                .touchBarpaloozaTokiPona
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
             .pitfall, .et, .caveFlyer, .adventure, .kitt, .tokiPona:
            bar.defaultItemIdentifiers = [.touchBarpaloozaHome, .content]
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
        case .lemmingsPlay: return 410
        case .lemmingsDemo: return 700
        case .clipboard: return 690
        case .audio: return 700
        case .midi: return 690
        case .pong, .snake, .breakout, .life: return 700
        case .pitfall, .et, .caveFlyer, .adventure: return 700
        case .kitt: return 700
        case .tokiPona: return 700
        default: return 600
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
            content = MiniGameView(frame: frame, game: .life)
        case .pitfall:
            content = PitfallHomageView(frame: frame)
        case .et:
            content = ETHomageView(frame: frame)
        case .caveFlyer:
            content = CaveFlyerView(frame: frame)
        case .adventure:
            content = AdventureTerminalView(frame: frame)
        case .kitt:
            content = KITTScannerView(frame: frame)
        case .tokiPona:
            content = TokiPonaStudyView(frame: frame)
        default:
            content = NSView(frame: frame)
        }

        // The system-modal Touch Bar drops a custom item entirely when its
        // view reports a rigid intrinsic width that no longer fits beside
        // Home/system controls. Keep the host intrinsically flexible and let
        // the Touch Bar choose the available width.
        item.view = TouchBarContentHostView(content: content, preferredWidth: width)
        item.visibilityPriority = .high
        return item
    }

    private func lemmingsControlItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 270, height: 30))
        stack.orientation = .horizontal
        stack.spacing = 2

        let skills = NSSegmentedControl(
            labels: LemmingsView.Skill.allCases.map { $0.shortName },
            trackingMode: .selectOne,
            target: self,
            action: #selector(skillChanged(_:))
        )
        skills.selectedSegment = LemmingsView.Skill.builder.rawValue
        skills.font = .monospacedSystemFont(ofSize: 6.5, weight: .medium)
        skills.frame.size.width = 165
        stack.addArrangedSubview(skills)
        stack.addArrangedSubview(compactButton("⏯", #selector(toggleLemmingsPause)))
        stack.addArrangedSubview(compactButton("−", #selector(releaseSlower)))
        stack.addArrangedSubview(compactButton("+", #selector(releaseFaster)))
        stack.addArrangedSubview(compactButton("☠", #selector(nukeLemmings)))

        item.view = stack
        return item
    }

    private func gamesMenuItem(identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 610, height: 30))
        stack.orientation = .horizontal
        stack.spacing = 2
        stack.distribution = .fillEqually

        let specs: [(String, Selector)] = [
            ("Pong", #selector(showPong)),
            ("Snake", #selector(showSnake)),
            ("Break", #selector(showBreakout)),
            ("Life", #selector(showLife)),
            ("Pit", #selector(showPitfall)),
            ("E.T.", #selector(showET)),
            ("Scram", #selector(showCaveFlyer)),
            ("Adv", #selector(showAdventure))
        ]
        for (title, action) in specs {
            let button = NSButton(title: title, target: self, action: action)
            button.font = .systemFont(ofSize: 8)
            stack.addArrangedSubview(button)
        }
        item.view = stack
        return item
    }

    private func compactButton(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.font = .systemFont(ofSize: 8)
        return button
    }

    private func buttonItem(identifier: NSTouchBarItem.Identifier, title: String, action: Selector) -> NSCustomTouchBarItem {
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
    @objc private func showPitfall() { mode = .pitfall; rebuildAndPresent() }
    @objc private func showET() { mode = .et; rebuildAndPresent() }
    @objc private func showCaveFlyer() { mode = .caveFlyer; rebuildAndPresent() }
    @objc private func showAdventure() { mode = .adventure; rebuildAndPresent() }
    @objc private func showKITT() { mode = .kitt; rebuildAndPresent() }
    @objc private func showTokiPona() { mode = .tokiPona; rebuildAndPresent() }
}

private final class TouchBarContentHostView: NSView {
    init(content: NSView, preferredWidth: CGFloat) {
        let size = NSSize(width: preferredWidth, height: 30)
        super.init(frame: NSRect(origin: .zero, size: size))
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
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

    private lazy var entries: [Entry] = Self.rawEntries.split(separator: "\n").compactMap { line in
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
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

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
        pronunciationLabel.textColor = NSColor(calibratedRed: 0.55, green: 0.85, blue: 1.0, alpha: 1)
        pronunciationLabel.alignment = .center

        meaningLabel.font = .systemFont(ofSize: 9.5)
        meaningLabel.textColor = NSColor(calibratedWhite: 0.88, alpha: 1)
        meaningLabel.lineBreakMode = .byTruncatingTail
        meaningLabel.maximumNumberOfLines = 1

        wordLabel.frame = NSRect(x: 8, y: 4, width: 118, height: 22)
        pronunciationLabel.frame = NSRect(x: 132, y: 7, width: 112, height: 16)
        meaningLabel.frame = NSRect(x: 258, y: 7, width: max(120, bounds.width - 266), height: 16)
        wordLabel.autoresizingMask = []
        pronunciationLabel.autoresizingMask = []
        meaningLabel.autoresizingMask = [.width]

        addSubview(wordLabel)
        addSubview(pronunciationLabel)
        addSubview(meaningLabel)

        // A real NSButton gives Touch Bar taps a reliable target even when
        // TouchBarpalooza is not the frontmost app.
        let hitButton = NSButton(frame: bounds)
        hitButton.title = ""
        hitButton.isBordered = false
        hitButton.target = self
        hitButton.action = #selector(nextWord)
        hitButton.autoresizingMask = [.width, .height]
        hitButton.alphaValue = 0.01
        addSubview(hitButton)
    }

    @objc private func nextWord() {
        showRandomWord()
        restartTimer()
    }

    private func restartTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.showRandomWord()
        }
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }

    private func showRandomWord() {
        guard !entries.isEmpty else { return }
        var next = Int.random(in: 0..<entries.count)
        if entries.count > 1 {
            while next == currentIndex { next = Int.random(in: 0..<entries.count) }
        }
        currentIndex = next
        let entry = entries[next]
        wordLabel.stringValue = entry.word
        pronunciationLabel.stringValue = pronunciation(for: entry.word)
        meaningLabel.stringValue = "•  " + entry.meanings
    }

    private func pronunciation(for word: String) -> String {
        let chars = Array(word)
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        var syllables: [String] = []
        var index = 0

        func consonant(_ c: Character) -> String { c == "j" ? "y" : String(c) }
        func vowel(_ c: Character) -> String {
            switch c {
            case "a": return "ah"
            case "e": return "eh"
            case "i": return "ee"
            case "o": return "oh"
            case "u": return "oo"
            default: return String(c)
            }
        }

        while index < chars.count {
            var syllable = ""
            if !vowels.contains(chars[index]) {
                syllable += consonant(chars[index])
                index += 1
            }
            guard index < chars.count, vowels.contains(chars[index]) else { break }
            syllable += vowel(chars[index])
            index += 1
            if index < chars.count, chars[index] == "n" {
                let followedByVowel = index + 1 < chars.count && vowels.contains(chars[index + 1])
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
