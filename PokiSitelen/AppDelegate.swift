import AppKit

final class PokiSitelenAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let welcomeKey = "PokiSitelenHasShownWelcomeV1"

    private let touchBarController = PokiSitelenTouchBarController()
    private var statusItem: NSStatusItem?
    private var welcomeWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Stay out of the foreground during normal use so macOS can supply
        // the native system-modal close box.
        NSApp.setActivationPolicy(.accessory)

        configureApplicationMenu()
        configureStatusItem()
        welcomeWindow = makeWelcomeWindow()

        touchBarController.start()

        let firstLaunch = !UserDefaults.standard.bool(forKey: welcomeKey)
        if firstLaunch {
            UserDefaults.standard.set(true, forKey: welcomeKey)
            showGettingStarted(nil)
        } else {
            DispatchQueue.main.async {
                NSApp.hide(nil)
            }
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "⌂"
        item.button?.toolTip = "poki sitelen"

        let menu = NSMenu()

        let showTouchBarItem = NSMenuItem(
            title: "Show poki sitelen on Touch Bar",
            action: #selector(showTouchBarFromMenu(_:)),
            keyEquivalent: ""
        )
        showTouchBarItem.target = self
        menu.addItem(showTouchBarItem)

        let gettingStartedItem = NSMenuItem(
            title: "Getting Started",
            action: #selector(showGettingStarted(_:)),
            keyEquivalent: ""
        )
        gettingStartedItem.target = self
        menu.addItem(gettingStartedItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(
            title: "About poki sitelen",
            action: #selector(showAboutPanel(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit poki sitelen",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu()
        let applicationMenuItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "poki sitelen")

        let aboutItem = NSMenuItem(
            title: "About poki sitelen",
            action: #selector(showAboutPanel(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = self
        applicationMenu.addItem(aboutItem)

        let gettingStartedItem = NSMenuItem(
            title: "Getting Started",
            action: #selector(showGettingStarted(_:)),
            keyEquivalent: ""
        )
        gettingStartedItem.target = self
        applicationMenu.addItem(gettingStartedItem)

        let showTouchBarItem = NSMenuItem(
            title: "Show poki sitelen on Touch Bar",
            action: #selector(showTouchBarFromMenu(_:)),
            keyEquivalent: ""
        )
        showTouchBarItem.target = self
        applicationMenu.addItem(showTouchBarItem)

        applicationMenu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: "Hide poki sitelen",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        hideItem.target = NSApp
        applicationMenu.addItem(hideItem)
        applicationMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit poki sitelen",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        applicationMenu.addItem(quitItem)

        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func makeWelcomeWindow() -> NSWindow {
        let root = NSView()

        let title = NSTextField(labelWithString: "poki sitelen")
        title.font = .systemFont(ofSize: 27, weight: .semibold)
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = NSTextField(
            labelWithString: "Toki Pona study tools and clipboard history on the Touch Bar."
        )
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let instructions = NSTextField(wrappingLabelWithString: """
        1. Tap poki to open the six-slot clipboard history.
        2. Tap toki to return to the Toki Pona study view.
        3. Tap × to dismiss the app temporarily. Tap ⌂ in the Control Strip or menu bar to restore it.
        """)
        instructions.font = .systemFont(ofSize: 13)
        instructions.translatesAutoresizingMaskIntoConstraints = false

        let note = NSTextField(
            wrappingLabelWithString: "Requires a physical Touch Bar. This experimental build uses private macOS Touch Bar interfaces, so behavior on other Mac models and macOS versions is not yet verified."
        )
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.alignment = .center
        note.translatesAutoresizingMaskIntoConstraints = false

        let closeHint = NSTextField(
            labelWithString: "You can close this window. poki sitelen keeps running from the menu bar."
        )
        closeHint.font = .systemFont(ofSize: 11)
        closeHint.textColor = .tertiaryLabelColor
        closeHint.alignment = .center
        closeHint.translatesAutoresizingMaskIntoConstraints = false

        for subview in [title, subtitle, instructions, note, closeHint] {
            root.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 28),
            title.centerXAnchor.constraint(equalTo: root.centerXAnchor),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            subtitle.centerXAnchor.constraint(equalTo: root.centerXAnchor),

            instructions.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 22),
            instructions.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 50),
            instructions.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -50),

            note.topAnchor.constraint(equalTo: instructions.bottomAnchor, constant: 20),
            note.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 40),
            note.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -40),

            closeHint.topAnchor.constraint(equalTo: note.bottomAnchor, constant: 16),
            closeHint.centerXAnchor.constraint(equalTo: root.centerXAnchor)
        ])

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "poki sitelen"
        window.contentView = root
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    @objc private func showTouchBarFromMenu(_ sender: Any?) {
        touchBarController.showTouchBar()
        DispatchQueue.main.async {
            NSApp.hide(nil)
        }
    }

    @objc private func showGettingStarted(_ sender: Any?) {
        welcomeWindow?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAboutPanel(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(
            options: [
                .applicationName: "poki sitelen",
                .applicationVersion: Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String ?? "0.1",
                .credits: NSAttributedString(
                    string: "Toki Pona study view + six-slot clipboard history."
                )
            ]
        )
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.hide(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showGettingStarted(sender)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchBarController.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
