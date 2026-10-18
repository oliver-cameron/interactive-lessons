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
        // Variables without a colour take the next palette colour, as in Desmos.
        var nextColour = PaletteColor.allCases.makeIterator()
        for declaration in lesson.variables {
            let colour: PaletteColor
            if let name = declaration.colour {
                guard let c = PaletteColor(rawValue: name) else { throw LoadError.unknownColour(name, usedBy: declaration.name) }
                colour = c
            } else {
                if let c = nextColour.next() { colour = c }
                else { nextColour = PaletteColor.allCases.makeIterator(); colour = nextColour.next()! }
            }
            definitions.append(try definition(for: declaration, colour: colour, functions: functions))
        }
        let store = VariableStore()
        try store.load(definitions)
        let context = Context(store: store, functions: functions)
        return LoadedLesson(store: store, body: context.resolve(lesson.body))
    }

    private static func definition(for d: VariableDeclaration, colour: PaletteColor,
                                   functions: FunctionRegistry) throws(LoadError) -> VariableDefinition {
        switch (d.value, d.fn) {
        case (let value?, nil):
            return VariableDefinition(name: d.name, colour: colour, source: .literal(value))
        case (nil, let fn?):
            guard let compute = functions[fn] else { throw LoadError.unknownFunction(fn, usedBy: d.name) }
            return VariableDefinition(name: d.name, colour: colour, source: .computed(inputs: d.inputs ?? [], compute: compute))
        default:
            throw LoadError.needsValueOrFunction(d.name)
        }
    }

    // Errors inside the tree are messages, not throws: they become error nodes in place.
    @MainActor
    struct Context {
        let store: VariableStore
        let functions: FunctionRegistry

        func resolve(_ node: Node) -> ResolvedNode {
            switch node {
            case .vstack(let children):
                return .vstack(children.map(resolve))
            case .text(let text):
                switch TextSegment.parse(text, in: store) {
                case .success(let segments): return .text(segments)
                case .failure(let unknown): return .error("Text: no variable named \(unknown.name).")
                }
            case .slider(let name, let min, let max, let step):
                guard let variable = store[name] else { return .error("Slider: no variable named \(name).") }
                guard case .number = variable.value else { return .error("Slider: \(name) isn't a number.") }
                // ClosedRange traps when min > max.
                guard min <= max else { return .error("Slider: min is greater than max.") }
                return .slider(variable, range: min...max, step: step)
            case .diagram(let diagram):
                switch resolve(diagram) {
                case .success(let resolved): return .diagram(resolved)
                case .failure(let problem): return .error("Diagram: \(problem.message)")
                }
            case .unknown(let type):
                return .error("Unknown component type \"\(type)\".")
            }
        }

        struct Problem: Error { let message: String }

        func resolve(_ d: Diagram) -> Result<ResolvedDiagram, Problem> {
            Result { () throws(Problem) -> ResolvedDiagram in
                guard d.x.count == 2, d.y.count == 2, d.x[0] < d.x[1], d.y[0] < d.y[1] else {
                    throw Problem(message: "x and y must each be [min, max] with min < max.")
                }
                let elements = try d.elements.map { (e) throws(Problem) in try resolve(e) }
                return ResolvedDiagram(bounds: Bounds(x: d.x[0]...d.x[1], y: d.y[0]...d.y[1]),
                                       height: d.height ?? 300, elements: elements)
            }
        }

        func resolve(_ e: DiagramElement) throws(Problem) -> ResolvedElement {
            switch e {
            case .axes:
                return .axes
            case .point(let at, let colour, let drag):
                let p = try resolve(at)
                return .point(p, colour: try colourFor(colour, [p.x.variable, p.y.variable]), drag: drag)
            case .segment(let from, let to, let colour):
                let (a, b) = (try resolve(from), try resolve(to))
                return .segment(from: a, to: b, colour: try colourFor(colour, variables(a) + variables(b)))
            case .vector(let from, let to, let colour):
                let a = try from.map { (p) throws(Problem) in try resolve(p) } ?? ResolvedPoint(x: .constant(0), y: .constant(0))
                let b = try resolve(to)
                // A vector takes its colour from its tip, the part that usually moves.
                return .vector(from: a, to: b, colour: try colourFor(colour, variables(b) + variables(a)))
            case .label(let at, let text, let anchor, let colour):
                let p = try resolve(at)
                let segments: [TextSegment]
                switch TextSegment.parse(text, in: store) {
                case .success(let s): segments = s
                case .failure(let unknown): throw Problem(message: "label uses \(unknown.name), which isn't declared.")
                }
                guard let a = LabelAnchor(rawValue: anchor ?? "aboveRight") else {
                    throw Problem(message: "label anchor \(anchor!) isn't one of \(LabelAnchor.allCases.map(\.rawValue).joined(separator: ", ")).")
                }
                let textVariables: [Variable?] = segments.map { if case .variable(let v) = $0 { v } else { nil } }
                return .label(at: p, text: segments, anchor: a, colour: try colourFor(colour, textVariables + variables(p)))
            case .plot(let name, let inputNames, let colour):
                guard let fn = functions[name] else { throw Problem(message: "plot uses the function \(name), which doesn't exist.") }
                var inputs: [Variable] = []
                for input in inputNames {
                    guard let v = store[input] else { throw Problem(message: "plot uses \(input), which isn't declared.") }
                    inputs.append(v)
                }
                return .plot(name: name, fn: fn, inputs: inputs, colour: try colourFor(colour, inputs))
            case .unknown(let type):
                throw Problem(message: "unknown element type \"\(type)\".")
            }
        }

        func resolve(_ p: Point) throws(Problem) -> ResolvedPoint {
            ResolvedPoint(x: try resolve(p.x), y: try resolve(p.y))
        }

        func resolve(_ s: Scalar) throws(Problem) -> ResolvedScalar {
            switch s {
            case .constant(let d): return .constant(d)
            case .variable(let name):
                guard let v = store[name] else { throw Problem(message: "no variable named \(name).") }
                return .variable(v)
            }
        }

        func variables(_ p: ResolvedPoint) -> [Variable?] { [p.x.variable, p.y.variable] }

        // An explicit colour wins; otherwise the first variable's colour; otherwise black.
        func colourFor(_ name: String?, _ candidates: [Variable?]) throws(Problem) -> PaletteColor {
            if let name {
                guard let c = PaletteColor(rawValue: name) else {
                    throw Problem(message: "colour \(name) isn't one of \(PaletteColorNames.list).")
                }
                return c
            }
            return candidates.lazy.compactMap { $0 }.first?.colour ?? .black
        }
    }
}
