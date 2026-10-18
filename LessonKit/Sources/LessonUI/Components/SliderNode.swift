import SwiftUI
import LessonEngine

struct SliderNode: View {
    let variable: Variable
    let range: ClosedRange<Double>
    let step: Double?

    var body: some View {
        let value = variable.binding(default: range.lowerBound)
        HStack {
            Text(verbatim: variable.name)
                .foregroundStyle(variable.colour.color)
            if let step {
                Slider(value: value, in: range, step: step)
            } else {
                Slider(value: value, in: range)
            }
            Text(verbatim: variable.value.displayString)
                .monospacedDigit()
        }
        .tint(variable.colour.color)
    }
}
