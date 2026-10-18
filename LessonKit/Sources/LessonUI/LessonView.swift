import SwiftUI
import LessonEngine

public struct LessonView: View {
    let lesson: LoadedLesson

    public init(_ lesson: LoadedLesson) {
        self.lesson = lesson
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NodeView(lesson.body)
                Divider()
                VariablePanel(store: lesson.store)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .environment(lesson.store)
    }
}
