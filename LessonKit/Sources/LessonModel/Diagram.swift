// A diagram as saved: a maths-coordinate window and a list of named elements.
//   { "type": "diagram", "x": [-5, 5], "y": [-3, 3], "height": 300, "elements": [
//       { "type": "axes" },
//       { "type": "vector", "to": ["ax", "ay"] },
//       { "type": "point", "at": ["ax", "ay"], "drag": true } ] }
// Positions are in maths units. Sizes of decorations (arrowheads, dots, label offsets)
// are in screen points and chosen by the renderer, so zooming doesn't enlarge them.
public struct Diagram: Equatable, Sendable {
    public var x: [Double]
    public var y: [Double]
    public var height: Double?
    public var elements: [DiagramElement]

    public init(x: [Double], y: [Double], height: Double? = nil, elements: [DiagramElement]) {
        self.x = x
        self.y = y
        self.height = height
        self.elements = elements
    }
}

extension Diagram: Codable {}

// A number, or the name of a variable whose value is used.
public enum Scalar: Equatable, Sendable {
    case constant(Double)
    case variable(String)
}

extension Scalar: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { self = .constant(d) }
        else { self = .variable(try c.decode(String.self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .constant(let d): try c.encode(d)
        case .variable(let name): try c.encode(name)
        }
    }
}

// Written as a two-element array: [1, "ay"].
public struct Point: Equatable, Sendable {
    public var x: Scalar
    public var y: Scalar

    public init(_ x: Scalar, _ y: Scalar) {
        self.x = x
        self.y = y
    }
}

extension Point: Codable {
    public init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        x = try c.decode(Scalar.self)
        y = try c.decode(Scalar.self)
        guard c.isAtEnd else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "A point has exactly two coordinates.")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(x)
        try c.encode(y)
    }
}

// Adding an element type: a case here, its decode and encode branches, a case in
// ResolvedElement, a branch in Resolver and one in DiagramCompiler. Renderer untouched.
public enum DiagramElement: Equatable, Sendable {
    case axes
    case point(at: Point, colour: String?, drag: Bool)
    case segment(from: Point, to: Point, colour: String?)
    // From the origin unless `from` is given.
    case vector(from: Point?, to: Point, colour: String?)
    // Text may interpolate \var{name}. Anchor is where the label sits relative to `at`.
    case label(at: Point, text: String, anchor: String?, colour: String?)
    // y = fn(x, inputs...). The function is a built-in or a lesson JavaScript function.
    case plot(fn: String, inputs: [String], colour: String?)
    case unknown(type: String)
}

extension DiagramElement: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, at, from, to, colour, drag, text, anchor, fn, inputs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        let colour = try c.decodeIfPresent(String.self, forKey: .colour)
        switch type {
        case "axes":
            self = .axes
        case "point":
            self = .point(at: try c.decode(Point.self, forKey: .at), colour: colour,
                          drag: try c.decodeIfPresent(Bool.self, forKey: .drag) ?? false)
        case "segment":
            self = .segment(from: try c.decode(Point.self, forKey: .from),
                            to: try c.decode(Point.self, forKey: .to), colour: colour)
        case "vector":
            self = .vector(from: try c.decodeIfPresent(Point.self, forKey: .from),
                           to: try c.decode(Point.self, forKey: .to), colour: colour)
        case "label":
            self = .label(at: try c.decode(Point.self, forKey: .at), text: try c.decode(String.self, forKey: .text),
                          anchor: try c.decodeIfPresent(String.self, forKey: .anchor), colour: colour)
        case "plot":
            self = .plot(fn: try c.decode(String.self, forKey: .fn),
                         inputs: try c.decodeIfPresent([String].self, forKey: .inputs) ?? [], colour: colour)
        default:
            self = .unknown(type: type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .axes:
            try c.encode("axes", forKey: .type)
        case .point(let at, let colour, let drag):
            try c.encode("point", forKey: .type)
            try c.encode(at, forKey: .at)
            try c.encodeIfPresent(colour, forKey: .colour)
            if drag { try c.encode(true, forKey: .drag) }
        case .segment(let from, let to, let colour):
            try c.encode("segment", forKey: .type)
            try c.encode(from, forKey: .from)
            try c.encode(to, forKey: .to)
            try c.encodeIfPresent(colour, forKey: .colour)
        case .vector(let from, let to, let colour):
            try c.encode("vector", forKey: .type)
            try c.encodeIfPresent(from, forKey: .from)
            try c.encode(to, forKey: .to)
            try c.encodeIfPresent(colour, forKey: .colour)
        case .label(let at, let text, let anchor, let colour):
            try c.encode("label", forKey: .type)
            try c.encode(at, forKey: .at)
            try c.encode(text, forKey: .text)
            try c.encodeIfPresent(anchor, forKey: .anchor)
            try c.encodeIfPresent(colour, forKey: .colour)
        case .plot(let fn, let inputs, let colour):
            try c.encode("plot", forKey: .type)
            try c.encode(fn, forKey: .fn)
            try c.encode(inputs, forKey: .inputs)
            try c.encodeIfPresent(colour, forKey: .colour)
        case .unknown(let type):
            try c.encode(type, forKey: .type)
        }
    }
}
