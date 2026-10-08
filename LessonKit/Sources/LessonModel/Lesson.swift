// A whole lesson file. Variables are an array so the panel can show them in declaration order.
public struct Lesson: Codable, Equatable, Sendable {
    public var variables: [VariableDeclaration]
    public var body: Node

    public init(variables: [VariableDeclaration], body: Node) {
        self.variables = variables
        self.body = body
    }
}
