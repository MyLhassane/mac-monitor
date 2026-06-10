import Cocoa

class ProcessTableView: NSView {
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private var processes: [(pid: Int, name: String, cpu: Double, mem: Double, desc: String)] = [
        (0,    "kernel_task",      12.5, 0.2, "CPU thermal management"),
        (1,    "launchd",           0.0, 0.5, "Service manager"),
        (94,   "WindowServer",      8.2, 1.8, "Window compositor"),
        (112,  "usbd",              0.0, 0.1, "USB device handling"),
        (208,  "opendirectoryd",    0.0, 0.3, "Directory services"),
        (389,  "systemstats",       1.5, 0.4, "System statistics daemon"),
        (444,  "airportd",          0.0, 0.2, "Wi-Fi management"),
        (456,  "WiFiAgent",         0.3, 1.1, "Wi-Fi status menu"),
        (478,  "thermalmonitord",   2.1, 0.3, "Thermal monitoring"),
        (5678, "Finder",            1.2, 3.1, "File manager GUI"),
        (9101, "Terminal",          0.8, 0.9, "Command line interface"),
        (8877, "Safari",           14.3, 7.2, "Web browser"),
        (3344, "Music",             0.0, 4.5, "Media player"),
        (1121, "Dock",              0.3, 1.5, "Application dock"),
        (2200, "NotificationCenter",0.1, 0.8, "Notifications UI"),
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
    }

    required init?(coder: NSCoder) { nil }

    private func buildUI() {
        let cols: [(id: String, title: String, width: CGFloat)] = [
            ("pid", "PID", 50),
            ("name", "Name", 140),
            ("cpu", "CPU%", 50),
            ("mem", "MEM%", 50),
            ("desc", "Description", 120),
        ]
        for col in cols {
            let tc = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(col.id))
            tc.title = col.title
            tc.width = col.width
            tc.minWidth = col.width
            tableView.addTableColumn(tc)
        }

        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView?.frame.size.height = 20
        tableView.rowHeight = 18
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.target = self
        tableView.doubleAction = #selector(doubleClick)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Kill Process", action: #selector(killProcess), keyEquivalent: "k"))
        tableView.menu = menu

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    override var intrinsicContentSize: NSSize {
        let rowArea = CGFloat(processes.count) * tableView.rowHeight + (tableView.headerView?.frame.height ?? 20)
        return NSSize(width: NSView.noIntrinsicMetric, height: min(rowArea + 4, 480))
    }

    @objc func doubleClick(_ sender: Any?) { killProcess(sender) }
    @objc func killProcess(_ sender: Any?) {
        let row = tableView.clickedRow
        guard row >= 0, row < processes.count else { return }
        let pid = processes[row].pid
        kill(pid_t(pid), SIGKILL)
        processes.remove(at: row)
        tableView.reloadData()
    }
}

extension ProcessTableView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { processes.count }
}

extension ProcessTableView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let id = tableColumn?.identifier.rawValue else { return nil }
        let p = processes[row]

        let text: String
        switch id {
        case "pid": text = "\(p.pid)"
        case "name": text = p.name
        case "cpu": text = String(format: "%.1f", p.cpu)
        case "mem": text = String(format: "%.1f", p.mem)
        case "desc": text = p.desc
        default: text = ""
        }

        let cell = NSTextField(labelWithString: text)
        cell.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        cell.lineBreakMode = .byTruncatingTail
        return cell
    }
}
