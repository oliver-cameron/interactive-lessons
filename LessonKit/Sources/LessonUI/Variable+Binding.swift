import SwiftUI
import LessonEngine

extension Variable {
    // A typed binding for controls: Slider needs Binding<Double>, not Binding<Value>.
    public func binding<T: Storable>(default fallback: T) -> Binding<T> {
        Binding(
            get: { T(storage: self.value) ?? fallback },
            set: { self.write($0.storage) }
        )
    }
}
