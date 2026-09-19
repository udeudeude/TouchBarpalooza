import AppKit

let app = NSApplication.shared
let delegate = PokiSitelenAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
