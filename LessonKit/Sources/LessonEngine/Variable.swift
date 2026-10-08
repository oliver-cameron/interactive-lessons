import Foundation
import Observation
import LessonModel

@MainActor @Observable
public final class Variable: Identifiable {
    public enum Kind {
        case input
        case computed(inputs: [Variable], compute: ([Value]) -> Value)
    }

    public let id = UUID()
    public let name: String
    public let kind: Kind
    public var colour: String?

    // Only the store sets this, so every change goes through propagation.
    public internal(set) var value: Value

    @ObservationIgnored weak var store: VariableStore?

    init(name: String, value: Value, colour: String?, kind: Kind) {
        self.name = name
        self.value = value
        self.colour = colour
        self.kind = kind
    }

    public func write(_ newValue: Value) {
        store?.write(newValue, to: self)
    }
}
