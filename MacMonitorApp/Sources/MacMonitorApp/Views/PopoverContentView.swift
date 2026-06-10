import Cocoa

class PopoverContentView: NSView {
    private let tabs = NSTabView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
    }

    required init?(coder: NSCoder) { nil }

    private func buildUI() {
        tabs.translatesAutoresizingMaskIntoConstraints = false
        tabs.tabViewType = .topTabsBezelBorder
        tabs.font = NSFont.systemFont(ofSize: 12)

        tabs.addTabViewItem(NSTabViewItem(identifier: "processes", label: "Processes", view: ProcessTableView()))
        tabs.addTabViewItem(NSTabViewItem(identifier: "thermal", label: "Thermal", view: PlaceholderView(label: "Thermal sensors (SMC) — coming soon")))
        tabs.addTabViewItem(NSTabViewItem(identifier: "network", label: "Network", view: PlaceholderView(label: "Network usage — coming soon")))
        tabs.addTabViewItem(NSTabViewItem(identifier: "history", label: "History", view: PlaceholderView(label: "Historical charts (SQLite) — coming soon")))

        addSubview(tabs)
        NSLayoutConstraint.activate([
            tabs.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            tabs.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            tabs.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            tabs.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }
}

extension NSTabViewItem {
    convenience init(identifier: String, label: String, view: NSView) {
        self.init(identifier: identifier as NSTabViewItem.Identifier)
        self.label = label
        self.view = view
        view.autoresizingMask = [.width, .height]
    }
}
