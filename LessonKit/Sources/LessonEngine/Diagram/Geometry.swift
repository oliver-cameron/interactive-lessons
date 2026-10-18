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

    public func toScreen(_ p: Vec2) -> Vec2 {
        Vec2((p.x - bounds.x.lowerBound) / (bounds.x.upperBound - bounds.x.lowerBound) * width,
             height - (p.y - bounds.y.lowerBound) / (bounds.y.upperBound - bounds.y.lowerBound) * height)
    }

    public func toMaths(_ p: Vec2) -> Vec2 {
        Vec2(bounds.x.lowerBound + p.x / width * (bounds.x.upperBound - bounds.x.lowerBound),
             bounds.y.lowerBound + (height - p.y) / height * (bounds.y.upperBound - bounds.y.lowerBound))
    }
}
