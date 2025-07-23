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
    # Use coordinate scaling fix shader to address horizontal line artifacts
    return getCoordinateScalingFixShader()
    
    # Previous debug: 
    # return getNoSuperSamplingShader()
    
    # Original: Use the exact reference implementation from gpu-font-rendering
    # return getReferenceFragmentShader()
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

# Debug coverage shader to analyze winding number issues
function getDebugCoverageShader()::String
    return """
// Improved fragment shader for font rendering with better numerical stability
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
    
    // Use a simple fixed anti-aliasing value to isolate horizontal line issues
    // This eliminates potential derivative calculation problems
    let inverseDiameter = 1.0 / uniforms.antiAliasingWindowSize;
    
    let glyph = glyphs[input.bufferIndex];
    
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
        
        // Calculate coverage for this curve
        alpha += computeCoverage(inverseDiameter, p0, p1, p2);
        
        // Apply super-sampling anti-aliasing if enabled
        if (uniforms.enableSuperSamplingAntiAliasing != 0u) {
            // Rotate points 90 degrees for second sample
            let rp0 = vec2<f32>(p0.y, -p0.x);
            let rp1 = vec2<f32>(p1.y, -p1.x);
            let rp2 = vec2<f32>(p2.y, -p2.x);
            
            alpha += computeCoverage(inverseDiameter, rp0, rp1, rp2);
        }
    }
    
    // Average the samples if super-sampling is enabled
    if (uniforms.enableSuperSamplingAntiAliasing != 0u) {
        alpha *= 0.5;
    }
    
    // Clamp final alpha to valid range
    alpha = clamp(alpha, 0.0, 1.0);
    
    // Return final color with proper alpha blending
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
    // Note: Simplified from abc formula by extracting a factor of (-2) from b
    let a = p0 - 2.0 * p1 + p2;
    let b = p0 - p1;
    let c = p0;
    
    var t0: f32 = -1.0;
    var t1: f32 = -1.0;
    
    if (abs(a.y) >= 1e-5) {
        // Quadratic segment - solve using quadratic formula
        let radicand = b.y * b.y - a.y * c.y;
        if (radicand > 0.0) {  // Changed from >= to > to avoid numerical issues
            let s = sqrt(radicand);
            t0 = (b.y - s) / a.y;
            t1 = (b.y + s) / a.y;
        }
    } else {
        // Linear segment - avoid division by zero
        // Handle the case where a.y is near zero more carefully
        if (abs(p0.y - p2.y) > 1e-10) {
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
    
    // Process first root (exit point)
    if (t0 >= 0.0 && t0 < 1.0) {  // Changed <= to < to match reference
        let x = (a.x * t0 - 2.0 * b.x) * t0 + c.x;
        alpha += clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
    }
    
    // Process second root (entry point)
    if (t1 >= 0.0 && t1 < 1.0) {  // Changed <= to < to match reference
        let x = (a.x * t1 - 2.0 * b.x) * t1 + c.x;
        alpha -= clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
    }
    
    return alpha;  // Don't clamp here, let the caller handle final clamping
}
"""
end

# Stable coverage shader with improved numerical precision
function getStableCoverageShader()::String
    return """
// Stable fragment shader for font rendering with reduced artifacts
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
    
    // Use a conservative anti-aliasing window size
    let inverseDiameter = 1.0 / max(uniforms.antiAliasingWindowSize, 1.0);
    
    let glyph = glyphs[input.bufferIndex];
    
    // Only process curves that could potentially contribute
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
        
        // Calculate coverage for this curve with improved stability
        alpha += computeStableCoverage(inverseDiameter, p0, p1, p2);
    }
    
    // Clamp final alpha to valid range
    alpha = clamp(alpha, 0.0, 1.0);
    
    // Return final color with proper alpha blending
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
}

fn computeStableCoverage(
    inverseDiameter: f32,
    p0: vec2<f32>,
    p1: vec2<f32>,
    p2: vec2<f32>
) -> f32 {
    // More aggressive early exit if curve is entirely above or below the ray
    if (p0.y > 0.0 && p1.y > 0.0 && p2.y > 0.0) { return 0.0; }
    if (p0.y < 0.0 && p1.y < 0.0 && p2.y < 0.0) { return 0.0; }
    
    // Quadratic Bezier curve coefficients
    let a = p0 - 2.0 * p1 + p2;
    let b = p0 - p1;
    let c = p0;
    
    var t0 = -1.0;
    var t1 = -1.0;
    
    // More robust numerical handling with better epsilon values
    let eps = 1e-8;  // Tighter epsilon for better precision
    
    if (abs(a.y) > eps) {
        // Quadratic case - use numerically stable quadratic formula
        let discriminant = b.y * b.y - a.y * c.y;
        if (discriminant > eps) {  // Avoid near-zero discriminants
            let sqrtDisc = sqrt(discriminant);
            // Use the numerically stable version of quadratic formula
            if (b.y >= 0.0) {
                let q = -(b.y + sqrtDisc);
                t0 = q / a.y;
                t1 = c.y / q;
            } else {
                let q = -(b.y - sqrtDisc);
                t0 = c.y / q;
                t1 = q / a.y;
            }
            
            // Ensure proper ordering
            if (t0 > t1) {
                let temp = t0;
                t0 = t1;
                t1 = temp;
            }
        }
    } else {
        // Linear case - more robust handling
        let denomY = p0.y - p2.y;
        if (abs(denomY) > eps) {
            let t = p0.y / denomY;
            if (t >= 0.0 && t <= 1.0) {
                if (p0.y < p2.y) {
                    t1 = t;
                } else {
                    t0 = t;
                }
            }
        }
    }
    
    var alpha = 0.0;
    
    // Process intersections with more stable evaluation and bounds checking
    if (t0 >= -1e-6 && t0 <= 1.0 + 1e-6) {  // Slightly relaxed bounds to avoid edge artifacts
        let x = evaluateQuadraticX(a.x, b.x, c.x, clamp(t0, 0.0, 1.0));
        let contribution = clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
        alpha += contribution;
    }
    
    if (t1 >= -1e-6 && t1 <= 1.0 + 1e-6) {  // Slightly relaxed bounds to avoid edge artifacts
        let x = evaluateQuadraticX(a.x, b.x, c.x, clamp(t1, 0.0, 1.0));
        let contribution = clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
        alpha -= contribution;
    }
    
    return alpha;
}

fn evaluateQuadraticX(a: f32, b: f32, c: f32, t: f32) -> f32 {
    // Use Horner's method for better numerical stability
    return (a * t - 2.0 * b) * t + c;
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
    // This needs to be tuned based on the actual font scale being used
    // Larger values = sharper edges, smaller values = more anti-aliasing
    let inverseDiameter = 1.0;  // Middle-ground value for font units
    
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
    
    var t0: f32 = -1.0;
    var t1: f32 = -1.0;
    
    if (abs(a.y) >= 1e-5) {
        // Quadratic segment, solve abc formula to find roots.
        let radicand = b.y * b.y - a.y * c.y;
        if (radicand > 0.0) {
            let s = sqrt(radicand);
            t0 = (b.y - s) / a.y;
            t1 = (b.y + s) / a.y;
            
            // Ensure t0 <= t1
            if (t0 > t1) {
                let temp = t0;
                t0 = t1;
                t1 = temp;
            }
        }
    } else {
        // Linear segment, avoid division by a.y, which is near zero.
        if (abs(p0.y - p2.y) > 1e-10) {
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
    
    if (t0 >= 0.0 && t0 <= 1.0) {
        let x = (a.x * t0 - 2.0 * b.x) * t0 + c.x;
        let contribution = clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
        alpha += contribution;
    }
    
    if (t1 >= 0.0 && t1 <= 1.0) {
        let x = (a.x * t1 - 2.0 * b.x) * t1 + c.x;
        let contribution = clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
        alpha -= contribution;
    }
    
    // Clamp the final result to prevent extreme values
    return clamp(alpha, -1.0, 1.0);
}

fn rotate(v: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(v.y, -v.x);
}
"""
end

# EXACT reference implementation from gpu-font-rendering
# Translated directly from the OpenGL fragment shader
function getNoSuperSamplingShader()::String
    return """
// Debug shader with super-sampling DISABLED to isolate horizontal line artifacts
// This removes the potential source of instability from the rotated ray sampling

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
    
    // Use a MUCH simpler inverse diameter calculation
    // This completely avoids fwidth approximation issues
    let inverseDiameter = 1.0 / uniforms.antiAliasingWindowSize;
    
    let glyph = glyphs[input.bufferIndex];
    
    // Only use the main ray - NO super-sampling at all
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }
        
        let curve = curves[curveIndex];
        let p0 = curve.p0 - input.uv;
        let p1 = curve.p1 - input.uv;
        let p2 = curve.p2 - input.uv;
        
        // Use the exact same coverage calculation as reference but NO rotation
        alpha += computeCoverage(inverseDiameter, p0, p1, p2);
    }
    
    // NO averaging since we only have one sample
    
    alpha = clamp(alpha, 0.0, 1.0);
    return uniforms.color * alpha;
}

fn computeCoverage(inverseDiameter: f32, p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> f32 {
    if (p0.y > 0.0 && p1.y > 0.0 && p2.y > 0.0) { return 0.0; }
    if (p0.y < 0.0 && p1.y < 0.0 && p2.y < 0.0) { return 0.0; }
    
    let a = p0 - 2.0 * p1 + p2;
    let b = p0 - p1;
    let c = p0;
    
    var t0: f32;
    var t1: f32;
    if (abs(a.y) >= 1e-5) {
        let radicand = b.y * b.y - a.y * c.y;
        if (radicand <= 0.0) { return 0.0; }
        
        let s = sqrt(radicand);
        t0 = (b.y - s) / a.y;
        t1 = (b.y + s) / a.y;
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
"""
end

function getReferenceFragmentShader()::String
    return """
// EXACT WGSL translation of gpu-font-rendering fragment shader
// Based on: http://wdobbie.com/post/gpu-text-rendering-with-vector-textures/

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
    var alpha = 0.0;
    
    // Proper fwidth approximation for WGSL
    // The reference uses: vec2 inverseDiameter = 1.0 / (antiAliasingWindowSize * fwidth(uv))
    // We need to approximate fwidth(uv) based on the font scale and pixel size
    
    // Debug: Use much simpler inverse diameter calculation to eliminate coordinate space issues
    // The horizontal lines suggest a scaling problem with the fwidth approximation
    
    // Try direct scaling based on font units to screen pixels
    // Font units are ~2000, screen scale is 0.05, so 1 font unit = 0.05 screen pixels
    // Therefore 1 screen pixel = 20 font units
    let pixelSizeInFontUnits = 20.0; // 1/0.05
    
    // Use a much larger anti-aliasing window to reduce sensitivity to numerical precision
    let inverseDiameterX = 1.0 / (uniforms.antiAliasingWindowSize * pixelSizeInFontUnits);
    let inverseDiameterY = inverseDiameterX; // Use same value for both directions initially
    
    if (input.bufferIndex < 0 || input.bufferIndex >= i32(arrayLength(&glyphs))) {
        return vec4<f32>(0.0, 0.0, 0.0, 0.0);
    }
    
    let glyph = glyphs[input.bufferIndex];
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }
        
        let curve = curves[curveIndex];
        
        let p0 = curve.p0 - input.uv;
        let p1 = curve.p1 - input.uv;
        let p2 = curve.p2 - input.uv;
        
        alpha += computeCoverage(inverseDiameterX, p0, p1, p2);
        if (uniforms.enableSuperSamplingAntiAliasing != 0u) {
            alpha += computeCoverage(inverseDiameterY, rotate(p0), rotate(p1), rotate(p2));
        }
    }
    
    if (uniforms.enableSuperSamplingAntiAliasing != 0u) {
        alpha *= 0.5;
    }
    
    alpha = clamp(alpha, 0.0, 1.0);
    return uniforms.color * alpha;
}

// EXACT translation of the reference computeCoverage function
fn computeCoverage(inverseDiameter: f32, p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> f32 {
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
