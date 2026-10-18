import SwiftUI
import LessonEngine

// Live values from \var{name} show in the variable's colour. Markdown and $…$ maths come next.
struct TextNode: View {
    let segments: [TextSegment]

    var body: some View {
        Text(attributed)
    }

    // Reading each variable's value here is what re-renders the text when it changes.
    private var attributed: AttributedString {
        var result = AttributedString()
        for segment in segments {
            switch segment {
            case .literal(let s):
                result += AttributedString(s)
            case .variable(let v):
                var run = AttributedString(v.value.displayString)
                run.foregroundColor = v.colour.color
                run.font = .body.monospacedDigit().weight(.semibold)
                result += run
            }
        }
        return result
    }
}
