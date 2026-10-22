import AppKit

let supportDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/PPPKeeper")

final class AppDelegate: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let statusLine = NSMenuItem(title: "Stopped", action: nil, keyEquivalent: "")
    let startItem = NSMenuItem(title: "Start", action: #selector(start), keyEquivalent: "s")
    let stopItem = NSMenuItem(title: "Stop", action: #selector(stop), keyEquivalent: "x")
    var firstSeenConnected: Date?  // fallback when the status file has no timestamp

    func applicationDidFinishLaunching(_ n: Notification) {
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        for i in [startItem, stopItem] { i.target = self; menu.addItem(i) }
        menu.addItem(.separator())
        let log = NSMenuItem(title: "Show Log", action: #selector(showLog), keyEquivalent: "l")
        log.target = self
        menu.addItem(log)
        let quit = NSMenuItem(title: "Stop & Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        // .common mode so the counter keeps ticking while the menu is open
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        refresh()
    }

    func keeperRunning() -> Bool {
        guard let s = try? String(contentsOf: supportDir.appendingPathComponent("keeper.pid"), encoding: .utf8),
              let pid = Int32(s.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        // EPERM means it exists but belongs to root
        return kill(pid, 0) == 0 || errno == EPERM
    }

    func refresh() {
        // status file is "<state>" or "connected <epoch-seconds>"
        let parts = ((try? String(contentsOf: supportDir.appendingPathComponent("status"), encoding: .utf8)) ?? "stopped")
            .split(separator: " ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var state = parts.first ?? "stopped"
        if !keeperRunning() { state = "stopped" }
        if state == "connected" { firstSeenConnected = firstSeenConnected ?? Date() } else { firstSeenConnected = nil }
        let since = (parts.count > 1 ? Double(parts[1]).map { Date(timeIntervalSince1970: $0) } : nil) ?? firstSeenConnected

        let (dot, text): (String, String)
        var bar = "PPP"
        switch state {
        case "connected":
            let t = max(0, Int(Date().timeIntervalSince(since!)))
            let up = String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60)
            (dot, text) = ("🟢", "Connected – \(up)")
            bar = up
        case "connecting": (dot, text) = ("🟡", "Connecting…")
        case "retrying": (dot, text) = ("🟠", "Disconnected – retrying…")
        default: (dot, text) = ("⚪️", "Stopped")
        }
        item.button?.title = "\(dot) \(bar)"
        statusLine.title = text
        startItem.isEnabled = state == "stopped"
        stopItem.isEnabled = state != "stopped"
    }

    @objc func start() {
        let keeper = Bundle.main.path(forResource: "keeper", ofType: "sh")!
        func q(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let cmd = "/bin/bash \(q(keeper)) \(q(supportDir.path)) >/dev/null 2>&1 &"
        let script = "do shell script \"\(cmd.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        try? p.run()
    }

    @objc func stop() {
        FileManager.default.createFile(atPath: supportDir.appendingPathComponent("stop").path, contents: nil)
    }

    @objc func showLog() {
        let log = supportDir.appendingPathComponent("keeper.log")
        if !FileManager.default.fileExists(atPath: log.path) { FileManager.default.createFile(atPath: log.path, contents: nil) }
        NSWorkspace.shared.open([log], withApplicationAt: URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"),
                                configuration: NSWorkspace.OpenConfiguration())
    }

    @objc func quit() {
        if keeperRunning() { stop() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
