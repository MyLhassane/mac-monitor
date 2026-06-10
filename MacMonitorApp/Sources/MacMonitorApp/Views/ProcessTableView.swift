import Cocoa

class ProcessTableView: NSView {
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private var processes: [(pid: Int, name: String, cpu: Double, mem: Double, desc: String)] = [
        (1234, "kernel_task", 12.5, 0.2, "CPU thermal management"),
        (5678, "Finder", 1.2, 3.1, "File manager GUI"),
        (9101, "Terminal", 0.8, 0.9, "Command line interface"),
        (1121, "Dock", 0.3, 1.5, "Application dock"),
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
