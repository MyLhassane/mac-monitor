import Cocoa

class PlaceholderView: NSView {
    private let label = NSTextField(labelWithString: "")

    init(label text: String) {
        super.init(frame: .zero)
        label.stringValue = text
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        label.font = NSFont.systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { nil }
}
