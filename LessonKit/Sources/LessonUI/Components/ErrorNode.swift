import SwiftUI

// Lesson mistakes show up where they are, rather than crashing or vanishing.
struct ErrorNode: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
            .padding(8)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.red))
    }
}
