import AppKit

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
pu|the official toki pona book; use/interact with pu
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
        let pitSpecs: [(CGFloat, CGFloat, CGFloat)] = [
            (0.24, 9, 0.10),
            (0.50, 18, 0.12),
            (0.76, 8, 0.10)
        ]
        for (fraction, y, width) in pitSpecs {
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
