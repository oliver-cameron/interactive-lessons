import SwiftUI
import LessonEngine

// The one place a resolved node becomes a view. The switch is exhaustive, so a new
// ResolvedNode case doesn't compile until it has a view here.
public struct NodeView: View {
    let node: ResolvedNode

    public init(_ node: ResolvedNode) {
        self.node = node
    }

    public var body: some View {
        switch node {
        case .vstack(let children):
            VStack(alignment: .leading, spacing: 12) {
                ForEach(children.indices, id: \.self) { NodeView(children[$0]) }
            }
        case .text(let segments):
            TextNode(segments: segments)
        case .slider(let variable, let range, let step):
            SliderNode(variable: variable, range: range, step: step)
        case .diagram(let diagram):
            DiagramView(diagram: diagram)
        case .error(let message):
            ErrorNode(message: message)
        }
    }
}
