# TouchBarpalooza

A native macOS playground for Touch Bar-equipped MacBook Pros.

TouchBarpalooza includes its own **persistent system-modal Touch Bar host**, so it can remain visible while Safari, Finder, Xcode, or another application is frontmost. BetterTouchTool is not required.

## Current launcher

- **Lemmings**
- **Clipboard**
- **Audio**
- **MIDI**
- **Games**
- **KITT**

## Lemmings

The Lemmings module now has two modes:

- **PLAY**: interactive one-dimensional Lemmings-inspired game.
- **DEMO**: autonomous game that plays itself so the Touch Bar can simply be watched.

The current playable pass includes larger 8-frame walkers, a trapdoor entrance, exit, terrain, pits and walls, falling, turning, release-rate adjustment, pause, nuke, OUT/IN counters, and eight skill selectors: climber, floater, bomber, blocker, builder, basher, miner, and digger. Tap a lemming after choosing a skill to assign it.

No original *Lemmings* artwork or game assets are included. The graphics are newly drawn pixel approximations inspired by the 1991 visual language.

## Clipboard

Keeps a rolling shelf of recent text clipboard entries. Tap an entry to make it the current clipboard contents again.

## Audio

A live microphone-input VU meter and coarse spectrum analyzer. macOS will request microphone permission the first time this module is opened.

## MIDI

Four Touch Bar sliders send MIDI CC 20–23, values 0–127, to the first available MIDI destination.

## Games

Current mini-games:

- Pong
- Snake
- Breakout
- Conway's Life

The games are deliberately Touch-Bar-shaped. Touch/drag affects the paddle, snake direction, Breakout paddle, or Life cells depending on the game.

## KITT

A persistent red back-and-forth scanner inspired by the front scanner on KITT from *Knight Rider*.

## Run it

1. Clone this repository on a Touch Bar Mac with Xcode installed.
2. Open `TouchBarpalooza.xcodeproj`.
3. Select the **TouchBarpalooza** scheme and **My Mac**.
4. Quit or disable BetterTouchTool while testing the standalone host so the two programs do not compete for the Touch Bar.
5. Press Run.

Closing TouchBarpalooza's window does not quit the process, because the Touch Bar host is intended to keep running. Quit the app normally from its application menu or Dock when you want to stop it.

## Private API note

Persistent ownership of the Touch Bar is not exposed by Apple's public AppKit API. TouchBarpalooza therefore uses private system-modal Touch Bar interfaces plus `DFRFoundation` for its Control Strip entry.

Consequences:

- This is appropriate for experimentation on a fixed Touch Bar Mac, but not for Mac App Store distribution.
- A macOS update could change or remove these private interfaces.
- The standalone host is isolated in `GlobalTouchBarController.swift` and `TouchBarPrivateApi.h` so the rest of the project remains ordinary AppKit code.

## BetterTouchTool proof-of-concept

`BetterTouchTool/TouchBarpaloozaLemmings.swift` remains in the repository as the prototype that proved global hosting worked. It is no longer required by the standalone app.

## Requirements

- A Mac with a physical Touch Bar
- macOS 10.15 or later
- Xcode capable of building Swift 5

## License

MIT. See `LICENSE`.
