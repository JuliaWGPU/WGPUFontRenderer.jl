# WGSL Shader generation for font rendering
# Based on gpu-font-renderer implementation

function getVertexShader()::String
    return """
// Vertex shader for font rendering

struct Glyph {
    start: u32,
    count: u32,
}

struct Curve {
    p0: vec2<f32>,
    p1: vec2<f32>,
    p2: vec2<f32>,
}

struct FontUniforms {
    color: vec4<f32>,
    projection: mat4x4<f32>,
    antiAliasingWindowSize: f32,
    enableSuperSamplingAntiAliasing: u32,
    padding: vec2<u32>,
}

struct VertexInput {
    @location(0) position: vec2<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) bufferIndex: i32,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) bufferIndex: i32,
}

@group(0) @binding(0) var<storage, read> glyphs: array<Glyph>;
@group(0) @binding(1) var<storage, read> curves: array<Curve>;
@group(0) @binding(2) var<uniform> uniforms: FontUniforms;

@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;

    // Transform position by projection matrix
    let worldPos = vec4<f32>(input.position, 0.0, 1.0);
    output.position = uniforms.projection * worldPos;

    // Pass through UV coordinates and buffer index
    output.uv = input.uv;
    output.bufferIndex = input.bufferIndex;

    return output;
}
"""
end

function getFragmentShader()::String
    # return getDebugFragmentShader()  # Use debug shader first to see positioning
    return getComplexFragmentShader()  # Use complex shader for proper vector font rendering
end

# Simple debug shader that shows solid colors per character
function getDebugFragmentShader()::String
    return """
// Fragment shader for font rendering - debug version showing solid rectangles

struct Glyph {
    start: u32,
    count: u32,
}

struct Curve {
    p0: vec2<f32>,
    p1: vec2<f32>,
    p2: vec2<f32>,
}

struct FontUniforms {
    color: vec4<f32>,
    projection: mat4x4<f32>,
    antiAliasingWindowSize: f32,
    enableSuperSamplingAntiAliasing: u32,
    padding: vec2<u32>,
}

struct FragmentInput {
    @location(0) uv: vec2<f32>,
    @location(1) bufferIndex: i32,
}

@group(0) @binding(0) var<storage, read> glyphs: array<Glyph>;
@group(0) @binding(1) var<storage, read> curves: array<Curve>;
@group(0) @binding(2) var<uniform> uniforms: FontUniforms;

@fragment
fn fs_main(input: FragmentInput) -> @location(0) vec4<f32> {
    // Simple solid color test - just return bright colors
    // This should be easily visible

    if (input.bufferIndex < 0) {
        return vec4<f32>(1.0, 0.0, 0.0, 1.0);  // Red for invalid indices
    }

    // Show different solid colors for different characters
    if (input.bufferIndex == 0) {
        return vec4<f32>(0.0, 1.0, 0.0, 1.0);  // Green for first character
    } else if (input.bufferIndex == 1) {
        return vec4<f32>(0.0, 0.0, 1.0, 1.0);  // Blue for second character
    } else {
        return vec4<f32>(1.0, 1.0, 0.0, 1.0);  // Yellow for other characters
    }
}
"""
end

# Keep the original complex fragment shader for later use
function getComplexFragmentShader()::String
    return """
// Fragment shader for font rendering with coverage calculation
// Based on the original C++ gpu-font-rendering implementation

struct Glyph {
    start: u32,
    count: u32,
}

struct Curve {
    p0: vec2<f32>,
    p1: vec2<f32>,
    p2: vec2<f32>,
}

struct FontUniforms {
    color: vec4<f32>,
    projection: mat4x4<f32>,
    antiAliasingWindowSize: f32,
    enableSuperSamplingAntiAliasing: u32,
    padding: vec2<u32>,
}

struct FragmentInput {
    @location(0) uv: vec2<f32>,
    @location(1) bufferIndex: i32,
}

@group(0) @binding(0) var<storage, read> glyphs: array<Glyph>;
@group(0) @binding(1) var<storage, read> curves: array<Curve>;
@group(0) @binding(2) var<uniform> uniforms: FontUniforms;

@fragment
fn fs_main(input: FragmentInput) -> @location(0) vec4<f32> {
    if (input.bufferIndex < 0 || input.bufferIndex >= i32(arrayLength(&glyphs))) {
        return vec4<f32>(0.0, 0.0, 0.0, 0.0);
    }

    var alpha = 0.0;
    
    // Inverse of the diameter of a pixel in uv units for anti-aliasing.
    let inverseDiameter = 1.0 / (uniforms.antiAliasingWindowSize * fwidth(input.uv));
    
    let glyph = glyphs[input.bufferIndex];
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }

        let curve = curves[curveIndex];
        
        // Transform curve points relative to current UV coordinate
        let p0 = curve.p0 - input.uv;
        let p1 = curve.p1 - input.uv;
        let p2 = curve.p2 - input.uv;
        
        alpha += computeCoverage(inverseDiameter.x, p0, p1, p2);
        
        if (uniforms.enableSuperSamplingAntiAliasing != 0u) {
            alpha += computeCoverage(inverseDiameter.y, rotate(p0), rotate(p1), rotate(p2));
        }
    }
    
    if (uniforms.enableSuperSamplingAntiAliasing != 0u) {
        alpha *= 0.5;
    }
    
    alpha = clamp(alpha, 0.0, 1.0);
    
    // Fix inverted text by inverting the alpha value. Ensure that rendered glyphs appear correctly.
    if (uniforms.enableSuperSamplingAntiAliasing != 0u) {
        alpha = 1.0 - alpha; 
    }
    
    // Debug: Show alpha as grayscale to understand coverage
    
    // For debugging, output alpha as grayscale to analyze.
    return vec4<f32>(alpha, alpha, alpha, 1.0);
}

fn computeCoverage(
    inverseDiameter: f32,
    p0: vec2<f32>,
    p1: vec2<f32>,
    p2: vec2<f32>
) -> f32 {
    // Early exit if curve is entirely above or below the ray
    if (p0.y > 0.0 && p1.y > 0.0 && p2.y > 0.0) { return 0.0; }
    if (p0.y < 0.0 && p1.y < 0.0 && p2.y < 0.0) { return 0.0; }
    
    // Quadratic Bezier curve coefficients
    // Note: Simplified from abc formula by extracting a factor of (-2) from b.
    let a = p0 - 2.0 * p1 + p2;
    let b = p0 - p1;
    let c = p0;
    
    var t0: f32;
    var t1: f32;
    
    if (abs(a.y) >= 1e-5) {
        // Quadratic segment, solve abc formula to find roots.
        let radicand = b.y * b.y - a.y * c.y;
        if (radicand <= 0.0) { return 0.0; }
        
        let s = sqrt(radicand);
        t0 = (b.y - s) / a.y;
        t1 = (b.y + s) / a.y;
    } else {
        // Linear segment, avoid division by a.y, which is near zero.
        // There is only one root, so we have to decide which variable to
        // assign it to based on the direction of the segment, to ensure that
        // the ray always exits the shape at t0 and enters at t1.
        if (abs(p0.y - p2.y) < 1e-10) {
            // Degenerate case - line is horizontal
            t0 = -1.0;
            t1 = -1.0;
        } else {
            let t = p0.y / (p0.y - p2.y);
            if (p0.y < p2.y) {
                t0 = -1.0;
                t1 = t;
            } else {
                t0 = t;
                t1 = -1.0;
            }
        }
    }
    
    var alpha = 0.0;
    
    if (t0 >= 0.0 && t0 < 1.0) {
        let x = (a.x * t0 - 2.0 * b.x) * t0 + c.x;
        alpha += clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
    }
    
    if (t1 >= 0.0 && t1 < 1.0) {
        let x = (a.x * t1 - 2.0 * b.x) * t1 + c.x;
        alpha -= clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
    }
    
    return alpha;
}

fn rotate(v: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(v.y, -v.x);
}
"""
end
