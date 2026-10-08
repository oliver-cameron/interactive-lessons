import LessonModel

// Built-in computations, looked up by the name in a declaration's "fn" field.
public struct FunctionRegistry: Sendable {
    public typealias Function = @Sendable ([Value]) -> Value

    private var functions: [String: Function]

    public init(_ functions: [String: Function]) {
        self.functions = functions
    }

    public subscript(name: String) -> Function? { functions[name] }

    public static let standard = FunctionRegistry([
        "reciprocal": { inputs in
            guard case .number(let x) = inputs.first, x != 0 else { return .number(.nan) }
            return .number(1 / x)
        },
    ])
}
