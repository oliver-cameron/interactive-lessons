import LessonModel

// Node with variable names replaced by references. Same shape; built once at load.
public indirect enum ResolvedNode {
    case vstack([ResolvedNode])
    case text(String)
    case slider(Variable, range: ClosedRange<Double>, step: Double?)
    // A component that couldn't be resolved, shown in place as a visible error.
    case error(String)
}
