// A whole lesson file. Variables are an array so the panel can show them in declaration order.
public struct Lesson: Codable, Equatable, Sendable {
    public var variables: [VariableDeclaration]
    // JavaScript functions by name, e.g. "wave": "(a, x) => a * Math.sin(x)".
    // Variables and plots call them through "fn", like the built-in functions.
    public var functions: [String: String]?
    public var body: Node

    public init(variables: [VariableDeclaration], functions: [String: String]? = nil, body: Node) {
        self.variables = variables
        self.functions = functions
        self.body = body
    }
}
