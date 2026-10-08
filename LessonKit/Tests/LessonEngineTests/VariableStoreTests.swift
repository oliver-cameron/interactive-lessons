import Testing
@testable import LessonModel
@testable import LessonEngine

@MainActor
struct VariableStoreTests {
    private func number(_ v: Value) -> Double? { Double(storage: v) }

    @Test func writePropagatesToComputedVariables() throws {
        let loaded = try Resolver.load(Lesson(
            variables: [
                VariableDeclaration(name: "freq", value: .number(4)),
                VariableDeclaration(name: "period", fn: "reciprocal", inputs: ["freq"]),
            ],
            body: .vstack([])
        ))
        let freq = try #require(loaded.store["freq"])
        let period = try #require(loaded.store["period"])
        #expect(number(period.value) == 0.25)

        freq.write(.number(2))
        #expect(number(period.value) == 0.5)
    }

    // a → b, a → c, b + c → d. Topological order computes d once, with both inputs fresh.
    @Test func diamondComputesEachVariableOnceWithFreshInputs() throws {
        let recorder = Recorder()
        let functions = FunctionRegistry([
            "double": { inputs in .number(Double(storage: inputs[0])! * 2) },
            "triple": { inputs in .number(Double(storage: inputs[0])! * 3) },
            // The store calls functions on the main actor, so the recorder can be touched here.
            "recordingSum": { inputs in
                MainActor.assumeIsolated { recorder.calls.append(inputs) }
                return .number(inputs.compactMap { Double(storage: $0) }.reduce(0, +))
            },
        ])
        let loaded = try Resolver.load(Lesson(
            variables: [
                VariableDeclaration(name: "d", fn: "recordingSum", inputs: ["b", "c"]),
                VariableDeclaration(name: "b", fn: "double", inputs: ["a"]),
                VariableDeclaration(name: "c", fn: "triple", inputs: ["a"]),
                VariableDeclaration(name: "a", value: .number(1)),
            ],
            body: .vstack([])
        ), functions: functions)
        recorder.calls.removeAll()

        loaded.store["a"]!.write(.number(10))
        #expect(recorder.calls == [[.number(20), .number(30)]])
        #expect(number(loaded.store["d"]!.value) == 50)
    }

    @Test func cycleIsReportedWithItsVariables() {
        #expect(throws: LoadError.cycle(["x", "y"])) {
            try Resolver.load(Lesson(
                variables: [
                    VariableDeclaration(name: "x", fn: "reciprocal", inputs: ["y"]),
                    VariableDeclaration(name: "y", fn: "reciprocal", inputs: ["x"]),
                ],
                body: .vstack([])
            ))
        }
    }

    @Test func misspeltVariableInTreeBecomesAnErrorNode() throws {
        let loaded = try Resolver.load(Lesson(
            variables: [VariableDeclaration(name: "freq", value: .number(440))],
            body: .slider(variable: "fequency", min: 0, max: 1, step: nil)
        ))
        guard case .error = loaded.body else {
            Issue.record("Expected an error node, got \(loaded.body)")
            return
        }
    }
}

@MainActor
private final class Recorder {
    var calls: [[Value]] = []
}
