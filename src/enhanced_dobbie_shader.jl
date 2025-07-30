# Enhanced Will Dobbie shader with improved multi-angle sampling
# Based on https://wdobbie.com/post/gpu-text-rendering-with-vector-textures/
# Implements multiple sampling angles for better anti-aliasing

function getEnhancedDobbieFragmentShader()::String
    return """
// Enhanced Will Dobbie shader with multiple sampling angles
// Implements the multi-angle sampling approach suggested by Will Dobbie
// for better anti-aliasing and artifact reduction

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
    
    // Enhanced multi-angle sampling approach
    // Calculate fwidth approximation for proper anti-aliasing
    let duvdx = dpdx(input.uv);
    let duvdy = dpdy(input.uv);
    let fwidthUV = abs(duvdx) + abs(duvdy);
    let inverseDiameter = 1.0 / (uniforms.antiAliasingWindowSize * fwidthUV);
    
    let glyph = glyphs[input.bufferIndex];
    
    // Will Dobbie's enhanced approach: multiple sampling angles
    let numAngles = 4; // Test 4 different angles for better coverage
    let angleStep = 1.5707963 / f32(numAngles); // pi/2 divided by number of angles
    
    for (var angleIdx = 0; angleIdx < numAngles; angleIdx++) {
        let angle = f32(angleIdx) * angleStep;
        let cosAngle = cos(angle);
        let sinAngle = sin(angle);
        
        // Process each curve with rotated coordinate system
        for (var i = 0u; i < glyph.count; i += 1u) {
            let curveIndex = glyph.start + i;
            if (curveIndex >= arrayLength(&curves)) {
                break;
            }
            
            let curve = curves[curveIndex];
            
            // Transform curve points to sample space
            let p0_local = vec2<f32>(curve.x0, curve.y0) - input.uv;
            let p1_local = vec2<f32>(curve.x1, curve.y1) - input.uv;
            let p2_local = vec2<f32>(curve.x2, curve.y2) - input.uv;
            
            // Apply rotation for this sampling angle
            let p0 = vec2<f32>(
                cosAngle * p0_local.x - sinAngle * p0_local.y,
                sinAngle * p0_local.x + cosAngle * p0_local.y
            );
            let p1 = vec2<f32>(
                cosAngle * p1_local.x - sinAngle * p1_local.y,
                sinAngle * p1_local.x + cosAngle * p1_local.y
            );
            let p2 = vec2<f32>(
                cosAngle * p2_local.x - sinAngle * p2_local.y,
                sinAngle * p2_local.x + cosAngle * p2_local.y
            );
            
            // Use reference coverage calculation
            alpha += computeEnhancedCoverage(inverseDiameter.x, p0, p1, p2);
        }
    }
    
    // Average across all angles
    alpha /= f32(numAngles);
    
    // Clamp and return result
    alpha = clamp(alpha, 0.0, 1.0);
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
}

// Enhanced coverage calculation based on reference implementation
fn computeEnhancedCoverage(inverseDiameter: f32, p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> f32 {
    // Early exit if curve is entirely above or below the horizontal ray
    if (p0.y > 0.0 && p1.y > 0.0 && p2.y > 0.0) { return 0.0; }
    if (p0.y < 0.0 && p1.y < 0.0 && p2.y < 0.0) { return 0.0; }
    
    // Reference implementation coefficients
    let a = p0 - 2.0 * p1 + p2;
    let b = p0 - p1;
    let c = p0;
    
    var t0: f32;
    var t1: f32;
    
    if (abs(a.y) >= 1e-5) {
        // Quadratic segment, solve abc formula to find roots
        let radicand = b.y * b.y - a.y * c.y;
        if (radicand <= 0.0) { return 0.0; }
        
        let s = sqrt(radicand);
        t0 = (b.y - s) / a.y;
        t1 = (b.y + s) / a.y;
    } else {
        // Linear segment, avoid division by a.y which is near zero
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
    
    // Process intersections with exact bounds from reference
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
"""
end

function getEnhancedDobbieVertexShader()::String
    return """
// Enhanced Dobbie vertex shader
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
    
    let worldPos = vec4<f32>(input.position, input.depth, 1.0);
    output.position = uniforms.projection * worldPos;
    output.uv = input.uv;
    output.bufferIndex = input.bufferIndex;
    
    return output;
}
"""
end