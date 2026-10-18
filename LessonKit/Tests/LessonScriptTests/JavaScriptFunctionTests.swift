#if canImport(JavaScriptCore)
import Testing
import LessonModel
import LessonEngine
@testable import LessonScript

@MainActor
struct JavaScriptFunctionTests {
    private func registry(_ sources: [String: String]) throws -> FunctionRegistry {
        var functions = FunctionRegistry.standard
        try functions.addJavaScript(sources)
        return functions
    }

    @Test func callsFunctionWithNumbers() throws {
        let f = try #require(try registry(["scale": "(a, x) => a * x"])["scale"])
        #expect(try f([.number(3), .number(4)]) == .number(12))
    }

    @Test func convertsListsRecordsAndBooleans() throws {
        let f = try #require(try registry(["wrap": "(xs) => ({ total: xs.reduce((a, b) => a + b, 0), big: xs.length > 2, xs })"])["wrap"])
        let result = try f([.list([.number(1), .number(2), .number(3)])])
        #expect(result == .record(["total": .number(6), "big": .bool(true),
                                   "xs": .list([.number(1), .number(2), .number(3)])]))
    }

    @Test func syntaxErrorFailsLoad() {
        #expect(throws: LoadError.self) { try registry(["broken": "(x) => x +"]) }
    }

    @Test func runtimeErrorBecomesVariableError() throws {
        let functions = try registry(["boom": "(x) => { throw new Error('too big') }"])
        let loaded = try Resolver.load(Lesson(
            variables: [
                VariableDeclaration(name: "x", value: .number(1)),
                VariableDeclaration(name: "y", fn: "boom", inputs: ["x"]),
            ],
            body: .vstack([])
        ), functions: functions)
        let error = try #require(loaded.store["y"]?.error)
        #expect(error.contains("too big"))
    }
}
#endif
