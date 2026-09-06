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

    static let pong = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.games.pong")
    static let snake = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.games.snake")
    static let breakout = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.games.breakout")
    static let life = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.games.life")
    static let pitfall = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.games.pitfall")
    static let et = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.games.et")
    static let caveFlyer = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.games.caveflyer")
    static let adventure = NSTouchBarItem.Identifier("com.udeudeude.TouchBarpalooza.games.adventure")

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
                .touchBarpaloozaKITT,
                .touchBarpaloozaTokiPona
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
            bar.defaultItemIdentifiers = [.pong, .snake, .breakout, .life, .pitfall, .et, .caveFlyer, .adventure]

        case .clipboard, .audio, .midi, .pong, .snake, .breakout, .life, .pitfall, .et, .caveFlyer, .adventure, .kitt, .tokiPona:
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

        case .pong:
            return buttonItem(identifier: identifier, title: "Pong", action: #selector(showPong))
        case .snake:
            return buttonItem(identifier: identifier, title: "Snake", action: #selector(showSnake))
        case .breakout:
            return buttonItem(identifier: identifier, title: "Breakout", action: #selector(showBreakout))
        case .life:
            return buttonItem(identifier: identifier, title: "Life", action: #selector(showLife))
        case .pitfall:
            return buttonItem(identifier: identifier, title: "Pitfall", action: #selector(showPitfall))
        case .et:
            return buttonItem(identifier: identifier, title: "E.T.", action: #selector(showET))
        case .caveFlyer:
            return buttonItem(identifier: identifier, title: "Cave", action: #selector(showCaveFlyer))
        case .adventure:
            return buttonItem(identifier: identifier, title: "Adventure", action: #selector(showAdventure))

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
        case .pitfall:
            view = PitfallHomageView(frame: frame)
        case .et:
            view = ETHomageView(frame: frame)
        case .caveFlyer:
            view = CaveFlyerView(frame: frame)
        case .adventure:
            view = AdventureTerminalView(frame: frame)
        case .kitt:
            view = KITTScannerView(frame: frame)
        case .tokiPona:
            view = TokiPonaStudyView(frame: frame)
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
    @objc private func showPitfall() { mode = .pitfall; rebuildAndPresent() }
    @objc private func showET() { mode = .et; rebuildAndPresent() }
    @objc private func showCaveFlyer() { mode = .caveFlyer; rebuildAndPresent() }
    @objc private func showAdventure() { mode = .adventure; rebuildAndPresent() }
    @objc private func showKITT() { mode = .kitt; rebuildAndPresent() }
    @objc private func showTokiPona() { mode = .tokiPona; rebuildAndPresent() }
}

final class TokiPonaStudyView: NSView {
    private struct Entry {
        let word: String
        let meanings: String
    }

    private let entries: [Entry] = [
        Entry(word: "a", meanings: "ah!; emotion, emphasis, confirmation"),
        Entry(word: "akesi", meanings: "reptile, amphibian; non-cute animal"),
        Entry(word: "ala", meanings: "no, not, nothing; zero"),
        Entry(word: "alasa", meanings: "hunt, forage, seek, try to"),
        Entry(word: "ale", meanings: "all, every, everything; universe; 100"),
        Entry(word: "anpa", meanings: "low, below, bottom; humble, defeated"),
        Entry(word: "ante", meanings: "different, changed, other; change"),
        Entry(word: "anu", meanings: "or"),
        Entry(word: "awen", meanings: "stay, remain, wait, continue; enduring"),
        Entry(word: "e", meanings: "marks the direct object"),
        Entry(word: "en", meanings: "joins multiple subjects"),
        Entry(word: "esun", meanings: "market, shop, trade, exchange"),
        Entry(word: "ijo", meanings: "thing, object, matter, phenomenon"),
        Entry(word: "ike", meanings: "bad, negative, harmful, unnecessary"),
        Entry(word: "ilo", meanings: "tool, device, machine, instrument"),
        Entry(word: "insa", meanings: "inside, center, contents; internal"),
        Entry(word: "jaki", meanings: "dirty, gross, toxic; waste"),
        Entry(word: "jan", meanings: "person, human, somebody"),
        Entry(word: "jelo", meanings: "yellow, yellowish"),
        Entry(word: "jo", meanings: "have, carry, contain, hold"),
        Entry(word: "kala", meanings: "fish; aquatic animal"),
        Entry(word: "kalama", meanings: "sound, noise; make sound, speak aloud"),
        Entry(word: "kama", meanings: "come, arrive, become; future, arriving"),
        Entry(word: "kasi", meanings: "plant, vegetation, herb, leaf"),
        Entry(word: "ken", meanings: "can, may, possible; ability"),
        Entry(word: "kepeken", meanings: "use, using, by means of"),
        Entry(word: "kili", meanings: "fruit, vegetable, mushroom; edible plant part"),
        Entry(word: "kiwen", meanings: "hard object, stone, metal; solid, hard"),
        Entry(word: "ko", meanings: "paste, powder, semi-solid substance"),
        Entry(word: "kon", meanings: "air, breath, wind; spirit, essence"),
        Entry(word: "kule", meanings: "color, pigment; colorful"),
        Entry(word: "kulupu", meanings: "group, community, collection, company"),
        Entry(word: "kute", meanings: "hear, listen; ear, auditory"),
        Entry(word: "la", meanings: "context separator: given X, Y"),
        Entry(word: "lape", meanings: "sleep, rest; sleeping"),
        Entry(word: "laso", meanings: "blue, green, cyan"),
        Entry(word: "lawa", meanings: "head, mind; control, lead, govern"),
        Entry(word: "len", meanings: "cloth, clothing, cover, layer"),
        Entry(word: "lete", meanings: "cold, cool; uncooked, raw"),
        Entry(word: "li", meanings: "separates subject from predicate"),
        Entry(word: "lili", meanings: "small, little, short, young; reduce"),
        Entry(word: "linja", meanings: "line, cord, hair, rope, long flexible thing"),
        Entry(word: "lipu", meanings: "flat object, paper, page, book, document"),
        Entry(word: "loje", meanings: "red, reddish"),
        Entry(word: "lon", meanings: "at, in, on; exist, be present, true"),
        Entry(word: "luka", meanings: "hand, arm; five; touch, handle"),
        Entry(word: "lukin", meanings: "look, see, examine, read; eye"),
        Entry(word: "lupa", meanings: "hole, opening, door, window"),
        Entry(word: "ma", meanings: "land, earth, country, place, outdoors"),
        Entry(word: "mama", meanings: "parent, ancestor, creator, caretaker"),
        Entry(word: "mani", meanings: "money, wealth, valuable possession"),
        Entry(word: "meli", meanings: "woman, female, feminine"),
        Entry(word: "mi", meanings: "I, me, we, us"),
        Entry(word: "mije", meanings: "man, male, masculine"),
        Entry(word: "moku", meanings: "eat, drink, consume; food"),
        Entry(word: "moli", meanings: "dead, dying; kill, death"),
        Entry(word: "monsi", meanings: "back, behind, rear"),
        Entry(word: "mu", meanings: "animal sound; non-speech vocalization"),
        Entry(word: "mun", meanings: "moon, star, night-sky object"),
        Entry(word: "musi", meanings: "fun, play, game, art, entertainment"),
        Entry(word: "mute", meanings: "many, much, several, very; quantity"),
        Entry(word: "nanpa", meanings: "number; ordinal marker"),
        Entry(word: "nasa", meanings: "strange, unusual, silly, drunk, altered"),
        Entry(word: "nasin", meanings: "way, path, road, method, doctrine"),
        Entry(word: "nena", meanings: "bump, hill, mountain, nose, protrusion"),
        Entry(word: "ni", meanings: "this, that, these, those"),
        Entry(word: "nimi", meanings: "word, name"),
        Entry(word: "noka", meanings: "foot, leg; bottom, lower part"),
        Entry(word: "o", meanings: "vocative; command, wish, request marker"),
        Entry(word: "olin", meanings: "love, respect, deep affection"),
        Entry(word: "ona", meanings: "he, she, it, they; him, her, them"),
        Entry(word: "open", meanings: "open, begin, start, turn on"),
        Entry(word: "pakala", meanings: "broken, damaged, mistake; break, harm"),
        Entry(word: "pali", meanings: "work, do, make, build; activity"),
        Entry(word: "palisa", meanings: "long hard object, rod, stick, branch"),
        Entry(word: "pan", meanings: "grain, bread, cereal, starchy staple"),
        Entry(word: "pana", meanings: "give, send, emit, provide, put"),
        Entry(word: "pi", meanings: "regroups modifiers in a noun phrase"),
        Entry(word: "pilin", meanings: "feel, think intuitively; heart, emotion"),
        Entry(word: "pimeja", meanings: "black, dark, shadowy"),
        Entry(word: "pini", meanings: "end, finish, past; closed, completed"),
        Entry(word: "pipi", meanings: "bug, insect, spider, small crawling animal"),
        Entry(word: "poka", meanings: "side, nearby, beside; with, proximity"),
        Entry(word: "poki", meanings: "container, box, bowl, bag, vessel"),
        Entry(word: "pona", meanings: "good, simple, positive, useful; improve, fix"),
        Entry(word: "pu", meanings: "the official Toki Pona book; use/interact with pu"),
        Entry(word: "sama", meanings: "same, similar, equal; like, as"),
        Entry(word: "seli", meanings: "fire, heat, warmth; hot, cooked"),
        Entry(word: "selo", meanings: "outer layer, skin, shell, boundary"),
        Entry(word: "seme", meanings: "what? which? who?; question word"),
        Entry(word: "sewi", meanings: "above, high, upper; sacred, divine"),
        Entry(word: "sijelo", meanings: "body, physical state, torso"),
        Entry(word: "sike", meanings: "circle, sphere, cycle, round object; year"),
        Entry(word: "sin", meanings: "new, fresh, additional, again"),
        Entry(word: "sina", meanings: "you"),
        Entry(word: "sinpin", meanings: "front, face, wall, vertical surface"),
        Entry(word: "sitelen", meanings: "image, symbol, writing; draw, write"),
        Entry(word: "sona", meanings: "know, understand, skill, knowledge"),
        Entry(word: "soweli", meanings: "land mammal; animal"),
        Entry(word: "suli", meanings: "big, tall, long, important, adult; increase"),
        Entry(word: "suno", meanings: "sun, light, brightness, lamp"),
        Entry(word: "supa", meanings: "horizontal surface, table, floor, furniture"),
        Entry(word: "suwi", meanings: "sweet, cute, pleasant, adorable"),
        Entry(word: "tan", meanings: "from, because of, caused by; origin, cause"),
        Entry(word: "taso", meanings: "only, solely; but, however"),
        Entry(word: "tawa", meanings: "go, move; toward, to, for; moving"),
        Entry(word: "telo", meanings: "water, liquid, fluid, beverage; wash"),
        Entry(word: "tenpo", meanings: "time, duration, moment, event, period"),
        Entry(word: "toki", meanings: "speech, language, communication; speak, say"),
        Entry(word: "tomo", meanings: "building, room, house, indoor space"),
        Entry(word: "tu", meanings: "two; divide, split"),
        Entry(word: "unpa", meanings: "sex, sexual activity"),
        Entry(word: "uta", meanings: "mouth, lips, oral opening"),
        Entry(word: "utala", meanings: "fight, conflict, compete, challenge"),
        Entry(word: "walo", meanings: "white, pale, light-colored"),
        Entry(word: "wan", meanings: "one, unique; unite, combine"),
        Entry(word: "waso", meanings: "bird, flying creature"),
        Entry(word: "wawa", meanings: "strong, powerful, energetic, intense"),
        Entry(word: "weka", meanings: "away, absent, removed; remove, discard"),
        Entry(word: "wile", meanings: "want, need, must, should; desire")
    ]

    private let wordLabel = NSTextField(labelWithString: "")
    private let pronunciationLabel = NSTextField(labelWithString: "")
    private let meaningLabel = NSTextField(labelWithString: "")
    private var timer: Timer?
    private var currentIndex: Int?

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

        wordLabel.font = .monospacedSystemFont(ofSize: 17, weight: .bold)
        wordLabel.textColor = .white
        wordLabel.alignment = .right
        wordLabel.lineBreakMode = .byClipping
        wordLabel.translatesAutoresizingMaskIntoConstraints = false

        pronunciationLabel.font = .monospacedSystemFont(ofSize: 9, weight: .medium)
        pronunciationLabel.textColor = NSColor(calibratedRed: 0.55, green: 0.85, blue: 1.0, alpha: 1)
        pronunciationLabel.alignment = .center
        pronunciationLabel.lineBreakMode = .byClipping
        pronunciationLabel.translatesAutoresizingMaskIntoConstraints = false

        meaningLabel.font = .systemFont(ofSize: 10, weight: .regular)
        meaningLabel.textColor = NSColor(calibratedWhite: 0.88, alpha: 1)
        meaningLabel.alignment = .left
        meaningLabel.lineBreakMode = .byTruncatingTail
        meaningLabel.maximumNumberOfLines = 1
        meaningLabel.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSTextField(labelWithString: "•")
        separator.font = .systemFont(ofSize: 11, weight: .bold)
        separator.textColor = NSColor(calibratedWhite: 0.45, alpha: 1)
        separator.alignment = .center
        separator.translatesAutoresizingMaskIntoConstraints = false

        addSubview(wordLabel)
        addSubview(pronunciationLabel)
        addSubview(separator)
        addSubview(meaningLabel)

        NSLayoutConstraint.activate([
            wordLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            wordLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            wordLabel.widthAnchor.constraint(equalToConstant: 125),

            pronunciationLabel.leadingAnchor.constraint(equalTo: wordLabel.trailingAnchor, constant: 5),
            pronunciationLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            pronunciationLabel.widthAnchor.constraint(equalToConstant: 120),

            separator.leadingAnchor.constraint(equalTo: pronunciationLabel.trailingAnchor, constant: 5),
            separator.centerYAnchor.constraint(equalTo: centerYAnchor),
            separator.widthAnchor.constraint(equalToConstant: 10),

            meaningLabel.leadingAnchor.constraint(equalTo: separator.trailingAnchor, constant: 8),
            meaningLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            meaningLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    override func mouseDown(with event: NSEvent) {
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
        meaningLabel.stringValue = entry.meanings
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
                let nextIsVowel = index + 1 < characters.count && vowels.contains(characters[index + 1])
                if !nextIsVowel {
                    syllable += "n"
                    index += 1
                }
            }
            syllables.append(syllable)
        }

        return syllables.enumerated().map { offset, syllable in
            offset == 0 ? syllable.uppercased() : syllable.lowercased()
        }.joined(separator: "-")
    }
}
