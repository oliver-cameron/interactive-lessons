import SwiftUI
import LessonModel
import LessonEngine

// Measures the space, then hands the size to the view that compiles and draws.
struct DiagramView: View {
    let diagram: ResolvedDiagram

    var body: some View {
        GeometryReader { geometry in
            DiagramCanvas(diagram: diagram, size: geometry.size)
        }
        .frame(height: diagram.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }
}

private struct DiagramCanvas: View {
    let diagram: ResolvedDiagram
    let size: CGSize

    @Environment(VariableStore.self) private var store
    @State private var dragged: DragHandle?

    // Grab radius for drag handles, in screen points.
    private let grabRadius = 24.0

    var body: some View {
        let viewport = Viewport(bounds: diagram.bounds, width: size.width, height: size.height)
        // Compiled in body, not in the Canvas closure, so observation sees which variables
        // the diagram reads and redraws it when any of them changes.
        let list = DiagramCompiler.compile(diagram, samples: max(Int(size.width / 2), 2))

        Canvas { context, _ in
            for primitive in list.primitives {
                Self.draw(primitive, in: &context, viewport)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    if dragged == nil { dragged = nearestHandle(to: drag.startLocation, list, viewport) }
                    guard let handle = dragged else { return }
                    let p = viewport.toMaths(Vec2(drag.location.x, drag.location.y))
                    var changes: [(Variable, Value)] = []
                    if let x = handle.x { changes.append((x, .number(p.x))) }
                    if let y = handle.y { changes.append((y, .number(p.y))) }
                    store.write(changes)
                }
                .onEnded { _ in dragged = nil }
        )
    }

    private func nearestHandle(to location: CGPoint, _ list: DisplayList, _ viewport: Viewport) -> DragHandle? {
        list.handles
            .map { handle -> (DragHandle, Double) in
                let s = viewport.toScreen(handle.position)
                return (handle, hypot(s.x - location.x, s.y - location.y))
            }
            .filter { $0.1 <= grabRadius }
            .min { $0.1 < $1.1 }?.0
    }

    private static func draw(_ primitive: Primitive, in context: inout GraphicsContext, _ viewport: Viewport) {
        func cg(_ p: Vec2) -> CGPoint {
            let s = viewport.toScreen(p)
            return CGPoint(x: s.x, y: s.y)
        }

        switch primitive {
        case .polyline(let points, let ink, let width, let arrowAtEnd):
            guard let first = points.first else { return }
            var path = Path()
            path.move(to: cg(first))
            for p in points.dropFirst() { path.addLine(to: cg(p)) }
            context.stroke(path, with: .color(ink.color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            if arrowAtEnd, points.count >= 2 {
                context.fill(arrowhead(from: cg(points[points.count - 2]), to: cg(points[points.count - 1])), with: .color(ink.color))
            }
        case .dot(let at, let ink, let radius):
            let c = cg(at)
            context.fill(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: 2 * radius, height: 2 * radius)),
                         with: .color(ink.color))
        case .text(let string, let at, let anchor, let ink):
            let (offset, unitPoint) = placement(anchor)
            let c = cg(at)
            context.draw(Text(verbatim: string).font(.caption).foregroundStyle(ink.color),
                         at: CGPoint(x: c.x + offset.width, y: c.y + offset.height), anchor: unitPoint)
        }
    }

    // A filled triangle 10 points long at the tip, in screen space, so it doesn't scale with zoom.
    private static func arrowhead(from: CGPoint, to tip: CGPoint) -> Path {
        let length = 10.0, halfWidth = 4.5
        let dx = tip.x - from.x, dy = tip.y - from.y
        let d = hypot(dx, dy)
        guard d > 0 else { return Path() }
        let (ux, uy) = (dx / d, dy / d)
        let base = CGPoint(x: tip.x - ux * length, y: tip.y - uy * length)
        var path = Path()
        path.move(to: tip)
        path.addLine(to: CGPoint(x: base.x - uy * halfWidth, y: base.y + ux * halfWidth))
        path.addLine(to: CGPoint(x: base.x + uy * halfWidth, y: base.y - ux * halfWidth))
        path.closeSubpath()
        return path
    }

    // Where a label sits relative to its point: an offset of 6 points and the matching anchor.
    private static func placement(_ anchor: LabelAnchor) -> (CGSize, UnitPoint) {
        let g = 6.0
        switch anchor {
        case .center: return (.zero, .center)
        case .above: return (CGSize(width: 0, height: -g), .bottom)
        case .below: return (CGSize(width: 0, height: g), .top)
        case .left: return (CGSize(width: -g, height: 0), .trailing)
        case .right: return (CGSize(width: g, height: 0), .leading)
        case .aboveLeft: return (CGSize(width: -g, height: -g), .bottomTrailing)
        case .aboveRight: return (CGSize(width: g, height: -g), .bottomLeading)
        case .belowLeft: return (CGSize(width: -g, height: g), .topTrailing)
        case .belowRight: return (CGSize(width: g, height: g), .topLeading)
        }
    }
}
