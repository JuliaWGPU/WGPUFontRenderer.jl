# Faithful WGSL translation of the reference gpu-font-rendering implementation
# Based on: https://github.com/GreenLightning/gpu-font-rendering

function getReferenceVertexShader()::String
    return """
// Faithful translation of reference vertex shader

struct VertexInput {
    @location(0) position: vec2<f32>,
    @location(1) depth: f32,
    @location(2) uv: vec2<f32>,
    @location(3) bufferIndex: i32,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) bufferIndex: i32,
}

struct FontUniforms {
    color: vec4<f32>,
    projection: mat4x4<f32>,
    antiAliasingWindowSize: f32,
    enableSuperSamplingAntiAliasing: u32,
    padding: vec2<u32>,
}

@group(0) @binding(2) var<uniform> uniforms: FontUniforms;

@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;
    
    // Transform position exactly like reference implementation
    let worldPos = vec4<f32>(input.position, input.depth, 1.0);
    output.position = uniforms.projection * worldPos;
    
    // Pass through UV coordinates and buffer index
    output.uv = input.uv;
    output.bufferIndex = input.bufferIndex;
    
    return output;
}
"""
end

function getReferenceFragmentShader()::String
    return """
// Faithful WGSL translation of reference gpu-font-rendering fragment shader
// Based on: http://wdobbie.com/post/gpu-text-rendering-with-vector-textures/

struct Glyph {
    start: u32,
    count: u32,
}

struct Curve {
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    x2: f32,
    y2: f32,
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
    // Handle special visualization cases
    if (input.bufferIndex == -1) {
        return vec4<f32>(1.0, 0.0, 0.0, 0.1); // Red text quad bounding box
    }
    if (input.bufferIndex == -2) {
        return vec4<f32>(0.0, 0.0, 1.0, 0.05); // Blue text block bounding box
    }
    
    // Bounds check for glyph index
    if (input.bufferIndex < 0 || input.bufferIndex >= i32(arrayLength(&glyphs))) {
        return vec4<f32>(0.0, 0.0, 0.0, 0.0);
    }
    
    var alpha = 0.0;
    
    // CRITICAL FIX: Proper fwidth() approximation for WGSL
    // The reference implementation uses: vec2 inverseDiameter = 1.0 / (antiAliasingWindowSize * fwidth(uv));
    // In WGSL, we need to approximate fwidth() using dpdx() and dpdy()
    
    // Calculate fwidth approximation: fwidth(uv) ≈ abs(dpdx(uv)) + abs(dpdy(uv))
    let duvdx = dpdx(input.uv);
    let duvdy = dpdy(input.uv);
    let fwidthUV = abs(duvdx) + abs(duvdy);
    
    // CRITICAL FIX: Prevent division by zero or very small values that cause horizontal line artifacts
    // Use max() to ensure we have a minimum derivative value
    let minDerivative = max(fwidthUV, vec2<f32>(1e-6, 1e-6));
    
    // Calculate inverse diameter exactly like reference implementation
    // This eliminates the coordinate space mismatch that causes horizontal lines
    let inverseDiameter = 1.0 / (uniforms.antiAliasingWindowSize * minDerivative);
    
    let glyph = glyphs[input.bufferIndex];
    
    // Process each curve with reference algorithm
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }
        
        let curve = curves[curveIndex];
        
        // Transform curve points to sample space (exact reference translation)
        let p0 = vec2<f32>(curve.x0, curve.y0) - input.uv;
        let p1 = vec2<f32>(curve.x1, curve.y1) - input.uv;
        let p2 = vec2<f32>(curve.x2, curve.y2) - input.uv;
        
        // Use reference coverage calculation with proper inverse diameter
        alpha += computeCoverage(inverseDiameter.x, p0, p1, p2);
        
        // Super-sampling anti-aliasing (reference implementation)
        if (uniforms.enableSuperSamplingAntiAliasing != 0u) {
            alpha += computeCoverage(inverseDiameter.y, rotate(p0), rotate(p1), rotate(p2));
        }
    }
    
    // Apply super-sampling normalization
    if (uniforms.enableSuperSamplingAntiAliasing != 0u) {
        alpha *= 0.5;
    }
    
    // Clamp and return result
    alpha = clamp(alpha, 0.0, 1.0);
    return uniforms.color * alpha;
}

// EXACT translation of reference computeCoverage function
fn computeCoverage(inverseDiameter: f32, p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> f32 {
    // Early exit if curve is entirely above or below the horizontal ray
    if (p0.y > 0.0 && p1.y > 0.0 && p2.y > 0.0) { return 0.0; }
    if (p0.y < 0.0 && p1.y < 0.0 && p2.y < 0.0) { return 0.0; }
    
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
        // the ray always exits the shape at t0 and enters at t1. For a
        // quadratic segment this works 'automatically', see readme.
        let t = p0.y / (p0.y - p2.y);
        if (p0.y < p2.y) {
            t0 = -1.0;
            t1 = t;
        } else {
            t0 = t;
            t1 = -1.0;
        }
    }
    
    var alpha = 0.0;
    
    // CRITICAL FIX: Use exact bounds from reference implementation
    // Reference uses t0 < 1.0 and t1 < 1.0 (not <=) to avoid edge artifacts
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

// Rotation function for super-sampling
fn rotate(v: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(v.y, -v.x);
}
"""
end

# Updated shader selection to use reference implementation
function getVertexShader()::String
    return getReferenceVertexShader()
end

function getFragmentShader()::String
    return getReferenceFragmentShader()
end