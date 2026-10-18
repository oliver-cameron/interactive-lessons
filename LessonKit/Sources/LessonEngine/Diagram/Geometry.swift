// Plain 2D geometry, so the compiler can be tested without CoreGraphics or SwiftUI.
public struct Vec2: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }

    public var isFinite: Bool { x.isFinite && y.isFinite }
}

public struct Bounds: Equatable, Sendable {
    public var x: ClosedRange<Double>
    public var y: ClosedRange<Double>
}

// Maps maths coordinates (y up) to screen points (y down) and back.
public struct Viewport: Equatable, Sendable {
    public var bounds: Bounds
    public var width: Double
    public var height: Double

    public init(bounds: Bounds, width: Double, height: Double) {
        self.bounds = bounds
        self.width = width
        self.height = height
    }

    // The requested window, widened in x or y about its centre so one maths unit is the same
    // length on both axes. Without this a non-square frame stretches everything: circles
    // become ellipses, and angles (like the 120° between the roots of z³ − 1) are wrong.
    public static func fitting(_ requested: Bounds, width: Double, height: Double) -> Viewport {
        let xSpan = requested.x.upperBound - requested.x.lowerBound
        let ySpan = requested.y.upperBound - requested.y.lowerBound
        guard width > 0, height > 0 else { return Viewport(bounds: requested, width: width, height: height) }
        let scale = min(width / xSpan, height / ySpan)   // points per maths unit
        func widened(_ r: ClosedRange<Double>, to span: Double) -> ClosedRange<Double> {
            let mid = (r.lowerBound + r.upperBound) / 2
            return (mid - span / 2)...(mid + span / 2)
        }
        let bounds = Bounds(x: widened(requested.x, to: width / scale), y: widened(requested.y, to: height / scale))
        return Viewport(bounds: bounds, width: width, height: height)
    }

    public func toScreen(_ p: Vec2) -> Vec2 {
        Vec2((p.x - bounds.x.lowerBound) / (bounds.x.upperBound - bounds.x.lowerBound) * width,
             height - (p.y - bounds.y.lowerBound) / (bounds.y.upperBound - bounds.y.lowerBound) * height)
    }

    public func toMaths(_ p: Vec2) -> Vec2 {
        Vec2(bounds.x.lowerBound + p.x / width * (bounds.x.upperBound - bounds.x.lowerBound),
             bounds.y.lowerBound + (height - p.y) / height * (bounds.y.upperBound - bounds.y.lowerBound))
    }
}
