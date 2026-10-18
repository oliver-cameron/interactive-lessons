import Foundation
import Observation
import LessonModel

@MainActor @Observable
public final class Variable: Identifiable {
    public enum Kind {
        case input
        case computed(inputs: [Variable], compute: FunctionRegistry.Function)
    }

    public let id = UUID()
    public let name: String
    public let kind: Kind
    public let colour: PaletteColor

    // Only the store sets these, so every change goes through propagation.
    public internal(set) var value: Value
    // Set when the variable's function threw; the value is then the last good one.
    public internal(set) var error: String?

    @ObservationIgnored weak var store: VariableStore?

    init(name: String, value: Value, colour: PaletteColor, kind: Kind) {
        self.name = name
        self.value = value
        self.colour = colour
        self.kind = kind
    }

    public func write(_ newValue: Value) {
        store?.write(newValue, to: self)
    }
}
