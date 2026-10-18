import Foundation

// Translates a GLSL fragment shader into Metal source, so lessons can carry shaders written
// in the language most people know and the app can compile them at load with Metal.
//
// It isn't a compiler: it relies on Metal being close to GLSL. A prelude maps GLSL's type
// names and the functions that differ, parameter qualifiers are rewritten, and the author's
// code is placed inside a struct whose members are the uniforms. Being a struct means helper
// functions can read uniforms and be declared in any order. Known gaps: function prototypes
// (a C++ struct can't redeclare a member), array constructors like vec3[](…), textures.
public enum GLSLTranslator {
    public struct Uniform: Equatable {
        public let name: String
        public let components: Int   // 1 for float, 2–4 for vec2–vec4

        public init(name: String, components: Int) {
            self.name = name
            self.components = components
        }
    }

    public struct Problem: Error, Equatable {
        public let message: String
    }

    // Members the translator provides; uniforms may not reuse these names.
    static let builtIns = ["bounds", "resolution", "pixel", "fragCoord", "iResolution"]

    public static func metalSource(glsl: String, uniforms: [Uniform]) throws(Problem) -> String {
        let entry: String
        if glsl.range(of: #"\bshade\s*\("#, options: .regularExpression) != nil {
            entry = "return s.shade(p);"
        } else if glsl.range(of: #"\bmainImage\s*\("#, options: .regularExpression) != nil {
            // Shadertoy puts the origin at the bottom left, in pixels.
            entry = "float4 colour = float4(0.0);\n    s.mainImage(colour, float2(in.position.x, U[5] - in.position.y));\n    return colour;"
        } else {
            throw Problem(message: "the GLSL needs a vec4 shade(vec2 p) function, or Shadertoy's mainImage.")
        }

        for u in uniforms {
            guard u.name.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil else {
                throw Problem(message: "uniform name \(u.name) isn't a valid identifier.")
            }
            guard !builtIns.contains(u.name) else {
                throw Problem(message: "uniform name \(u.name) is reserved (\(builtIns.joined(separator: ", ")) are provided).")
            }
        }

        let members = uniforms.map { "    \(type(of: $0)) \($0.name);" }.joined(separator: "\n")
        // Header floats: bounds (4), drawable size (2). Uniforms follow from U[6].
        var index = 6
        var loads: [String] = []
        for u in uniforms {
            let parts = (index..<index + u.components).map { "U[\($0)]" }.joined(separator: ", ")
            loads.append("    s.\(u.name) = \(u.components == 1 ? parts : "\(type(of: u))(\(parts))");")
            index += u.components
        }

        return """
        \(prelude)
        struct LessonShader {
            vec4 bounds;        // maths window: xmin, xmax, ymin, ymax
            vec2 resolution;    // drawable size in pixels
            vec3 iResolution;   // the same, for Shadertoy code
            float pixel;        // width of one pixel in maths units
            vec2 fragCoord;     // pixel position, origin top left
        \(members)

        #line 1
        \(rewrite(glsl))
        };

        struct LessonVertexOut { float4 position [[position]]; };

        // One triangle covering the whole view.
        vertex LessonVertexOut lessonVertex(uint id [[vertex_id]]) {
            float2 uv = float2((id << 1) & 2, id & 2);
            LessonVertexOut out;
            out.position = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
            return out;
        }

        fragment float4 lessonFragment(LessonVertexOut in [[stage_in]], constant float *U [[buffer(0)]]) {
            LessonShader s;
            s.bounds = float4(U[0], U[1], U[2], U[3]);
            s.resolution = float2(U[4], U[5]);
            s.iResolution = float3(U[4], U[5], 1.0);
            s.pixel = (U[1] - U[0]) / U[4];
            s.fragCoord = in.position.xy;
        \(loads.joined(separator: "\n"))
            float2 p = float2(U[0] + in.position.x / U[4] * (U[1] - U[0]),
                              U[3] - in.position.y / U[5] * (U[3] - U[2]));
            \(entry)
        }
        """
    }

    private static func type(of u: Uniform) -> String {
        u.components == 1 ? "float" : "vec\(u.components)"
    }

    // Line-preserving rewrites, so #line 1 keeps error line numbers matching the author's source.
    static func rewrite(_ glsl: String) -> String {
        var s = glsl
        let replacements: [(String, String)] = [
            // Declarations the struct provides or Metal doesn't have. Blanked, not removed.
            (#"(?m)^[ \t]*#version[^\n]*"#, ""),
            (#"(?m)^[ \t]*precision\s+\w+\s+\w+\s*;"#, ""),
            (#"(?m)^[ \t]*uniform\s+[^;]*;"#, ""),
            // Parameter qualifiers: out and inout become references; in is the default.
            (#"\b(?:inout|out)\s+(\w+)\s+(\w+)"#, "thread $1& $2"),
            (#"\bin\s+(\w+\s+\w+)"#, "$1"),
        ]
        for (pattern, template) in replacements {
            s = s.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        return s
    }

    // GLSL names that Metal spells differently, or functions whose meaning differs.
    static let prelude = """
    #include <metal_stdlib>
    using namespace metal;

    typedef float2 vec2;    typedef float3 vec3;    typedef float4 vec4;
    typedef int2 ivec2;     typedef int3 ivec3;     typedef int4 ivec4;
    typedef uint2 uvec2;    typedef uint3 uvec3;    typedef uint4 uvec4;
    typedef bool2 bvec2;    typedef bool3 bvec3;    typedef bool4 bvec4;
    typedef float2x2 mat2;  typedef float3x3 mat3;  typedef float4x4 mat4;

    #define lowp
    #define mediump
    #define highp
    #define discard discard_fragment()
    #define dFdx dfdx
    #define dFdy dfdy
    #define inversesqrt rsqrt

    // GLSL's mod floors; Metal's fmod truncates, which differs for negative numbers.
    inline float mod(float x, float y) { return x - y * floor(x / y); }
    inline float2 mod(float2 x, float2 y) { return x - y * floor(x / y); }
    inline float3 mod(float3 x, float3 y) { return x - y * floor(x / y); }
    inline float4 mod(float4 x, float4 y) { return x - y * floor(x / y); }
    inline float2 mod(float2 x, float y) { return x - y * floor(x / y); }
    inline float3 mod(float3 x, float y) { return x - y * floor(x / y); }
    inline float4 mod(float4 x, float y) { return x - y * floor(x / y); }

    // GLSL's two-argument atan is Metal's atan2.
    inline float atan(float y, float x) { return atan2(y, x); }
    inline float2 atan(float2 y, float2 x) { return atan2(y, x); }
    inline float3 atan(float3 y, float3 x) { return atan2(y, x); }
    inline float4 atan(float4 y, float4 x) { return atan2(y, x); }
    """
}
