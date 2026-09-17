# TouchBarpalooza

A native macOS playground for Touch Bar-equipped MacBook Pros.

TouchBarpalooza includes its own **persistent system-modal Touch Bar host**, so it can remain visible while Safari, Finder, Xcode, or another application is frontmost. BetterTouchTool is not required.

## Current launcher

The persistent launcher currently includes:

- Clipboard history
- live audio spectrum
- MIDI controls
- Games
- classic screensaver recreations
- KITT scanner
- Toki Pona study tools
- interactive koi pond

Compact `esc`, Home, and Quit controls are used where appropriate so the Touch Bar content has as much room as possible.

## Games

The Games menu currently includes, in chronological order:

- Conway's Life
- Pong
- Colossal Cave Adventure-style terminal
- Breakout
- Snake
- Pitfall-style platforming
- E.T.-style Touch Bar game
- Super Mario Bros. World 1-1 miniature
- Lemmings

Lemmings has two modes:

- **PLAY**: interactive one-dimensional Lemmings-inspired game with eight skill selectors and nuke.
- **DEMO**: autonomous sequence intended to be watched directly on the Touch Bar.

No original commercial game assets are bundled. Graphics are drawn in code or reconstructed as small original approximations for this Touch Bar experiment.

## Savers

The Savers menu currently includes:

- DVD VIDEO bouncing logo
- Windows 3D Pipes-style saver, including a rare Utah teapot joint
- After Dark Flying Toasters-style saver

## Clipboard

Keeps the six most recent text clipboard entries. Tap an entry to make it the current clipboard contents again.

## Audio

A live microphone-input VU meter and coarse spectrum analyzer. macOS requests microphone permission the first time this module is opened.

## MIDI

Four Touch Bar sliders send MIDI CC 20–23, values 0–127, to the first available MIDI destination.

## KITT

A persistent red back-and-forth scanner inspired by the front scanner on KITT from *Knight Rider*.

## Run from Xcode

1. Clone this repository on a Touch Bar Mac with Xcode installed.
2. Open `TouchBarpalooza.xcodeproj`.
3. Select the **TouchBarpalooza** target and **My Mac**.
4. Quit or disable BetterTouchTool while testing the standalone host so the two programs do not compete for the Touch Bar.
5. Press Run.

Closing TouchBarpalooza's window does not quit the process, because the Touch Bar host is intended to keep running. Quit from the TouchBarpalooza application menu, Dock, or the Touch Bar Quit control when you want to stop it.

## Build a standalone app

A Release build can be created without Xcode launching the app:

```bash
bash scripts/build-local-release.sh
```

That produces:

```text
dist/TouchBarpalooza.app
dist/TouchBarpalooza.zip
```

To build, replace `/Applications/TouchBarpalooza.app`, and launch the new copy:

```bash
bash scripts/build-local-release.sh --install
```

The standalone app is only a built snapshot. Development can continue normally afterward and newer builds can replace it at any time.

For Xcode Archive, signing, notarization, and future public distribution notes, see [`DISTRIBUTION.md`](DISTRIBUTION.md).

## Private API note

Persistent ownership of the Touch Bar is not exposed by Apple's public AppKit API. TouchBarpalooza therefore uses private system-modal Touch Bar interfaces plus `DFRFoundation` for its Control Strip entry.

Consequences:

- This is appropriate for direct distribution and experimentation on Touch Bar Macs, but not for Mac App Store distribution.
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
