# TouchBarpalooza

A native macOS playground for Touch Bar-equipped MacBook Pros.

TouchBarpalooza now includes its own **persistent system-modal Touch Bar host**. It does not need BetterTouchTool to remain visible when Safari, Finder, Xcode, or another application is frontmost.

The first module is **Lemmings**, an original pixel-art homage with tiny green-haired walkers crossing the Touch Bar.

## Current build

- Persistent global Touch Bar hosted directly by TouchBarpalooza.
- Home screen with buttons for **Lemmings**, **Meters**, **Clipboard**, **Notes**, and **About**.
- Animated original pixel-art Lemmings module.
- Home button returns from a module to the launcher.
- A small `TP` Control Strip item can restore TouchBarpalooza if the system-modal bar is minimized.
- Placeholder modules are wired for future experiments.

## Run it

1. Clone this repository on a Touch Bar Mac with Xcode installed.
2. Open `TouchBarpalooza.xcodeproj`.
3. Select the **TouchBarpalooza** scheme and **My Mac**.
4. Quit or disable BetterTouchTool while testing the standalone host so the two programs do not compete for the Touch Bar.
5. Press Run.
6. Tap **Lemmings**, then switch to Safari or another application. The TouchBarpalooza bar should remain active.

Closing TouchBarpalooza's window no longer quits the process, because the Touch Bar host is intended to keep running. Quit the app normally from its application menu or Dock when you want to stop it.

## Private API note

Persistent ownership of the Touch Bar is not exposed by Apple's public AppKit API. TouchBarpalooza therefore uses the private system-modal Touch Bar interfaces also used by established Touch Bar utilities, plus `DFRFoundation` for its Control Strip entry.

Consequences:

- This is appropriate for experimentation on a fixed Touch Bar Mac, but not for Mac App Store distribution.
- A macOS update could change or remove these private interfaces.
- The standalone host is deliberately isolated in `GlobalTouchBarController.swift` and `TouchBarPrivateApi.h` so the rest of the project remains ordinary AppKit code.

## BetterTouchTool proof-of-concept

`BetterTouchTool/TouchBarpaloozaLemmings.swift` remains in the repository as the prototype that proved global hosting worked. It is no longer required by the standalone app.

## Lemmings note

No original *Lemmings* artwork or game assets are included. The walkers are drawn in code as new pixel art inspired by the green-hair/blue-outfit visual language of the 1990s game.

## Requirements

- A Mac with a physical Touch Bar
- macOS 10.15 or later
- Xcode capable of building Swift 5

## License

MIT. See `LICENSE`.
