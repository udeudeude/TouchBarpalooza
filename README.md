# TouchBarpalooza

A tiny native macOS playground for the Touch Bar on Touch Bar-equipped MacBook Pros.

The app replaces its Touch Bar with a small launcher for TouchBarpalooza modules. The first module is **Lemmings**, an original pixel-art homage with tiny green-haired walkers crossing the Touch Bar.

## Current build

- Home Touch Bar with buttons for **Lemmings**, **Meters**, **Clipboard**, **Notes**, and **About**.
- Lemmings module with animated original pixel walkers.
- Home button returns from a module to the launcher.
- Placeholder modules are already wired so we can add them one at a time.

## Run it

1. Clone this repository on a Mac with Xcode installed.
2. Open `TouchBarpalooza.xcodeproj`.
3. Select the **TouchBarpalooza** scheme and **My Mac**.
4. Press Run.
5. Bring TouchBarpalooza to the foreground. Its controls should appear on the physical Touch Bar.

The window intentionally does very little; the Touch Bar is the actual playground.

## Lemmings note

No original *Lemmings* artwork or game assets are included. The walkers are drawn in code as new pixel art inspired by the green-hair/blue-outfit visual language of the 1990s game.

## Requirements

- macOS 10.15 or later
- Xcode capable of building Swift 5
- A MacBook Pro with a physical Touch Bar for the intended experience

## License

MIT. See `LICENSE`.
