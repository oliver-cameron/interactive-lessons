import SwiftUI
import LessonModel
import LessonEngine

extension PaletteColor {
    // System colours, so each name adapts to dark mode and Increase Contrast.
    public var color: Color {
        switch self {
        case .red: .red
        case .blue: .blue
        case .green: .green
        case .purple: .purple
        case .orange: .orange
        case .black: .primary
        }
    }
}

extension Ink {
    var color: Color {
        switch self {
        case .palette(let p): p.color
        case .axis: .secondary
        case .error: .red
        }
    }
}
