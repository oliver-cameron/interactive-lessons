import Foundation
import SwiftUI
import LessonModel
import LessonEngine
import LessonScript
import LessonUI

// Loads a lesson bundled with the app and shows it, or shows why it didn't load.
struct LessonScreen: View {
    @State private var result: Result<LoadedLesson, any Error>

    init(resource: String) {
        _result = State(initialValue: Result { try Self.load(resource) })
    }

    var body: some View {
        switch result {
        case .success(let lesson):
            LessonView(lesson)
        case .failure(let error):
            Text(verbatim: String(describing: error))
                .foregroundStyle(.red)
                .padding()
        }
    }

    private static func load(_ resource: String) throws -> LoadedLesson {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let lesson = try JSONDecoder().decode(Lesson.self, from: Data(contentsOf: url))
        var functions = FunctionRegistry.standard
        try functions.addJavaScript(lesson.functions ?? [:])
        return try Resolver.load(lesson, functions: functions)
    }
}
