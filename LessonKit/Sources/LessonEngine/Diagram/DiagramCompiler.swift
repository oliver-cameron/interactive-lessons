import Foundation
import LessonModel

// What the renderer draws. Positions are in maths coordinates; the renderer applies the
// viewport. Sizes (dot radius, arrowhead, label offset) are in screen points.
public enum Ink: Equatable, Sendable {
    case palette(PaletteColor)
    case axis
    case error
}

public enum Primitive: Equatable, Sendable {
    case polyline([Vec2], ink: Ink, width: Double, arrowAtEnd: Bool)
    case dot(Vec2, ink: Ink, radius: Double)
    case text(String, at: Vec2, anchor: LabelAnchor, ink: Ink)
}

// A draggable point. Dragging writes whichever coordinates are variables.
public struct DragHandle {
    public let position: Vec2
    public let x: Variable?
    public let y: Variable?
}

public struct DisplayList {
    public var primitives: [Primitive] = []
    public var handles: [DragHandle] = []
}

@MainActor
public enum DiagramCompiler {
    // `samples` is how many x values a plot evaluates; the renderer ties it to pixel width.
    public static func compile(_ diagram: ResolvedDiagram, samples: Int) -> DisplayList {
        var list = DisplayList()
        for element in diagram.elements {
            switch element {
            case .axes:
                list.primitives += axes(diagram.bounds)
            case .point(let p, let colour, let drag):
                let at = p.current
                list.primitives.append(.dot(at, ink: .palette(colour), radius: drag ? 6 : 4))
                if drag, p.x.variable != nil || p.y.variable != nil {
                    list.handles.append(DragHandle(position: at, x: p.x.variable, y: p.y.variable))
                }
            case .segment(let from, let to, let colour):
                list.primitives.append(.polyline([from.current, to.current], ink: .palette(colour), width: 2, arrowAtEnd: false))
            case .vector(let from, let to, let colour):
                list.primitives.append(.polyline([from.current, to.current], ink: .palette(colour), width: 2, arrowAtEnd: true))
            case .label(let at, let text, let anchor, let colour):
                list.primitives.append(.text(TextSegment.render(text), at: at.current, anchor: anchor, ink: .palette(colour)))
            case .plot(let name, let fn, let inputs, let colour):
                list.primitives += plot(name, fn, inputs, colour, diagram.bounds, samples: samples)
            }
        }
        return list
    }

    static func axes(_ b: Bounds) -> [Primitive] {
        var out: [Primitive] = []
        if b.y.contains(0) {
            out.append(.polyline([Vec2(b.x.lowerBound, 0), Vec2(b.x.upperBound, 0)], ink: .axis, width: 1, arrowAtEnd: false))
            for x in ticks(b.x) where x != 0 {
                out.append(.dot(Vec2(x, 0), ink: .axis, radius: 1.5))
                out.append(.text(Value.format(x), at: Vec2(x, 0), anchor: .below, ink: .axis))
            }
        }
        if b.x.contains(0) {
            out.append(.polyline([Vec2(0, b.y.lowerBound), Vec2(0, b.y.upperBound)], ink: .axis, width: 1, arrowAtEnd: false))
            for y in ticks(b.y) where y != 0 {
                out.append(.dot(Vec2(0, y), ink: .axis, radius: 1.5))
                out.append(.text(Value.format(y), at: Vec2(0, y), anchor: .left, ink: .axis))
            }
        }
        return out
    }

    // Round tick spacing (1, 2 or 5 times a power of ten) giving about eight ticks.
    static func ticks(_ range: ClosedRange<Double>) -> [Double] {
        let rough = (range.upperBound - range.lowerBound) / 8
        guard rough > 0, rough.isFinite else { return [] }
        let power = pow(10, floor(log10(rough)))
        let step = [1.0, 2, 5, 10].map { $0 * power }.first { $0 >= rough }!
        let first = (range.lowerBound / step).rounded(.up)
        let last = (range.upperBound / step).rounded(.down)
        guard first <= last else { return [] }
        return stride(from: first, through: last, by: 1).map { $0 * step }
    }

    static func plot(_ name: String, _ fn: FunctionRegistry.Function, _ inputs: [Variable], _ colour: PaletteColor,
                     _ b: Bounds, samples: Int) -> [Primitive] {
        let args = inputs.map(\.value)
        let n = max(samples, 2)
        let span = b.y.upperBound - b.y.lowerBound
        var runs: [[Vec2]] = [[]]
        for i in 0..<n {
            let x = b.x.lowerBound + Double(i) / Double(n - 1) * (b.x.upperBound - b.x.lowerBound)
            let y: Double
            do {
                y = Double(storage: try fn([.number(x)] + args)) ?? .nan
            } catch {
                let corner = Vec2(b.x.lowerBound, b.y.upperBound)
                return [.text("\(name): \(error)", at: corner, anchor: .belowRight, ink: .error)]
            }
            let point = Vec2(x, y)
            // Break the curve at undefined values, and at jumps of more than twice the window
            // height between neighbouring samples, which is how tan x's asymptotes show up.
            if !point.isFinite || (runs[runs.count - 1].last.map { abs($0.y - y) > 2 * span } ?? false) {
                if !runs[runs.count - 1].isEmpty { runs.append([]) }
                if !point.isFinite { continue }
            }
            runs[runs.count - 1].append(point)
        }
        return runs.filter { $0.count > 1 }.map { .polyline($0, ink: .palette(colour), width: 2, arrowAtEnd: false) }
    }
}
