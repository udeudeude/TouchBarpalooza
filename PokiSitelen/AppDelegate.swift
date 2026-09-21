import AppKit

final class PokiSitelenAppDelegate: NSObject, NSApplicationDelegate {
    private let touchBarController = PokiSitelenTouchBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Match TouchBarpalooza's operating model: stay out of the foreground
        // during normal use so macOS can supply the native system-modal X.
        NSApp.setActivationPolicy(.accessory)

        configureApplicationMenu()
        touchBarController.start()

        DispatchQueue.main.async {
            NSApp.hide(nil)
        }
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

    func applicationWillTerminate(_ notification: Notification) {
        touchBarController.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
