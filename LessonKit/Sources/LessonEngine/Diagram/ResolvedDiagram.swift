import LessonModel

// A diagram with names replaced by references, built once at load.
public struct ResolvedDiagram {
    public let bounds: Bounds
    public let height: Double
    public let elements: [ResolvedElement]
}

public enum ResolvedScalar {
    case constant(Double)
    case variable(Variable)

    // Reading a variable here is what makes the diagram redraw when it changes.
    @MainActor public var current: Double {
        switch self {
        case .constant(let d): d
        case .variable(let v): Double(storage: v.value) ?? .nan
        }
    }

    public var variable: Variable? {
        if case .variable(let v) = self { v } else { nil }
    }
}

public struct ResolvedPoint {
    public let x: ResolvedScalar
    public let y: ResolvedScalar

    @MainActor public var current: Vec2 { Vec2(x.current, y.current) }
}

public enum LabelAnchor: String, CaseIterable, Sendable {
    case center, above, below, left, right, aboveLeft, aboveRight, belowLeft, belowRight
}

public enum ResolvedElement {
    case axes
    case point(ResolvedPoint, colour: PaletteColor, drag: Bool)
    case segment(from: ResolvedPoint, to: ResolvedPoint, colour: PaletteColor)
    case vector(from: ResolvedPoint, to: ResolvedPoint, colour: PaletteColor)
    case label(at: ResolvedPoint, text: [TextSegment], anchor: LabelAnchor, colour: PaletteColor)
    case plot(name: String, fn: FunctionRegistry.Function, inputs: [Variable], colour: PaletteColor)
}
