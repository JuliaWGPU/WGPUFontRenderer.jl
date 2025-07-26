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
    return getFixedFragmentShader()
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


# Fixed fragment shader that resolves the horizontal/vertical line artifacts
function getFixedFragmentShader()::String
    return """
// Fixed fragment shader for font rendering - eliminates horizontal/vertical line artifacts
// Based on gpu-font-rendering with proper coordinate space handling

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
    
    // COORDINATE SPACE FIX:
    // The issue was incorrect scaling between font units and screen pixels
    // Font scale used in vertex generation: 0.01 (1 font unit = 0.01 screen pixels)
    // So 1 screen pixel = 100 font units
    
    let fontUnitsPerScreenPixel = 100.0; // 1/0.01
    
    // Scale the anti-aliasing window to font units
    // This ensures proper coverage calculation without artifacts
    let scaledWindowSize = uniforms.antiAliasingWindowSize * fontUnitsPerScreenPixel;
    let inverseDiameter = 1.0 / max(scaledWindowSize, 1.0);
    
    let glyph = glyphs[input.bufferIndex];
    
    // Process each curve with fixed coordinate handling
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }
        
        let curve = curves[curveIndex];
        
        // Transform curve points to sample space
        let p0 = curve.p0 - input.uv;
        let p1 = curve.p1 - input.uv;
        let p2 = curve.p2 - input.uv;
        
        // Calculate coverage with improved numerical stability
        alpha += computeFixedCoverage(inverseDiameter, p0, p1, p2);
    }
    
    // Clamp and return result
    alpha = clamp(alpha, 0.0, 1.0);
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
}

// Fixed coverage calculation with improved numerical stability
fn computeFixedCoverage(inverseDiameter: f32, p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> f32 {
    // Early exit if curve is entirely above or below the horizontal ray
    if (p0.y > 0.0 && p1.y > 0.0 && p2.y > 0.0) { return 0.0; }
    if (p0.y < 0.0 && p1.y < 0.0 && p2.y < 0.0) { return 0.0; }
    
    // Quadratic Bezier coefficients: B(t) = (1-t)²p0 + 2t(1-t)p1 + t²p2
    // Rearranged as: B(t) = at² + bt + c where:
    let a = p0 - 2.0 * p1 + p2;
    let b = 2.0 * (p1 - p0);
    let c = p0;
    
    var t0 = -1.0;
    var t1 = -1.0;
    
    let eps = 1e-6;
    
    if (abs(a.y) > eps) {
        // Quadratic case - find where curve crosses y=0
        let discriminant = b.y * b.y - 4.0 * a.y * c.y;
        if (discriminant > 0.0) {
            let sqrtDisc = sqrt(discriminant);
            let invTwoA = 1.0 / (2.0 * a.y);
            t0 = (-b.y - sqrtDisc) * invTwoA;
            t1 = (-b.y + sqrtDisc) * invTwoA;
            
            // Ensure t0 <= t1
            if (t0 > t1) {
                let temp = t0;
                t0 = t1;
                t1 = temp;
            }
        }
    } else if (abs(b.y) > eps) {
        // Linear case - line crosses y=0 at t = -c.y/b.y
        let t = -c.y / b.y;
        if (t >= 0.0 && t <= 1.0) {
            // Determine which is entry vs exit based on direction
            if (b.y > 0.0) {
                t0 = -1.0; // No exit before this point
                t1 = t;    // Entry point
            } else {
                t0 = t;    // Exit point
                t1 = -1.0; // No entry after this point
            }
        }
    }
    
    var alpha = 0.0;
    
    // Process exit point (where ray exits the shape)
    if (t0 >= 0.0 && t0 <= 1.0) {
        let x = a.x * t0 * t0 + b.x * t0 + c.x;
        let coverage = clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
        alpha += coverage;
    }
    
    // Process entry point (where ray enters the shape)
    if (t1 >= 0.0 && t1 <= 1.0) {
        let x = a.x * t1 * t1 + b.x * t1 + c.x;
        let coverage = clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
        alpha -= coverage;
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
    // Check for bounding box visualizations
    if (input.bufferIndex == -1) {
        return vec4<f32>(1.0, 0.0, 0.0, 0.3); // Red text quad bounding box with transparency
    }
    if (input.bufferIndex == -2) {
        return vec4<f32>(0.0, 0.0, 1.0, 0.2); // Blue text block bounding box with transparency
    }
    
    var alpha = 0.0;
    
    // Proper fwidth approximation for WGSL
    // The reference uses: vec2 inverseDiameter = 1.0 / (antiAliasingWindowSize * fwidth(uv))
    // We need to approximate fwidth(uv) based on the font scale and pixel size
    
    // Debug: Use much simpler inverse diameter calculation to eliminate coordinate space issues
    // The horizontal lines suggest a scaling problem with the fwidth approximation
    
    // Try direct scaling based on font units to screen pixels
    // Font units are ~2000, screen scale is 0.01, so 1 font unit = 0.01 screen pixels
    // Therefore 1 screen pixel = 100 font units
    let pixelSizeInFontUnits = 100.0; // 1/0.01
    
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
