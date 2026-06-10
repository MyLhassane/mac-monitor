import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let statusBarController = StatusBarController()

app.run()
