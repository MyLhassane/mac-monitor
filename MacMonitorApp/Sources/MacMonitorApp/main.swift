import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let lockPath = "/tmp/MacMonitorApp.pid"
if let oldPID = try? String(contentsOfFile: lockPath).trimmingCharacters(in: .whitespacesAndNewlines),
   let pid = pid_t(oldPID),
   kill(pid, 0) == 0 {
    print("MacMonitorApp is already running (PID \(pid)). Exiting.")
    exit(0)
}
try? "\(ProcessInfo.processInfo.processIdentifier)".write(toFile: lockPath, atomically: true, encoding: .utf8)

let statusBarController = StatusBarController()

app.run()
