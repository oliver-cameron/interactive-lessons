import SwiftUI
import LessonEngine

// Every variable in declaration order with its colour and current value, as in Desmos.
// A variable whose function failed shows the error under it.
public struct VariablePanel: View {
    let store: VariableStore

    public init(store: VariableStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(store.variables) { variable in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(variable.colour.color)
                            .frame(width: 10, height: 10)
                        Text(verbatim: "\(variable.name) = \(variable.value.displayString)")
                            .monospacedDigit()
                    }
                    if let error = variable.error {
                        Text(verbatim: error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .font(.callout)
    }
}
