import AppKit
import CoreGraphics

final class PokiSitelenAppDelegate: NSObject, NSApplicationDelegate {
    private let touchBarController = PokiSitelenTouchBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplicationMenu()
        requestEscapePostingAccessIfNeeded()
        touchBarController.start()
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

        let escapePermissionItem = NSMenuItem(
            title: "Enable Touch Bar Escape…",
            action: #selector(enableEscapePermission(_:)),
            keyEquivalent: ""
        )
        escapePermissionItem.target = self
        applicationMenu.addItem(escapePermissionItem)
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

    private func requestEscapePostingAccessIfNeeded() {
        if !CGPreflightPostEventAccess() {
            _ = CGRequestPostEventAccess()
        }
    }

    @objc private func enableEscapePermission(_ sender: Any?) {
        guard !CGPreflightPostEventAccess() else { return }

        _ = CGRequestPostEventAccess()

        if !CGPreflightPostEventAccess(),
           let url = URL(
               string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
           ) {
            NSWorkspace.shared.open(url)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        touchBarController.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
