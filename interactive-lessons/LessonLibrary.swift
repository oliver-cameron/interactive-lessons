import SwiftUI

// Every lesson file bundled with the app, by file name.
struct LessonLibrary: View {
    private let names = (Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
        .map { $0.deletingPathExtension().lastPathComponent }
        .sorted()

    var body: some View {
        NavigationStack {
            List(names, id: \.self) { name in
                NavigationLink(name) {
                    LessonScreen(resource: name)
                        .navigationTitle(name)
                }
            }
            .navigationTitle("Lessons")
        }
    }
}
