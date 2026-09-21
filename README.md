# TouchBarpalooza

[![Build TouchBarpalooza](https://github.com/udeudeude/TouchBarpalooza/actions/workflows/build.yml/badge.svg)](https://github.com/udeudeude/TouchBarpalooza/actions/workflows/build.yml)

**TouchBarpalooza is a standalone native macOS utility that turns the physical Touch Bar into a persistent playground for games, visualizers, utilities, study tools, and retro experiments.**

It includes its own **system-modal Touch Bar host**, so the TouchBarpalooza interface can stay visible while Safari, Finder, Xcode, or another application is frontmost. BetterTouchTool is not required.

The current standalone build is **TouchBarpalooza 0.3**. It has been built as a universal Mac application for both Intel and Apple silicon and tested running directly from `/Applications` on a physical Touch Bar Mac.

## Download and install

The project currently does **not** use a paid Apple Developer account, so downloadable builds are intentionally ad-hoc signed rather than Developer ID signed or notarized. They can still be distributed as normal Mac apps, but macOS requires the user to explicitly approve the app the first time it is opened.

For the friendliest current installation:

1. Download the latest `.dmg` from [GitHub Releases](https://github.com/udeudeude/TouchBarpalooza/releases).
2. Open it and drag the app into **Applications**.
3. Try to open the app once.
4. If macOS blocks it, use **Privacy & Security → Open Anyway**.
5. Follow the short Getting Started window shown on first launch.

See [INSTALL_UNSIGNED.md](INSTALL_UNSIGNED.md) for exact instructions, including older macOS versions and the security implications of opening an app that is not notarized.

Both apps now keep a **⌂ menu-bar icon** available for restoring the Touch Bar, reopening Getting Started, viewing About, or quitting.

TouchBarpalooza does not ask for privacy permissions merely because it launched. **Spectrum** requests microphone access only when opened, and **Mario** requests Input Monitoring only when opened.

## Companion app: poki sitelen

The repository also includes **poki sitelen**, a smaller standalone Touch Bar app built from the toki pona and clipboard parts of TouchBarpalooza. The name combines *poki* (container) with *sitelen* (writing/image), a natural toki pona description of a clipboard.

Its normal view is the toki pona word study display. Meanwhile, a six-slot clipboard history keeps watching copied text in the background. Tap **poki** to open those six clipboard slots, then tap **toki** to return to the study display.

Build and install it with:

```bash
bash scripts/build-poki-sitelen.sh --install
```

This creates and installs `/Applications/poki sitelen.app` independently of the full TouchBarpalooza app.

## What is on the Touch Bar

The main launcher currently includes:

- **Clipboard**: the six most recent text clipboard entries
- **Spectrum**: live microphone VU meter and coarse spectrum analyzer
- **MIDI**: four Touch Bar sliders sending MIDI control-change values
- **Games**
- **Savers**
- **KITT**: red back-and-forth scanner
- **toki pona** study tools
- **Pond**: interactive koi and water ripples

Home controls are kept compact to preserve Touch Bar space. The persistent system-modal bar uses macOS's native close box as a one-tap exit to the foreground application's normal Touch Bar, where the real system Escape key is available. The small Control Strip launcher remains available to reopen TouchBarpalooza. No Accessibility permission or synthetic keyboard event is required.

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

In standalone use, TouchBarpalooza can operate without keeping a desktop window in the way. A small **⌂ menu-bar item** remains available for restoring the Touch Bar, Getting Started, About, and Quit.

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

Those settings describe the intended build range, not a guarantee that every Touch Bar model and macOS release has been verified. The persistent host uses private macOS interfaces, and current physical testing is limited to the developer's present Touch Bar Mac. Reports from other Touch Bar models and macOS versions are especially useful; both apps include a **Report a Problem…** item in the ⌂ menu.

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
