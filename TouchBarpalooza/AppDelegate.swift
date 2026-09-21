import AppKit

extension NSButton {
    var periodicDelay: Float {
        get {
            var delay: Float = 0
            var interval: Float = 0
            getPeriodicDelay(&delay, interval: &interval)
            return delay
        }
        set {
            var delay: Float = 0
            var interval: Float = 0
            getPeriodicDelay(&delay, interval: &interval)
            setPeriodicDelay(newValue, interval: interval)
        }
    }

    var periodicInterval: Float {
        get {
            var delay: Float = 0
            var interval: Float = 0
            getPeriodicDelay(&delay, interval: &interval)
            return interval
        }
        set {
            var delay: Float = 0
            var interval: Float = 0
            getPeriodicDelay(&delay, interval: &interval)
            setPeriodicDelay(delay, interval: newValue)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let welcomeKey = "TouchBarpaloozaHasShownWelcomeV1"

    private var window: NSWindow?
    private var controller: MainViewController?
    private var statusItem: NSStatusItem?
    private let globalTouchBarController = GlobalTouchBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // TouchBarpalooza is primarily a persistent Touch Bar utility. Run as
        // an accessory app so normal use does not steal foreground focus.
        NSApp.setActivationPolicy(.accessory)

        configureApplicationMenu()
        configureStatusItem()

        let controller = MainViewController()
        self.controller = controller

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 340),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TouchBarpalooza \(shortVersion)"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName("TouchBarpaloozaMainWindow")
        if !window.setFrameUsingName("TouchBarpaloozaMainWindow") {
            window.center()
        }
        window.contentViewController = controller
        window.orderOut(nil)
        self.window = window

        globalTouchBarController.start()

        let firstLaunch = !UserDefaults.standard.bool(forKey: welcomeKey)
        if firstLaunch {
            UserDefaults.standard.set(true, forKey: welcomeKey)
            showMainWindow(nil)
        } else {
            DispatchQueue.main.async {
                NSApp.hide(nil)
            }
        }
    }

    private var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "⌂"
        item.button?.toolTip = "TouchBarpalooza"

        let menu = NSMenu()

        let showTouchBarItem = NSMenuItem(
            title: "Show TouchBarpalooza on Touch Bar",
            action: #selector(showTouchBarFromMenu(_:)),
            keyEquivalent: ""
        )
        showTouchBarItem.target = self
        menu.addItem(showTouchBarItem)

        let gettingStartedItem = NSMenuItem(
            title: "Getting Started",
            action: #selector(showMainWindow(_:)),
            keyEquivalent: ""
        )
        gettingStartedItem.target = self
        menu.addItem(gettingStartedItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(
            title: "About TouchBarpalooza",
            action: #selector(showAboutPanel(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit TouchBarpalooza",
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
        let applicationMenu = NSMenu(title: "TouchBarpalooza")

        let aboutItem = NSMenuItem(
            title: "About TouchBarpalooza",
            action: #selector(showAboutPanel(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = self
        applicationMenu.addItem(aboutItem)

        let showWindowItem = NSMenuItem(
            title: "Getting Started",
            action: #selector(showMainWindow(_:)),
            keyEquivalent: ""
        )
        showWindowItem.target = self
        applicationMenu.addItem(showWindowItem)

        let showTouchBarItem = NSMenuItem(
            title: "Show TouchBarpalooza on Touch Bar",
            action: #selector(showTouchBarFromMenu(_:)),
            keyEquivalent: ""
        )
        showTouchBarItem.target = self
        applicationMenu.addItem(showTouchBarItem)

        applicationMenu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: "Hide TouchBarpalooza",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        hideItem.target = NSApp
        applicationMenu.addItem(hideItem)
        applicationMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit TouchBarpalooza",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        applicationMenu.addItem(quitItem)

        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func showTouchBarFromMenu(_ sender: Any?) {
        globalTouchBarController.showTouchBar()
        DispatchQueue.main.async {
            NSApp.hide(nil)
        }
    }

    @objc private func showAboutPanel(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showMainWindow(_ sender: Any?) {
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.hide(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow(sender)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalTouchBarController.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
