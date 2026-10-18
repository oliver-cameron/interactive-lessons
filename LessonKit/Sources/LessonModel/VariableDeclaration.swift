// One entry in the lesson's "variables" array. Either a literal value:
//   { "name": "freq", "value": 440, "colour": "blue" }
// or a function of other variables, named by its inputs:
//   { "name": "period", "fn": "reciprocal", "inputs": ["freq"] }
// "fn" names a built-in or one of the lesson's JavaScript functions.
// The engine checks that exactly one of `value` and `fn` is present, and that the
// colour, if given, is a PaletteColor name.
public struct VariableDeclaration: Codable, Equatable, Sendable {
    public var name: String
    public var value: Value?
    public var fn: String?
    public var inputs: [String]?
    public var colour: String?

    public init(name: String, value: Value? = nil, fn: String? = nil, inputs: [String]? = nil, colour: String? = nil) {
        self.name = name
        self.value = value
        self.fn = fn
        self.inputs = inputs
        self.colour = colour
    }
}
