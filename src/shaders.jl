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
    # return getSimpleTestShader()  # Use simple test shader first
    # return getDebugFragmentShader()  # Use debug shader for UV visualization
    return getComplexFragmentShader()  # Use complex shader for proper vector font rendering
end

# Simple test shader that shows solid colors per character
function getSimpleTestShader()::String
    return """
struct FragmentInput {
    @location(0) uv: vec2<f32>,
    @location(1) bufferIndex: i32,
}

@fragment
fn fs_main(input: FragmentInput) -> @location(0) vec4<f32> {
    // Different colors for different characters based on bufferIndex
    let colorIndex = input.bufferIndex % 6;
    
    if (colorIndex == 0) {
        return vec4<f32>(1.0, 0.0, 0.0, 1.0);  // Red
    } else if (colorIndex == 1) {
        return vec4<f32>(0.0, 1.0, 0.0, 1.0);  // Green
    } else if (colorIndex == 2) {
        return vec4<f32>(0.0, 0.0, 1.0, 1.0);  // Blue
    } else if (colorIndex == 3) {
        return vec4<f32>(1.0, 1.0, 0.0, 1.0);  // Yellow
    } else if (colorIndex == 4) {
        return vec4<f32>(1.0, 0.0, 1.0, 1.0);  // Magenta
    } else {
        return vec4<f32>(0.0, 1.0, 1.0, 1.0);  // Cyan
    }
}
"""
end

# Simple debug shader that shows solid colors per character
function getDebugFragmentShader()::String
    return """
struct FragmentInput {
    @location(0) uv: vec2<f32>,
    @location(1) bufferIndex: i32,
}

@fragment
fn fs_main(input: FragmentInput) -> @location(0) vec4<f32> {
    // Simple visualization of UV coordinates
    // Since the debug files show UVs are set to 0.0-1.0 normalized values,
    // we can directly use them as colors
    
    // Red = U coordinate, Green = V coordinate, Blue = 0.5 for visibility
    return vec4<f32>(input.uv.x, input.uv.y, 0.5, 1.0);
}
"""
end

# Simplified complex shader for debugging coverage calculations
function getSimpleComplexShader()::String
    return """
// Simplified fragment shader for debugging coverage calculation
// Based on the reference gpu-font-rendering implementation

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
    
    // Use a fixed large value for better visibility during testing
    let inverseDiameter = 100.0;
    
    let glyph = glyphs[input.bufferIndex];
    
    // Simplified coverage calculation - just count intersections
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }

        let curve = curves[curveIndex];
        
        // Transform curve control points by subtracting sample position
        let p0 = curve.p0 - input.uv;
        let p1 = curve.p1 - input.uv;
        let p2 = curve.p2 - input.uv;
        
        // Simple coverage test - if any curve crosses the horizontal ray
        if ((p0.y <= 0.0 && p2.y > 0.0) || (p0.y > 0.0 && p2.y <= 0.0)) {
            alpha += 0.1; // Add small contribution per crossing
        }
    }
    
    alpha = clamp(alpha, 0.0, 1.0);
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
}
"""
end

# Keep the original complex fragment shader for later use
function getComplexFragmentShader()::String
    return """
// Fragment shader for font rendering with coverage calculation
// Based on the reference gpu-font-rendering implementation

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
    
    // Calculate inverse diameter for anti-aliasing based on font units
    // For font units, we need a much smaller value than screen coordinates
    // This controls the smoothness of the anti-aliasing
    let inverseDiameter = 0.1;  // Smaller value for font units
    
    let glyph = glyphs[input.bufferIndex];
    
    // Use the reference implementation's computeCoverage algorithm
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }

        let curve = curves[curveIndex];
        
        // Transform curve control points by subtracting sample position
        let p0 = curve.p0 - input.uv;
        let p1 = curve.p1 - input.uv;
        let p2 = curve.p2 - input.uv;
        
        alpha += computeCoverage(inverseDiameter, p0, p1, p2);
    }
    
    // Clamp alpha to prevent over/under-saturation artifacts
    alpha = clamp(alpha, 0.0, 1.0);
    
    // Return color with proper alpha blending
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
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
