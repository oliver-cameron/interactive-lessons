import Foundation
import Testing
@testable import LessonModel

struct LessonDecodingTests {
    @Test func decodesBareLiteralValues() throws {
        let json = #"[440, "A4", true, [1, 2], {"x": 1}]"#
        let values = try JSONDecoder().decode([Value].self, from: Data(json.utf8))
        #expect(values == [.number(440), .string("A4"), .bool(true),
                           .list([.number(1), .number(2)]), .record(["x": .number(1)])])
    }

    @Test func unknownComponentTypeDecodesInsteadOfThrowing() throws {
        let json = #"{"type": "wobble", "amount": 3}"#
        let node = try JSONDecoder().decode(Node.self, from: Data(json.utf8))
        #expect(node == .unknown(type: "wobble"))
    }

    @Test func lessonRoundTrips() throws {
        let lesson = Lesson(
            variables: [VariableDeclaration(name: "freq", value: .number(440))],
            body: .vstack([.text("Hi"), .slider(variable: "freq", min: 20, max: 2000, step: 1)])
        )
        let data = try JSONEncoder().encode(lesson)
        #expect(try JSONDecoder().decode(Lesson.self, from: data) == lesson)
    }
}
