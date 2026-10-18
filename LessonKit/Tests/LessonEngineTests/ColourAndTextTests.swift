import Testing
import LessonModel
@testable import LessonEngine

@MainActor
struct ColourAndTextTests {
    @Test func variablesWithoutColourTakePaletteColoursInTurn() throws {
        let loaded = try Resolver.load(Lesson(
            variables: [
                VariableDeclaration(name: "a", value: .number(1)),
                VariableDeclaration(name: "b", value: .number(2), colour: "green"),
                VariableDeclaration(name: "c", value: .number(3)),
            ],
            body: .vstack([])
        ))
        #expect(loaded.store.variables.map(\.colour) == [.red, .green, .blue])
    }

    @Test func unknownColourFailsLoad() {
        #expect(throws: LoadError.unknownColour("teal", usedBy: "a")) {
            try Resolver.load(Lesson(variables: [VariableDeclaration(name: "a", value: .number(1), colour: "teal")],
                                     body: .vstack([])))
        }
    }

    @Test func textInterpolatesLiveValues() throws {
        let loaded = try Resolver.load(Lesson(
            variables: [VariableDeclaration(name: "f", value: .number(440))],
            body: .text("\\var{f} Hz, period \\var{f}")
        ))
        guard case .text(let segments) = loaded.body else { Issue.record("not text"); return }
        #expect(TextSegment.render(segments) == "440 Hz, period 440")
        loaded.store["f"]!.write(.number(0.5))
        #expect(TextSegment.render(segments) == "0.5 Hz, period 0.5")
    }

    @Test func textWithUnknownVariableIsAnErrorNode() throws {
        let loaded = try Resolver.load(Lesson(variables: [], body: .text("x is \\var{x}")))
        guard case .error(let message) = loaded.body else { Issue.record("not an error"); return }
        #expect(message.contains("x"))
    }

    @Test func throwingFunctionSetsErrorAndKeepsLastGoodValue() throws {
        let functions = FunctionRegistry([
            "positiveRoot": { inputs in
                guard case .number(let x) = inputs[0], x >= 0 else { throw ComputeError("needs x ≥ 0") }
                return .number(x.squareRoot())
            },
        ])
        let loaded = try Resolver.load(Lesson(
            variables: [
                VariableDeclaration(name: "x", value: .number(4)),
                VariableDeclaration(name: "r", fn: "positiveRoot", inputs: ["x"]),
            ],
            body: .vstack([])
        ), functions: functions)
        let x = loaded.store["x"]!, r = loaded.store["r"]!
        x.write(.number(-1))
        #expect(r.value == .number(2))
        #expect(r.error == "needs x ≥ 0")
        x.write(.number(9))
        #expect(r.value == .number(3))
        #expect(r.error == nil)
    }

    @Test(arguments: [(440.0, "440"), (0.5, "0.5"), (1.0 / 440, "0.002273"), (1234.56, "1234.6"), (-2, "-2"), (.nan, "undefined")])
    func numbersDisplayCompactly(value: Double, expected: String) {
        #expect(Value.number(value).displayString == expected)
    }
}
