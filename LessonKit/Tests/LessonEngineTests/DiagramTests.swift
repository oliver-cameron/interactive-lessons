import Foundation
import Testing
import LessonModel
@testable import LessonEngine

@MainActor
struct DiagramTests {
    private func load(_ elements: [DiagramElement], functions: FunctionRegistry = .standard) throws -> (LoadedLesson, ResolvedDiagram) {
        let loaded = try Resolver.load(Lesson(
            variables: [
                VariableDeclaration(name: "px", value: .number(2), colour: "purple"),
                VariableDeclaration(name: "py", value: .number(1)),
            ],
            body: .diagram(Diagram(x: [-5, 5], y: [-5, 5], elements: elements))
        ), functions: functions)
        guard case .diagram(let d) = loaded.body else {
            Issue.record("Expected a diagram, got \(loaded.body)")
            throw CancellationError()
        }
        return (loaded, d)
    }

    @Test func decodesFromJSON() throws {
        let json = #"{"type": "diagram", "x": [-1, 1], "y": [-1, 1], "elements": [{"type": "point", "at": [0, "py"], "drag": true}]}"#
        let node = try JSONDecoder().decode(Node.self, from: Data(json.utf8))
        #expect(node == .diagram(Diagram(x: [-1, 1], y: [-1, 1], elements: [.point(at: Point(.constant(0), .variable("py")), colour: nil, drag: true)])))
    }

    @Test func draggablePointGivesHandleAndTakesItsVariablesColour() throws {
        let (_, d) = try load([.point(at: Point(.variable("px"), .variable("py")), colour: nil, drag: true)])
        let list = DiagramCompiler.compile(d, samples: 10)
        #expect(list.primitives == [.dot(Vec2(2, 1), ink: .palette(.purple), radius: 6)])
        #expect(list.handles.count == 1)
        #expect(list.handles[0].x?.name == "px")
    }

    @Test func compiledListFollowsVariableWrites() throws {
        let (loaded, d) = try load([.vector(from: nil, to: Point(.variable("px"), .variable("py")), colour: nil)])
        loaded.store.write([(loaded.store["px"]!, .number(-3)), (loaded.store["py"]!, .number(4))])
        #expect(DiagramCompiler.compile(d, samples: 10).primitives ==
                [.polyline([Vec2(0, 0), Vec2(-3, 4)], ink: .palette(.purple), width: 2, arrowAtEnd: true)])
    }

    @Test func plotBreaksAtAsymptotes() throws {
        let functions = FunctionRegistry(["tan": { inputs in .number(tan(Double(storage: inputs[0])!)) }])
        let (_, d) = try load([.plot(fn: "tan", inputs: [], colour: "blue")], functions: functions)
        let lines = DiagramCompiler.compile(d, samples: 400).primitives
        // tan has asymptotes at ±π/2 and ±3π/2 inside [-5, 5], so the curve splits into five pieces.
        #expect(lines.count == 5)
    }

    @Test func plotErrorShowsAsTextInsteadOfCurve() throws {
        let functions = FunctionRegistry(["bad": { _ in throw ComputeError("no") }])
        let (_, d) = try load([.plot(fn: "bad", inputs: [], colour: nil)], functions: functions)
        guard case .text(let message, _, _, .error) = DiagramCompiler.compile(d, samples: 10).primitives.first else {
            Issue.record("Expected an error label"); return
        }
        #expect(message == "bad: no")
    }

    @Test func unknownElementMakesTheDiagramAnErrorNode() throws {
        let loaded = try Resolver.load(Lesson(
            variables: [],
            body: .diagram(Diagram(x: [-1, 1], y: [-1, 1], elements: [.unknown(type: "spiral")]))
        ))
        guard case .error(let message) = loaded.body else { Issue.record("not an error"); return }
        #expect(message.contains("spiral"))
    }

    @Test func ticksUseRoundSteps() {
        #expect(DiagramCompiler.ticks(-5...5) == [-4, -2, 0, 2, 4].map(Double.init))
        let unit = DiagramCompiler.ticks(0...1)
        #expect(unit.count == 6)
        #expect(zip(unit, [0, 0.2, 0.4, 0.6, 0.8, 1]).allSatisfy { abs($0 - $1) < 1e-12 })
    }

    @Test func viewportRoundTrips() {
        let v = Viewport(bounds: Bounds(x: -5...5, y: -2...2), width: 400, height: 200)
        #expect(v.toScreen(Vec2(-5, 2)) == Vec2(0, 0))
        #expect(v.toScreen(Vec2(0, 0)) == Vec2(200, 100))
        let p = v.toMaths(v.toScreen(Vec2(1.5, -0.5)))
        #expect(abs(p.x - 1.5) < 1e-9 && abs(p.y + 0.5) < 1e-9)
    }
}
