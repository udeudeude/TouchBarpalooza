# TouchBarpalooza distribution

TouchBarpalooza and poki sitelen can be built and distributed as normal standalone macOS applications while development continues. The Git repository remains the source of truth; exported apps are release snapshots.

## Current distribution target: no Apple Developer account

The project currently stops short of Developer ID signing and Apple notarization.

That means downloadable builds can still be packaged cleanly, but macOS will require the user to explicitly approve each app the first time it is opened. The user-facing steps live in [INSTALL_UNSIGNED.md](INSTALL_UNSIGNED.md).

This is the intended stopping point until a paid Apple Developer account is available.

## Build local standalone copies

TouchBarpalooza:

```bash
bash scripts/build-local-release.sh
```

This creates:

```text
dist/TouchBarpalooza.app
dist/TouchBarpalooza.zip
```

To replace the installed copy in `/Applications` and launch it:

```bash
bash scripts/build-local-release.sh --install
```

poki sitelen:

```bash
bash scripts/build-poki-sitelen.sh
```

or:

```bash
bash scripts/build-poki-sitelen.sh --install
```

## Build public unsigned packages

To build both apps as direct-download packages without any Apple Developer credentials:

```bash
bash scripts/package-unsigned-release.sh
```

The script:

1. builds Release versions of both apps with Developer ID signing disabled
2. applies an ad-hoc code signature to each app bundle
3. verifies the resulting bundle signatures
4. creates a disk image for each app with an Applications-folder shortcut and the unsigned-install guide
5. also creates ZIP copies

Output is placed in:

```text
dist/unsigned-release/
```

These packages are **not notarized** and macOS will still show Gatekeeper warnings on first launch.

## GitHub Releases without an Apple Developer account

`.github/workflows/release-unsigned.yml` can package the apps on GitHub Actions.

It can be run manually to produce downloadable workflow artifacts. When a tag beginning with `v` is pushed, the workflow also creates a GitHub Release and attaches the generated DMG and ZIP packages.

No Apple Developer credentials are required for this workflow.

A typical future release sequence is:

```bash
git tag v0.3.0
git push origin v0.3.0
```

Do this only from the commit intended to become the public release.

## First-run experience

Both applications now:

- run primarily as accessory/background utilities
- show a Getting Started window on first launch
- keep a **⌂ menu-bar item** for restoring the Touch Bar, reopening help, About, and Quit
- keep a **⌂ Control Strip launcher** for restoring the persistent Touch Bar after dismissal

TouchBarpalooza no longer requests Input Monitoring at startup. Spectrum requests microphone access only when opened, and Mario requests Input Monitoring only when opened.

## Compatibility

Current build settings target:

- a physical Touch Bar
- macOS 10.15 Catalina or later
- Swift 5
- Intel `x86_64`
- Apple silicon `arm64`

The Intel and Apple silicon architectures are build targets, but persistent Touch Bar behavior has not yet been physically tested across the full range of Touch Bar Macs or macOS releases.

The persistent host depends on private system-modal Touch Bar APIs and `DFRFoundation`. Those interfaces can change between macOS versions, so compatibility claims should remain conservative until reports arrive from additional hardware.

## Xcode archive workflow

For a graphical local archive:

1. Open `TouchBarpalooza.xcodeproj`.
2. Select the TouchBarpalooza target and **My Mac**.
3. Choose **Product > Archive**.
4. In Organizer, select the new archive.

The TouchBarpalooza bundle identifier is:

```text
com.udeudeude.TouchBarpalooza
```

The marketing version and build number are Xcode build settings. `Info.plist` reads those values through `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)`.

## If a Developer account is added later

The next distribution step would be:

- Developer ID Application signing
- Hardened Runtime testing
- required entitlements
- notarization
- stapling the notarization ticket to the downloadable package
- fresh testing of the private Touch Bar host, microphone spectrum view, global keyboard controls, and privacy prompts

The Mac App Store remains a poor fit because persistent Touch Bar hosting currently depends on private macOS APIs.

Do not enable Hardened Runtime or change signing requirements immediately before a release without retesting the private Touch Bar host and the permission-sensitive features.
