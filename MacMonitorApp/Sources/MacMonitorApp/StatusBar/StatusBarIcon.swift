import Cocoa

struct StatusBarIcon {
    static func attributed(cpu: Double, mem: Double) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let mono: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
        ]
        let dim: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        result.append(NSAttributedString(string: "⟳ ", attributes: dim))
        result.append(NSAttributedString(string: format(cpu), attributes: mono))
        result.append(NSAttributedString(string: " ", attributes: dim))
        result.append(NSAttributedString(string: format(mem), attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: color(for: mem),
        ]))

        return result
    }

    private static func format(_ val: Double) -> String {
        if val < 10 { return String(format: "%.1f", val) }
        if val < 100 { return String(format: "%.0f", val) }
        return ">99"
    }

    private static func color(for mem: Double) -> NSColor {
        if mem > 80 { return NSColor.systemRed }
        if mem > 50 { return NSColor.systemOrange }
        return NSColor.systemGreen
    }
}
