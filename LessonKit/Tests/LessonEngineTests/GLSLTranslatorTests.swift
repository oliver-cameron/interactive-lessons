import Testing
@testable import LessonEngine

struct GLSLTranslatorTests {
    @Test func rewritesQualifiersAndStripsDeclarations() {
        let glsl = """
        #version 300 es
        precision highp float;
        uniform vec2 r1;
        void f(out vec3 c, inout float t, in vec2 p) { c = vec3(p, t); }
        """
        let out = GLSLTranslator.rewrite(glsl)
        #expect(out == "\n\n\nvoid f(thread vec3& c, thread float& t, vec2 p) { c = vec3(p, t); }")
    }

    @Test func linesArePreservedSoErrorsPointAtTheAuthorsLines() {
        let glsl = "uniform float a;\nuniform float b;\nvec4 shade(vec2 p) { return vec4(a); }"
        #expect(GLSLTranslator.rewrite(glsl).split(separator: "\n", omittingEmptySubsequences: false).count == 3)
    }

    @Test func uniformsBecomeMembersLoadedFromTheBufferInOrder() throws {
        let metal = try GLSLTranslator.metalSource(
            glsl: "vec4 shade(vec2 p) { return vec4(c, k); }",
            uniforms: [.init(name: "c", components: 3), .init(name: "k", components: 1), .init(name: "r", components: 2)])
        #expect(metal.contains("    vec3 c;\n    float k;\n    vec2 r;"))
        #expect(metal.contains("s.c = vec3(U[6], U[7], U[8]);"))
        #expect(metal.contains("s.k = U[9];"))
        #expect(metal.contains("s.r = vec2(U[10], U[11]);"))
        #expect(metal.contains("return s.shade(p);"))
        #expect(metal.contains("#line 1\nvec4 shade(vec2 p)"))
    }

    @Test func shadertoyEntryIsSupported() throws {
        let metal = try GLSLTranslator.metalSource(
            glsl: "void mainImage(out vec4 fragColor, in vec2 fragCoord) { fragColor = vec4(1.0); }", uniforms: [])
        #expect(metal.contains("void mainImage(thread vec4& fragColor, vec2 fragCoord)"))
        #expect(metal.contains("s.mainImage(colour, float2(in.position.x, U[5] - in.position.y));"))
    }

    @Test func missingEntryPointIsAProblem() {
        #expect(throws: GLSLTranslator.Problem.self) {
            try GLSLTranslator.metalSource(glsl: "float f() { return 1.0; }", uniforms: [])
        }
    }

    @Test func reservedUniformNameIsAProblem() {
        #expect(throws: GLSLTranslator.Problem.self) {
            try GLSLTranslator.metalSource(glsl: "vec4 shade(vec2 p) { return vec4(1.0); }",
                                           uniforms: [.init(name: "pixel", components: 1)])
        }
    }
}
