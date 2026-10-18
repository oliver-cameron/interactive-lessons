import LessonModel

// Node with variable names replaced by references. Same shape; built once at load.
public indirect enum ResolvedNode {
    case vstack([ResolvedNode])
    case text([TextSegment])
    case slider(Variable, range: ClosedRange<Double>, step: Double?)
    case diagram(ResolvedDiagram)
    // A component that couldn't be resolved, shown in place as a visible error.
    case error(String)
}
