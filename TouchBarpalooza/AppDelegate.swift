import AppKit
import CoreGraphics

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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var controller: MainViewController?
    private let globalTouchBarController = GlobalTouchBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplicationMenu()
        requestInputMonitoringIfNeeded()

        let controller = MainViewController()
        self.controller = controller

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 220),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TouchBarpalooza \(shortVersion)"
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("TouchBarpaloozaMainWindow")
        if !window.setFrameUsingName("TouchBarpaloozaMainWindow") {
            window.center()
        }
        window.contentViewController = controller
        self.window = window

        globalTouchBarController.start()

        // TouchBarpalooza is primarily a persistent background Touch Bar utility.
        // Returning focus to the user's current app also lets macOS display the
        // native system-modal close box consistently during normal use.
        DispatchQueue.main.async {
            NSApp.hide(nil)
        }
    }

    private var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
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
            title: "Show TouchBarpalooza Window",
            action: #selector(showMainWindow(_:)),
            keyEquivalent: ""
        )
        showWindowItem.target = self
        applicationMenu.addItem(showWindowItem)

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

    @objc private func showAboutPanel(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showMainWindow(_ sender: Any?) {
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func requestInputMonitoringIfNeeded() {
        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
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
