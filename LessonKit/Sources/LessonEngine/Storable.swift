import LessonModel

// Lets a view ask for the Swift type it needs; the variable converts or falls back.
public protocol Storable: Sendable {
    init?(storage: Value)
    var storage: Value { get }
}

extension Double: Storable {
    public init?(storage: Value) { guard case .number(let d) = storage else { return nil }; self = d }
    public var storage: Value { .number(self) }
}

extension String: Storable {
    public init?(storage: Value) { guard case .string(let s) = storage else { return nil }; self = s }
    public var storage: Value { .string(self) }
}

extension Bool: Storable {
    public init?(storage: Value) { guard case .bool(let b) = storage else { return nil }; self = b }
    public var storage: Value { .bool(self) }
}
