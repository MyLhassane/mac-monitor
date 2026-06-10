import Cocoa

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    override init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        button.attributedTitle = StatusBarIcon.attributed(cpu: 0, mem: 0)
        button.action = #selector(togglePopover)
        button.target = self

        let contentView = PopoverContentView()
        let hostingVC = NSViewController()
        hostingVC.view = contentView

        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 540)
        popover.behavior = .transient
        popover.contentViewController = hostingVC
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func updateStatus(cpu: Double, mem: Double) {
        statusItem.button?.attributedTitle = StatusBarIcon.attributed(cpu: cpu, mem: mem)
    }
}
