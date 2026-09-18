# TouchBarpalooza

[![Build TouchBarpalooza](https://github.com/udeudeude/TouchBarpalooza/actions/workflows/build.yml/badge.svg)](https://github.com/udeudeude/TouchBarpalooza/actions/workflows/build.yml)

**TouchBarpalooza is a standalone native macOS utility that turns the physical Touch Bar into a persistent playground for games, visualizers, utilities, study tools, and retro experiments.**

It includes its own **system-modal Touch Bar host**, so the TouchBarpalooza interface can stay visible while Safari, Finder, Xcode, or another application is frontmost. BetterTouchTool is not required.

The current standalone build is **TouchBarpalooza 0.3**. It has been built as a universal Mac application for both Intel and Apple silicon and tested running directly from `/Applications` on a physical Touch Bar Mac.

## What is on the Touch Bar

The main launcher currently includes:

- **Clipboard**: the six most recent text clipboard entries
- **Spectrum**: live microphone VU meter and coarse spectrum analyzer
- **MIDI**: four Touch Bar sliders sending MIDI control-change values
- **Games**
- **Savers**
- **KITT**: red back-and-forth scanner
- **Toki Pona** study tools
- **Pond**: interactive koi and water ripples

Compact `esc`, Home, and Quit controls are used where appropriate to preserve Touch Bar space.

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

### Lemmings

Lemmings has two modes:

- **PLAY**: interactive one-dimensional game with the eight classic skill categories and nuke
- **DEMO**: an autonomous sequence designed to be watched directly on the Touch Bar

The project does not bundle original commercial game assets. Graphics are drawn in code or recreated specifically for this Touch Bar experiment.

## Savers

The Savers menu currently includes:

- **DVD VIDEO** bouncing logo
- **3D Pipes** recreation with a Utah teapot on roughly 1 in 100 turning joints
- **Flying Toasters** recreation inspired by After Dark

## Standalone app

TouchBarpalooza now works as a normal standalone Mac application. It does not need Xcode to remain running.

From the repository root:

```bash
bash scripts/build-local-release.sh
```

That creates:

```text
dist/TouchBarpalooza.app
dist/TouchBarpalooza.zip
```

To build the Release version, replace the copy in `/Applications`, and launch it:

```bash
bash scripts/build-local-release.sh --install
```

The release script verifies the app bundle, version, bundle identifier, processor architectures, private framework linkage, and local code signature.

In standalone use, TouchBarpalooza can operate without keeping a desktop window in the way. The macOS application menu remains available for normal application commands such as About and Quit.

## Develop from Xcode

1. Clone this repository on a Touch Bar Mac with Xcode installed.
2. Open `TouchBarpalooza.xcodeproj`.
3. Select **TouchBarpalooza** and **My Mac**.
4. Quit or disable BetterTouchTool while testing the standalone host so the two programs do not compete for the Touch Bar.
5. Press **Command-R**.

Development can continue normally after installing the standalone app. A built `.app` is only a snapshot of the source at that point. Later changes can be built and installed over it.

Every push to `main` is also checked with both Debug and Release macOS builds on GitHub Actions.

## Compatibility

Current project settings:

- physical Touch Bar required
- macOS 10.15 or later
- Swift 5
- universal Intel (`x86_64`) + Apple silicon (`arm64`) builds

Actual Touch Bar behavior still needs hardware testing because the persistent host uses private macOS interfaces.

## Private API note

Persistent ownership of the Touch Bar is not exposed through Apple's public AppKit API. TouchBarpalooza therefore uses private system-modal Touch Bar interfaces plus `DFRFoundation`.

Consequences:

- the Mac App Store is not an appropriate distribution target
- direct standalone distribution is the intended path
- a future macOS update could change or remove the private interfaces
- the private host code is isolated primarily in `GlobalTouchBarController.swift` and `TouchBarPrivateApi.h`

For local builds, Xcode Archive, signing, notarization, and future public distribution notes, see [`DISTRIBUTION.md`](DISTRIBUTION.md).

## BetterTouchTool prototype

`BetterTouchTool/TouchBarpaloozaLemmings.swift` remains in the repository as the early proof-of-concept that demonstrated persistent global Touch Bar hosting. It is no longer required by the standalone app.

## License

MIT. See [`LICENSE`](LICENSE).
