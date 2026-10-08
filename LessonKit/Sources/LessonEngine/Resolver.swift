import LessonModel

@MainActor
public struct LoadedLesson {
    public let store: VariableStore
    public let body: ResolvedNode
}

// Loading is a compile step: build the store, then resolve every name in the tree once.
@MainActor
public enum Resolver {
    public static func load(_ lesson: Lesson, functions: FunctionRegistry = .standard) throws(LoadError) -> LoadedLesson {
        var definitions: [VariableDefinition] = []
        for declaration in lesson.variables {
            definitions.append(try definition(for: declaration, functions: functions))
        }
        let store = VariableStore()
        try store.load(definitions)
        return LoadedLesson(store: store, body: resolve(lesson.body, in: store))
    }

    private static func definition(for d: VariableDeclaration, functions: FunctionRegistry) throws(LoadError) -> VariableDefinition {
        switch (d.value, d.fn) {
        case (let value?, nil):
            return VariableDefinition(name: d.name, colour: d.colour, source: .literal(value))
        case (nil, let fn?):
            guard let compute = functions[fn] else { throw LoadError.unknownFunction(fn, usedBy: d.name) }
            return VariableDefinition(name: d.name, colour: d.colour, source: .computed(inputs: d.inputs ?? [], compute: compute))
        default:
            throw LoadError.needsValueOrFunction(d.name)
        }
    }

    static func resolve(_ node: Node, in store: VariableStore) -> ResolvedNode {
        switch node {
        case .vstack(let children):
            return .vstack(children.map { resolve($0, in: store) })
        case .text(let text):
            return .text(text)
        case .slider(let name, let min, let max, let step):
            guard let variable = store[name] else { return .error("Slider: no variable named \(name).") }
            guard case .number = variable.value else { return .error("Slider: \(name) isn't a number.") }
            // ClosedRange traps when min > max.
            guard min <= max else { return .error("Slider: min is greater than max.") }
            return .slider(variable, range: min...max, step: step)
        case .unknown(let type):
            return .error("Unknown component type \"\(type)\".")
        }
    }
}
