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
        requestEscapePostingAccessIfNeeded()

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
        window.makeKeyAndOrderFront(nil)
        self.window = window

        globalTouchBarController.start()
        NSApp.activate(ignoringOtherApps: true)
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

        let escapePermissionItem = NSMenuItem(
            title: "Enable Touch Bar Escape…",
            action: #selector(enableEscapePermission(_:)),
            keyEquivalent: ""
        )
        escapePermissionItem.target = self
        applicationMenu.addItem(escapePermissionItem)
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

    private func requestEscapePostingAccessIfNeeded() {
        if !CGPreflightPostEventAccess() {
            _ = CGRequestPostEventAccess()
        }
    }

    @objc private func enableEscapePermission(_ sender: Any?) {
        guard !CGPreflightPostEventAccess() else { return }

        _ = CGRequestPostEventAccess()

        // If the one-shot privacy prompt has already been dismissed or denied,
        // take the user directly to the pane where PostEvent access is managed.
        if !CGPreflightPostEventAccess(),
           let url = URL(
               string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
           ) {
            NSWorkspace.shared.open(url)
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
