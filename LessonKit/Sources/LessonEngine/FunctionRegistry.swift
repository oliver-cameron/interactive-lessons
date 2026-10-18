import LessonModel

// Why a function couldn't produce a value. Shown on the variable or plot that called it.
public struct ComputeError: Error, Equatable, CustomStringConvertible {
    public var message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}

// Computations looked up by the name in a declaration's or plot's "fn" field: the built-ins,
// plus any the lesson defines in JavaScript (added by LessonScript). Called on the main actor.
public struct FunctionRegistry {
    public typealias Function = ([Value]) throws -> Value

    private var functions: [String: Function]

    public init(_ functions: [String: Function]) {
        self.functions = functions
    }

    public subscript(name: String) -> Function? {
        get { functions[name] }
        set { functions[name] = newValue }
    }

    public static var standard: FunctionRegistry {
        FunctionRegistry([
            "reciprocal": { inputs in
                guard case .number(let x) = inputs.first else { throw ComputeError("reciprocal needs a number.") }
                return .number(1 / x)
            },
        ])
    }
}
