// A variable's value. Closed and recursive: a list of points is a list of records.
public enum Value: Equatable, Sendable {
    case number(Double)
    case string(String)
    case bool(Bool)
    case list([Value])
    case record([String: Value])
}

// Lesson JSON writes values as bare literals: 440, "A4", true, [1, 2], {"x": 1}
extension Value: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let d = try? c.decode(Double.self) { self = .number(d) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let l = try? c.decode([Value].self) { self = .list(l) }
        else { self = .record(try c.decode([String: Value].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .number(let d): try c.encode(d)
        case .string(let s): try c.encode(s)
        case .bool(let b):   try c.encode(b)
        case .list(let l):   try c.encode(l)
        case .record(let r): try c.encode(r)
        }
    }
}
