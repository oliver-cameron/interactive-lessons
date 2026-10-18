#if canImport(JavaScriptCore)
import JavaScriptCore
import LessonModel
import LessonEngine

extension FunctionRegistry {
    // Compiles the lesson's "functions" section and adds each one by name. Each source is a
    // JavaScript function expression, e.g. "(a, x) => a * Math.sin(x)". Arguments arrive as
    // plain JavaScript values (numbers, strings, booleans, arrays, objects); the return
    // value converts back to a Value the same way.
    //
    // There is no time limit: JavaScriptCore's public API can't interrupt a running script,
    // so a function that loops forever hangs the app. A watchdog is still to do (design.md §4).
    @MainActor
    public mutating func addJavaScript(_ sources: [String: String]) throws(LoadError) {
        guard !sources.isEmpty else { return }
        let runtime = ScriptRuntime()
        for (name, source) in sources.sorted(by: { $0.key < $1.key }) {
            let function = try runtime.compile(name, source)
            self[name] = { inputs in try runtime.call(function, name, inputs) }
        }
    }
}

// One JavaScript context per lesson, shared by its functions, used only on the main actor.
@MainActor
final class ScriptRuntime {
    private let context: JSContext

    init() {
        context = JSContext()!
    }

    func compile(_ name: String, _ source: String) throws(LoadError) -> JSValue {
        let value = context.evaluateScript("(\(source))")
        if let message = takeException() { throw LoadError.scriptError(function: name, message: message) }
        guard let value, value.isObject else {
            throw LoadError.scriptError(function: name, message: "it isn't a function.")
        }
        return value
    }

    func call(_ function: JSValue, _ name: String, _ inputs: [Value]) throws -> Value {
        let result = function.call(withArguments: inputs.map(Self.foundationObject))
        if let message = takeException() { throw ComputeError("\(name): \(message)") }
        guard let result else { throw ComputeError("\(name) returned nothing.") }
        return try value(from: result, name)
    }

    // The default exception handler stores the exception on the context; take and clear it.
    private func takeException() -> String? {
        guard let exception = context.exception else { return nil }
        context.exception = nil
        return exception.toString()
    }

    private static func foundationObject(_ value: Value) -> Any {
        switch value {
        case .number(let d): d
        case .string(let s): s
        case .bool(let b): b
        case .list(let l): l.map(foundationObject)
        case .record(let r): r.mapValues(foundationObject)
        }
    }

    // Converted by hand, not with toObject(), so booleans stay booleans instead of NSNumbers.
    private func value(from js: JSValue, _ name: String) throws -> Value {
        if js.isBoolean { return .bool(js.toBool()) }
        if js.isNumber { return .number(js.toDouble()) }
        if js.isString { return .string(js.toString()) }
        if js.isArray {
            let count = Int(js.objectForKeyedSubscript("length").toInt32())
            return .list(try (0..<count).map { try value(from: js.atIndex($0), name) })
        }
        if js.isObject {
            let keys = context.objectForKeyedSubscript("Object")
                .invokeMethod("keys", withArguments: [js])
                .toArray() as? [String] ?? []
            var record: [String: Value] = [:]
            for key in keys {
                record[key] = try value(from: js.objectForKeyedSubscript(key), name)
            }
            return .record(record)
        }
        throw ComputeError("\(name) returned \(js.toString() ?? "undefined"), which isn't a value.")
    }
}
#endif
