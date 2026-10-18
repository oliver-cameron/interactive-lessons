import Foundation
import LessonModel

extension Value {
    // How a value reads in text, labels and the variable panel.
    public var displayString: String {
        switch self {
        case .number(let d): Self.format(d)
        case .string(let s): s
        case .bool(let b): b ? "true" : "false"
        case .list(let l): "[" + l.map(\.displayString).joined(separator: ", ") + "]"
        case .record(let r): "{" + r.keys.sorted().map { "\($0): \(r[$0]!.displayString)" }.joined(separator: ", ") + "}"
        }
    }

    static func format(_ d: Double) -> String {
        if d.isNaN { return "undefined" }
        if d.isInfinite { return d > 0 ? "∞" : "−∞" }
        if d == d.rounded(), abs(d) < 1e15 { return String(Int64(d)) }
        // Four significant figures for small numbers, one decimal place for large ones.
        return abs(d) >= 1000 ? String(format: "%.1f", d) : String(format: "%.4g", d)
    }
}
