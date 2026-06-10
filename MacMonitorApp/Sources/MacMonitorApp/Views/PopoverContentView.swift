import Cocoa

class PopoverContentView: NSView {
    private let tabs = NSTabView()

    override var intrinsicContentSize: NSSize { NSSize(width: 420, height: 520) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        tabs.translatesAutoresizingMaskIntoConstraints = false
        tabs.tabViewType = .topTabsBezelBorder
        tabs.font = NSFont.systemFont(ofSize: 12)

        tabs.addTabViewItem(NSTabViewItem(identifier: "processes", label: "Processes", view: ProcessTableView()))
        tabs.addTabViewItem(NSTabViewItem(identifier: "thermal", label: "Thermal", view: ThermalView()))
        tabs.addTabViewItem(NSTabViewItem(identifier: "network", label: "Network", view: NetworkView()))
        tabs.addTabViewItem(NSTabViewItem(identifier: "history", label: "History", view: HistoryChartView()))

        addSubview(tabs)
        NSLayoutConstraint.activate([
            tabs.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            tabs.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            tabs.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            tabs.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) { nil }
}

extension NSTabViewItem {
    convenience init(identifier: String, label: String, view: NSView) {
        self.init(identifier: identifier)
        self.label = label
        self.view = view
        view.autoresizingMask = [.width, .height]
    }
}
