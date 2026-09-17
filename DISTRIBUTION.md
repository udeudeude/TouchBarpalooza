# TouchBarpalooza distribution

TouchBarpalooza can be built and used as a normal standalone macOS application while development continues. The Git repository remains the source of truth; each exported `.app` is only a snapshot of the code at that moment.

## Local standalone build

From the repository root:

```bash
bash scripts/build-local-release.sh
```

The script builds the Release configuration and creates:

```text
dist/TouchBarpalooza.app
dist/TouchBarpalooza.zip
```

To also replace the installed copy in `/Applications` and launch it:

```bash
bash scripts/build-local-release.sh --install
```

If macOS denies permission to replace the app in `/Applications`, copy `dist/TouchBarpalooza.app` there with Finder instead.

Because TouchBarpalooza uses microphone input and global keyboard monitoring, macOS privacy permissions may need to be granted to the installed copy. Keeping the bundle identifier stable helps macOS recognize successive builds, but signing identity changes can still cause permissions to be requested again.

## Xcode archive workflow

For a graphical release build:

1. Open `TouchBarpalooza.xcodeproj`.
2. Select the TouchBarpalooza target and **My Mac**.
3. Choose **Product > Archive**.
4. In Organizer, select the new archive.
5. Use **Distribute App** for the desired signing/export method.

The current bundle identifier is:

```text
com.udeudeude.TouchBarpalooza
```

The marketing version and build number are Xcode build settings. `Info.plist` reads those values through `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)` so they do not need to be maintained in two places.

## Continuing development

A standalone build does not freeze the program. The normal cycle is:

```text
edit source -> build/test -> commit -> make a new Release build -> replace the installed app
```

Large architectural changes, new games, new Touch Bar modes, and future interface work can all continue normally.

## Public distribution later

The Mac App Store is not an appropriate target because persistent Touch Bar hosting currently depends on private system-modal Touch Bar APIs and `DFRFoundation`.

For public distribution outside the Mac App Store, the eventual release checklist should include:

- a stable Apple Developer ID signing identity
- Hardened Runtime testing
- any required entitlements, including audio input if Hardened Runtime is enabled
- notarization
- a real application icon packaged in the app bundle
- testing on multiple Intel and Apple silicon Touch Bar MacBook Pro models
- testing across the macOS versions the project intends to support
- a clean first-launch permissions test
- a signed zip or disk image for download

Do not enable Hardened Runtime or change signing requirements immediately before a release without retesting the private Touch Bar host, microphone spectrum view, global keyboard controls, and privacy prompts. Those are the parts most likely to expose signing or entitlement problems.
