import SwiftUI

// Plain text for now. Markdown, $…$ maths and \var{name} interpolation come next.
struct TextNode: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
    }
}
