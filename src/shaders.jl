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
struct FragmentInput {
    @location(0) uv: vec2<f32>,
    @location(1) bufferIndex: i32,
}

@fragment
fn fs_main(input: FragmentInput) -> @location(0) vec4<f32> {
    // Just output a solid bright color for all fragments
    // This will show if the geometry is being rendered at all
    return vec4<f32>(1.0, 0.0, 1.0, 1.0);  // Bright magenta - very visible
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
    
    let glyph = glyphs[input.bufferIndex];
    
    // GPU font rendering algorithm following the reference implementation
    // Calculate winding number using horizontal ray from input.uv to positive x
    var winding = 0;
    
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }

        let curve = curves[curveIndex];
        
        // Transform curve control points by subtracting sample position
        // This shifts coordinate system so ray origin is at (0,0) and ray is positive x-axis
        let p0 = curve.p0 - input.uv;
        let p1 = curve.p1 - input.uv;
        let p2 = curve.p2 - input.uv;
        
        // Find intersections where quadratic Bezier curve crosses y = 0
        // Quadratic Bezier: B(t) = (1-t)²p0 + 2(1-t)t*p1 + t²p2
        // Y component: y(t) = (1-t)²p0.y + 2(1-t)t*p1.y + t²p2.y
        // Expand and rearrange to standard form: at² + bt + c = 0
        let a = p0.y - 2.0 * p1.y + p2.y;
        let b = 2.0 * (p1.y - p0.y);
        let c = p0.y;
        
        // Solve quadratic equation
        if (abs(a) < 1e-6) {
            // Linear case: bt + c = 0
            if (abs(b) > 1e-6) {
                let t = -c / b;
                if (t >= 0.0 && t <= 1.0) {
                    // Calculate x coordinate at intersection
                    let x = (1.0 - t) * (1.0 - t) * p0.x + 2.0 * (1.0 - t) * t * p1.x + t * t * p2.x;
                    // Check if intersection is on positive x-axis (x >= 0)
                    if (x >= 0.0) {
                        // Determine winding direction based on curve direction
                        let dy = 2.0 * (p1.y - p0.y) * (1.0 - t) + 2.0 * (p2.y - p1.y) * t;
                        if (dy < 0.0) {
                            winding += 1;  // Curve going down (clockwise)
                        } else {
                            winding -= 1;  // Curve going up (counterclockwise)
                        }
                    }
                }
            }
        } else {
            // Quadratic case
            let discriminant = b * b - 4.0 * a * c;
            if (discriminant >= 0.0) {
                let sqrt_discriminant = sqrt(discriminant);
                let t1 = (-b - sqrt_discriminant) / (2.0 * a);
                let t2 = (-b + sqrt_discriminant) / (2.0 * a);
                
                // Check first root
                if (t1 >= 0.0 && t1 <= 1.0) {
                    let x = (1.0 - t1) * (1.0 - t1) * p0.x + 2.0 * (1.0 - t1) * t1 * p1.x + t1 * t1 * p2.x;
                    if (x >= 0.0) {
                        let dy = 2.0 * (p1.y - p0.y) * (1.0 - t1) + 2.0 * (p2.y - p1.y) * t1;
                        if (dy < 0.0) {
                            winding += 1;
                        } else {
                            winding -= 1;
                        }
                    }
                }
                
                // Check second root
                if (t2 >= 0.0 && t2 <= 1.0) {
                    let x = (1.0 - t2) * (1.0 - t2) * p0.x + 2.0 * (1.0 - t2) * t2 * p1.x + t2 * t2 * p2.x;
                    if (x >= 0.0) {
                        let dy = 2.0 * (p1.y - p0.y) * (1.0 - t2) + 2.0 * (p2.y - p1.y) * t2;
                        if (dy < 0.0) {
                            winding += 1;
                        } else {
                            winding -= 1;
                        }
                    }
                }
            }
        }
    }
    
    // Calculate final alpha based on winding number
    if (glyph.count > 0u) {
        // Use absolute winding number for coverage - non-zero rule
        let coverage = f32(abs(winding));
        
        // Apply anti-aliasing based on the window size parameter
        // This provides smoother edges by scaling coverage
        let smoothing = uniforms.antiAliasingWindowSize;
        alpha = clamp(coverage * smoothing, 0.0, 1.0);
        
        // Return final color with calculated alpha
        return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
    } else {
        return vec4<f32>(0.0, 0.0, 0.0, 0.0);  // Transparent if no curves
    }
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
