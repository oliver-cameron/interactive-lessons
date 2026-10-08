// The component tree as saved. Holds variable names, never references; never observable.
// Adding a component: a case here, a decode and encode branch, a case in ResolvedNode,
// a branch in Resolver, and a view in LessonUI. The compiler flags each one in turn.
public indirect enum Node: Equatable, Sendable {
    case vstack([Node])
    case text(String)
    case slider(variable: String, min: Double, max: Double, step: Double?)
    // A component type this version doesn't know. Rendered as a visible error.
    case unknown(type: String)
}

extension Node: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, contents, text, variable, min, max, step
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "vstack":
            self = .vstack(try c.decodeIfPresent([Node].self, forKey: .contents) ?? [])
        case "text":
            self = .text(try c.decode(String.self, forKey: .text))
        case "slider":
            self = .slider(variable: try c.decode(String.self, forKey: .variable),
                           min: try c.decode(Double.self, forKey: .min),
                           max: try c.decode(Double.self, forKey: .max),
                           step: try c.decodeIfPresent(Double.self, forKey: .step))
        default:
            self = .unknown(type: type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .vstack(let contents):
            try c.encode("vstack", forKey: .type)
            try c.encode(contents, forKey: .contents)
        case .text(let text):
            try c.encode("text", forKey: .type)
            try c.encode(text, forKey: .text)
        case .slider(let variable, let min, let max, let step):
            try c.encode("slider", forKey: .type)
            try c.encode(variable, forKey: .variable)
            try c.encode(min, forKey: .min)
            try c.encode(max, forKey: .max)
            try c.encodeIfPresent(step, forKey: .step)
        case .unknown(let type):
            // Only the type survives; the unknown component's other fields are lost.
            try c.encode(type, forKey: .type)
        }
    }
}
