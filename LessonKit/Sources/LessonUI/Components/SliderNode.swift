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
            if let step {
                Slider(value: value, in: range, step: step)
            } else {
                Slider(value: value, in: range)
            }
            Text(value.wrappedValue, format: .number.precision(.fractionLength(0...3)))
                .monospacedDigit()
        }
    }
}
