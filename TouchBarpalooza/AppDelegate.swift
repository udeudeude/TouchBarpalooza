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
        requestInputMonitoringIfNeeded()

        let controller = MainViewController()
        self.controller = controller

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 220),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TouchBarpalooza"
        window.center()
        window.contentViewController = controller
        window.makeKeyAndOrderFront(nil)
        self.window = window

        globalTouchBarController.start()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func requestInputMonitoringIfNeeded() {
        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }
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
