import SwiftUI
import MetalKit
import LessonEngine

// Draws one translated GLSL shader across its frame, or its compile error.
struct ShaderView: View {
    let metal: String
    // Bounds (4 floats) then uniform values, colours already resolved to RGB.
    let floats: [Float]

    @State private var renderer = ShaderRenderer()

    var body: some View {
        MetalViewHost(renderer: renderer)
            .overlay(alignment: .topLeading) {
                if let error = renderer.error {
                    Text(verbatim: error)
                        .font(.caption.monospaced())
                        .foregroundStyle(.red)
                        .padding(8)
                        .background(.background.opacity(0.85))
                }
            }
            .onChange(of: metal, initial: true) { renderer.compile(metal) }
            .onChange(of: floats, initial: true) { renderer.floats = floats }
    }
}

// Compiles the shader once per source and redraws on demand, not every frame.
@MainActor @Observable
final class ShaderRenderer: NSObject, MTKViewDelegate {
    private(set) var error: String?

    @ObservationIgnored var floats: [Float] = [] { didSet { redraw() } }
    @ObservationIgnored weak var view: MTKView? { didSet { redraw() } }
    @ObservationIgnored let device: MTLDevice?
    @ObservationIgnored private let queue: MTLCommandQueue?
    @ObservationIgnored private var pipeline: MTLRenderPipelineState?
    @ObservationIgnored private var compiled: String?

    override init() {
        let device = MTLCreateSystemDefaultDevice()
        self.device = device
        queue = device?.makeCommandQueue()
        super.init()
    }

    func compile(_ source: String) {
        guard source != compiled else { return }
        compiled = source
        pipeline = nil
        guard let device else { error = "Metal isn't available on this device."; return }
        do {
            let library = try device.makeLibrary(source: source, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "lessonVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "lessonFragment")
            descriptor.colorAttachments[0].pixelFormat = view?.colorPixelFormat ?? .bgra8Unorm
            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            error = nil
        } catch {
            self.error = Self.authorErrors(error)
        }
        redraw()
    }

    // Metal reports "program_source:LINE:COL: error: …". #line 1 makes LINE the author's own
    // line, except for errors in the generated code, which are dropped as noise.
    private static func authorErrors(_ error: Error) -> String {
        let text = (error as NSError).localizedDescription
        let lines = text.split(separator: "\n").filter { $0.contains(": error:") }
        return lines.isEmpty ? text : lines.prefix(4).map {
            $0.replacingOccurrences(of: "program_source:", with: "line ")
        }.joined(separator: "\n")
    }

    private func redraw() {
        #if os(macOS)
        view?.needsDisplay = true
        #else
        view?.setNeedsDisplay()
        #endif
    }

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        MainActor.assumeIsolated { redraw() }
    }

    nonisolated func draw(in view: MTKView) {
        MainActor.assumeIsolated { render(in: view) }
    }

    private func render(in view: MTKView) {
        guard let pipeline, let queue, floats.count >= 4,
              let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let commands = queue.makeCommandBuffer(),
              let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return }
        // Layout the fragment function reads: bounds, drawable size in pixels, then uniforms.
        let size = view.drawableSize
        var buffer = Array(floats[0..<4]) + [Float(size.width), Float(size.height)] + floats[4...]
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&buffer, length: buffer.count * MemoryLayout<Float>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commands.present(drawable)
        commands.commit()
    }
}

#if os(macOS)
private typealias PlatformViewRepresentable = NSViewRepresentable
#else
private typealias PlatformViewRepresentable = UIViewRepresentable
#endif

private struct MetalViewHost: PlatformViewRepresentable {
    let renderer: ShaderRenderer

    private func makeView() -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.device)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        // Draw only when asked: on compile, resize and uniform changes.
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.delegate = renderer
        renderer.view = view
        return view
    }

    #if os(macOS)
    func makeNSView(context: Context) -> MTKView { makeView() }
    func updateNSView(_ view: MTKView, context: Context) {}
    #else
    func makeUIView(context: Context) -> MTKView { makeView() }
    func updateUIView(_ view: MTKView, context: Context) {}
    #endif
}
