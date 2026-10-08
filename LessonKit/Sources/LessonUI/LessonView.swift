import SwiftUI
import LessonEngine

public struct LessonView: View {
    let lesson: LoadedLesson

    public init(_ lesson: LoadedLesson) {
        self.lesson = lesson
    }

    public var body: some View {
        ScrollView {
            NodeView(lesson.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .environment(lesson.store)
    }
}
