import Observation
import LessonModel

// A declaration with its function looked up, ready for the store.
struct VariableDefinition {
    enum Source {
        case literal(Value)
        case computed(inputs: [String], compute: FunctionRegistry.Function)
    }
    var name: String
    var colour: PaletteColor
    var source: Source

    var inputNames: [String] {
        if case .computed(let inputs, _) = source { inputs } else { [] }
    }
}

@MainActor @Observable
public final class VariableStore {
    // Declaration order: what the variable panel shows, and what the editor edits.
    public private(set) var variables: [Variable] = []

    @ObservationIgnored private var byName: [String: Variable] = [:]
    // Every variable appears after all of its inputs.
    @ObservationIgnored private var topologicalOrder: [Variable] = []

    public init() {}

    public subscript(name: String) -> Variable? { byName[name] }

    func load(_ definitions: [VariableDefinition]) throws(LoadError) {
        let sorted = try Self.topologicallySorted(definitions)

        // Creating in topological order means every input already exists.
        var created: [String: Variable] = [:]
        for definition in sorted {
            let variable: Variable
            switch definition.source {
            case .literal(let value):
                variable = Variable(name: definition.name, value: value, colour: definition.colour, kind: .input)
            case .computed(let inputNames, let compute):
                let inputs = inputNames.map { created[$0]! }
                variable = Variable(name: definition.name, value: .number(.nan),
                                    colour: definition.colour, kind: .computed(inputs: inputs, compute: compute))
                variable.recompute()
            }
            variable.store = self
            created[definition.name] = variable
        }

        byName = created
        topologicalOrder = sorted.map { created[$0.name]! }
        variables = definitions.map { created[$0.name]! }
    }

    public func write(_ value: Value, to variable: Variable) {
        write([(variable, value)])
    }

    // Several writes propagate once, so nothing downstream sees a half-applied change.
    public func write(_ changes: [(Variable, Value)]) {
        var changed = Set<ObjectIdentifier>()
        for (variable, newValue) in changes {
            // Writes to computed variables will route to a driven input; ignored for now.
            guard case .input = variable.kind, variable.value != newValue else { continue }
            variable.value = newValue
            changed.insert(ObjectIdentifier(variable))
        }
        guard !changed.isEmpty else { return }

        for variable in topologicalOrder {
            guard case .computed(let inputs, let compute) = variable.kind,
                  inputs.contains(where: { changed.contains(ObjectIdentifier($0)) }) else { continue }
            if variable.recompute(compute, inputs) {
                changed.insert(ObjectIdentifier(variable))
            }
        }
    }

    // Kahn's algorithm: repeatedly take a variable whose inputs are all placed.
    private static func topologicallySorted(_ definitions: [VariableDefinition]) throws(LoadError) -> [VariableDefinition] {
        var byName: [String: VariableDefinition] = [:]
        for definition in definitions {
            guard byName[definition.name] == nil else { throw LoadError.duplicateName(definition.name) }
            byName[definition.name] = definition
        }

        var remainingInputs: [String: Int] = [:]
        var dependents: [String: [String]] = [:]
        for definition in definitions {
            remainingInputs[definition.name] = definition.inputNames.count
            for input in definition.inputNames {
                guard byName[input] != nil else { throw LoadError.unknownInput(input, usedBy: definition.name) }
                dependents[input, default: []].append(definition.name)
            }
        }

        var ready = definitions.filter { remainingInputs[$0.name] == 0 }
        var next = 0
        while next < ready.count {
            let current = ready[next]
            next += 1
            for dependent in dependents[current.name] ?? [] {
                remainingInputs[dependent]! -= 1
                if remainingInputs[dependent] == 0 { ready.append(byName[dependent]!) }
            }
        }

        guard ready.count == definitions.count else {
            let placed = Set(ready.map(\.name))
            throw LoadError.cycle(definitions.map(\.name).filter { !placed.contains($0) })
        }
        return ready
    }
}

extension Variable {
    // Runs the function and stores the result, or the error and the last good value.
    // Returns whether the value changed (compare-before-write).
    @discardableResult
    func recompute() -> Bool {
        guard case .computed(let inputs, let compute) = kind else { return false }
        return recompute(compute, inputs)
    }

    func recompute(_ compute: FunctionRegistry.Function, _ inputs: [Variable]) -> Bool {
        let newValue: Value
        do {
            newValue = try compute(inputs.map(\.value))
        } catch {
            let message = String(describing: error)
            if self.error != message { self.error = message }
            return false
        }
        if self.error != nil { self.error = nil }
        guard newValue != value else { return false }
        value = newValue
        return true
    }
}
