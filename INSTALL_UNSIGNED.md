# Installing without an Apple Developer account

TouchBarpalooza and poki sitelen are currently distributed as **unsigned / ad-hoc-signed experimental Mac apps**. They are not notarized by Apple because the project does not currently use a paid Apple Developer account.

That means macOS will usually require one extra approval step the first time you open either app.

## Requirements

- A Mac with a **physical Touch Bar**
- macOS **10.15 Catalina or later**
- An Intel or Apple silicon Mac

The apps are built for both Intel and Apple silicon, but the persistent Touch Bar host uses private macOS interfaces. Hardware and macOS versions beyond the developer's current test Mac have not yet been verified.

## Install

1. Download the latest `.dmg` for the app from the project's GitHub Releases page.
2. Open the disk image.
3. Drag **TouchBarpalooza.app** or **poki sitelen.app** into the **Applications** folder shown in the disk image.
4. Open the app from **Applications**.

macOS will probably block the first launch because the app is not Developer ID signed and notarized.

## If macOS blocks the first launch

First try to open the app normally once. Then:

### macOS Ventura and later

1. Open **System Settings**.
2. Choose **Privacy & Security**.
3. Scroll down to the Security section.
4. Find the message about the app you just tried to open.
5. Click **Open Anyway**.
6. Confirm that you want to open it.

### macOS Catalina, Big Sur, or Monterey

1. Open **System Preferences**.
2. Choose **Security & Privacy**.
3. Open the **General** tab.
4. Find the message about the app you just tried to open.
5. Click **Open Anyway** and confirm.

After that first approval, macOS should remember the exception for that copy of the app.

Apple intentionally makes this override explicit because software that is not Developer ID signed and notarized has not been verified by Apple. Only override the warning if you downloaded the app from this project's official repository or release page and you trust that source.

## First launch

Both apps show a short Getting Started window the first time they run.

They also place a **⌂ icon in the macOS menu bar**. From there you can:

- restore the app to the Touch Bar
- reopen Getting Started
- open About
- quit the app

The **⌂ button in the Touch Bar Control Strip** also restores the persistent Touch Bar after you dismiss it.

## Permissions

TouchBarpalooza no longer asks for privacy permissions just because it launched.

- **Spectrum** asks for microphone permission only when you open Spectrum.
- **Mario** asks for Input Monitoring only when you open Mario, because its global keyboard controls need it.
- The rest of TouchBarpalooza does not require those permissions just to run.
- poki sitelen does not currently require either permission.

## Compatibility note

The project currently targets macOS 10.15 and later and builds universal Intel + Apple silicon binaries. That describes what the project is configured to build, not a promise that every Touch Bar Mac and every macOS release has been physically tested.

The persistent Touch Bar behavior depends on private macOS APIs. Apple can change those APIs between macOS versions.

If it fails on another Mac, please report:

- Mac model and year
- Intel or Apple silicon
- macOS version
- whether the normal Touch Bar works
- what TouchBarpalooza or poki sitelen did when launched
