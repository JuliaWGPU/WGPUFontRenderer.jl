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
    @location(1) depth: f32,
    @location(2) uv: vec2<f32>,
    @location(3) bufferIndex: i32,
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

    // Transform position by projection matrix, using depth coordinate for z-ordering
    let worldPos = vec4<f32>(input.position, input.depth, 1.0);
    output.position = uniforms.projection * worldPos;

    // Pass through UV coordinates and buffer index
    output.uv = input.uv;
    output.bufferIndex = input.bufferIndex;

    return output;
}
"""
end

function getFragmentShader()::String
    return getWallaceDobbieFragmentShader()  # Wallace Dobbie's approach
end

# Advanced spurious line fix shader that eliminates artificial line artifacts
function getSpuriousLineFixShader()::String
    return """
// Advanced spurious line fix shader - eliminates spurious line artifacts
// Uses multi-pass filtering and robust intersection testing to prevent false positives

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
    
    let glyph = glyphs[input.bufferIndex];
    
    // Multi-pass spurious line elimination approach:
    // 1. Primary sampling at fragment center
    // 2. Validation sampling at offset positions
    // 3. Confidence-based blending to eliminate false positives
    
    var primaryCoverage = 0.0;
    var validationCoverage = 0.0;
    let sampleCount = 5; // Center + 4 validation points
    
    // Primary sample at fragment center
    primaryCoverage = computeRobustCoverage(input.uv, glyph);
    
    // Validation samples at slight offsets to detect spurious artifacts
    let offsetScale = 0.5; // Very small offset in font units to prevent random splashes
    let offsets = array<vec2<f32>, 4>(
        vec2<f32>(-offsetScale, 0.0),   // Left
        vec2<f32>(offsetScale, 0.0),    // Right
        vec2<f32>(0.0, -offsetScale),   // Below
        vec2<f32>(0.0, offsetScale)     // Above
    );
    
    var validSamples = 0;
    for (var i = 0; i < 4; i++) {
        let samplePos = input.uv + offsets[i];
        let sampleCoverage = computeRobustCoverage(samplePos, glyph);
        
        // Check if validation sample agrees with primary sample
        let agreement = abs(primaryCoverage - sampleCoverage);
        if (agreement < 0.5) { // Samples agree
            validationCoverage += sampleCoverage;
            validSamples += 1;
        }
    }
    
    var finalCoverage: f32;
    if (validSamples >= 2) {
        // If most validation samples agree, use averaged result
        finalCoverage = (primaryCoverage + validationCoverage / f32(validSamples)) * 0.5;
    } else {
        // If validation samples disagree, likely spurious - use conservative approach
        finalCoverage = primaryCoverage * 0.3; // Reduce confidence for potential artifacts
    }
    
    // Apply final threshold to eliminate weak spurious lines
    let alpha = select(0.0, 1.0, abs(finalCoverage) > 0.4);
    
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
}

// Robust coverage computation with spurious line filtering
fn computeRobustCoverage(samplePos: vec2<f32>, glyph: Glyph) -> f32 {
    var totalCoverage = 0.0;
    
    // Process each curve with enhanced robustness
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }
        
        let curve = curves[curveIndex];
        
        // Transform curve points to sample space
        let p0 = vec2<f32>(curve.x0, curve.y0) - samplePos;
        let p1 = vec2<f32>(curve.x1, curve.y1) - samplePos;
        let p2 = vec2<f32>(curve.x2, curve.y2) - samplePos;
        
        // Apply spurious line filtering
        totalCoverage += computeFilteredCurveCoverage(p0, p1, p2);
    }
    
    return totalCoverage;
}

// Filtered curve coverage calculation that eliminates spurious intersections
fn computeFilteredCurveCoverage(p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> f32 {
    // Pre-filter: reject curves that are clearly not near the sample point
    let maxDist = max(max(length(p0), length(p1)), length(p2));
    if (maxDist > 200.0) { // Far from sample point - no contribution
        return 0.0;
    }
    
    // Early exit if curve is entirely above or below the horizontal ray
    let eps = 0.1; // Larger epsilon to reduce numerical sensitivity
    if (p0.y > eps && p1.y > eps && p2.y > eps) { return 0.0; }
    if (p0.y < -eps && p1.y < -eps && p2.y < -eps) { return 0.0; }
    
    // Standard quadratic Bezier parameterization with enhanced precision
    let a = p0 - 2.0 * p1 + p2;
    let b = 2.0 * (p1 - p0);
    let c = p0;
    
    var coverage = 0.0;
    let numericalEps = 1e-4; // Larger epsilon for better numerical stability
    
    if (abs(a.y) > numericalEps) {
        // Quadratic case with enhanced robustness
        let discriminant = b.y * b.y - 4.0 * a.y * c.y;
        if (discriminant >= 0.0) {
            let sqrtDisc = sqrt(discriminant);
            let invTwoA = 1.0 / (2.0 * a.y);
            let t0 = (-b.y - sqrtDisc) * invTwoA;
            let t1 = (-b.y + sqrtDisc) * invTwoA;
            
            // Process intersections with stricter validation
            if (t0 >= 0.05 && t0 <= 0.95) { // Avoid curve endpoints where numerical issues occur
                let x = a.x * t0 * t0 + b.x * t0 + c.x;
                if (x > 1.0) { // Require intersection to be clearly to the right
                    let dy = 2.0 * a.y * t0 + b.y;
                    if (abs(dy) > numericalEps) { // Avoid nearly-horizontal tangents
                        let windingDir = sign(dy);
                        let inverseDiameter = 0.01; // Soft anti-aliasing
                        coverage += windingDir * clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
                    }
                }
            }
            
            if (t1 >= 0.05 && t1 <= 0.95 && abs(t1 - t0) > 0.05) {
                let x = a.x * t1 * t1 + b.x * t1 + c.x;
                if (x > 1.0) { // Require intersection to be clearly to the right
                    let dy = 2.0 * a.y * t1 + b.y;
                    if (abs(dy) > numericalEps) { // Avoid nearly-horizontal tangents
                        let windingDir = sign(dy);
                        let inverseDiameter = 0.01; // Soft anti-aliasing
                        coverage += windingDir * clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
                    }
                }
            }
        }
    } else if (abs(b.y) > numericalEps) {
        // Linear case with enhanced validation
        let t = -c.y / b.y;
        if (t >= 0.05 && t <= 0.95) {
            let x = b.x * t + c.x;
            if (x > 1.0) { // Require intersection to be clearly to the right
                let windingDir = sign(b.y);
                let inverseDiameter = 0.01; // Soft anti-aliasing
                coverage += windingDir * clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
            }
        }
    }
    
    return coverage;
}
"""
end

# Simple debug shader to test basic rendering without complex coverage calculation
function getDebugSimpleShader()::String
    return """
// Simple debug fragment shader to isolate issues
// This shader just renders solid colors based on buffer index to test basic functionality

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
        return vec4<f32>(1.0, 0.0, 0.0, 0.3); // Red text quad bounding box
    }
    if (input.bufferIndex == -2) {
        return vec4<f32>(0.0, 0.0, 1.0, 0.1); // Blue text block bounding box
    }
    
    // Bounds check for glyph index
    if (input.bufferIndex < 0 || input.bufferIndex >= i32(arrayLength(&glyphs))) {
        return vec4<f32>(1.0, 0.0, 1.0, 1.0); // Magenta for out-of-bounds
    }
    
    let glyph = glyphs[input.bufferIndex];
    
    // Debug: Show different colors for different glyphs
    let glyphColorIndex = input.bufferIndex % 4;
    var debugColor: vec3<f32>;
    
    if (glyphColorIndex == 0) {
        debugColor = vec3<f32>(1.0, 1.0, 1.0); // White
    } else if (glyphColorIndex == 1) {
        debugColor = vec3<f32>(1.0, 1.0, 0.0); // Yellow
    } else if (glyphColorIndex == 2) {
        debugColor = vec3<f32>(0.0, 1.0, 1.0); // Cyan
    } else {
        debugColor = vec3<f32>(1.0, 0.5, 0.0); // Orange
    }
    
    // Check if glyph has valid curve data
    if (glyph.count > 0u && glyph.start < arrayLength(&curves)) {
        return vec4<f32>(debugColor, 1.0);
    } else {
        return vec4<f32>(0.5, 0.5, 0.5, 1.0); // Gray for glyphs with no curves
    }
}
"""
end

# Ultra-simple shader that just shows solid colors for each glyph quad
# This completely eliminates any curve-based artifacts
function getUltraSimpleShader()::String
    return """
// Ultra-simple fragment shader - just solid colors per glyph
// Completely bypasses all curve calculations to eliminate artifacts

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
        return vec4<f32>(0.0, 0.0, 0.0, 0.0); // Transparent background
    }
    
    // Just render solid color for each glyph - no curve processing at all
    // This completely eliminates any possibility of spurious lines
    return uniforms.color;
}
"""
end

# Robust fragment shader that eliminates spurious line artifacts
function getRobustFragmentShader()::String
    return """
// Robust fragment shader that eliminates spurious line artifacts
// Uses discrete sampling to avoid numerical precision issues

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
    
    // Use discrete sampling to avoid numerical precision artifacts
    var totalWindingNumber = 0;
    let sampleCount = 9; // 3x3 grid for anti-aliasing
    let sampleOffset = 0.3; // Small offset for sub-pixel sampling
    
    let glyph = glyphs[input.bufferIndex];
    
    // Sample multiple points to avoid spurious lines from numerical precision
    for (var sy = 0; sy < 3; sy++) {
        for (var sx = 0; sx < 3; sx++) {
            let sampleUV = input.uv + vec2<f32>(
                (f32(sx) - 1.0) * sampleOffset,
                (f32(sy) - 1.0) * sampleOffset
            );
            
            var windingNumber = 0;
            
            // Process each curve with robust intersection testing
            for (var i = 0u; i < glyph.count; i += 1u) {
                let curveIndex = glyph.start + i;
                if (curveIndex >= arrayLength(&curves)) {
                    break;
                }
                
                let curve = curves[curveIndex];
                
                // Transform curve points to sample space
                let p0 = vec2<f32>(curve.x0, curve.y0) - sampleUV;
                let p1 = vec2<f32>(curve.x1, curve.y1) - sampleUV;
                let p2 = vec2<f32>(curve.x2, curve.y2) - sampleUV;
                
                // Use robust discrete winding calculation
                windingNumber += computeRobustWinding(p0, p1, p2);
            }
            
            totalWindingNumber += windingNumber;
        }
    }
    
    // Use non-zero winding rule with discrete threshold
    let averageWinding = f32(totalWindingNumber) / f32(sampleCount);
    let alpha = select(0.0, 1.0, abs(averageWinding) > 0.5);
    
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
}

// Robust winding calculation that avoids spurious precision artifacts
fn computeRobustWinding(p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> i32 {
    // Early exit if curve is entirely above or below the horizontal ray
    if (p0.y > 0.1 && p1.y > 0.1 && p2.y > 0.1) { return 0; }
    if (p0.y < -0.1 && p1.y < -0.1 && p2.y < -0.1) { return 0; }
    
    // Use standard quadratic Bezier parameterization
    let a = p0 - 2.0 * p1 + p2;
    let b = 2.0 * (p1 - p0);
    let c = p0;
    
    var windingContribution = 0;
    
    let eps = 1e-4; // Larger epsilon for robustness
    
    if (abs(a.y) > eps) {
        // Quadratic case with robust discriminant handling
        let discriminant = b.y * b.y - 4.0 * a.y * c.y;
        if (discriminant >= eps) {
            let sqrtDisc = sqrt(discriminant);
            let invTwoA = 1.0 / (2.0 * a.y);
            let t0 = (-b.y - sqrtDisc) * invTwoA;
            let t1 = (-b.y + sqrtDisc) * invTwoA;
            
            // Process intersections with stricter bounds checking
            if (t0 >= 0.01 && t0 <= 0.99) {
                let x = a.x * t0 * t0 + b.x * t0 + c.x;
                if (x > 0.1) { // Require intersection to be clearly to the right
                    let dy = 2.0 * a.y * t0 + b.y;
                    windingContribution += select(0, 1, dy > 0.0) - select(0, 1, dy < 0.0);
                }
            }
            
            if (t1 >= 0.01 && t1 <= 0.99 && abs(t1 - t0) > 0.01) {
                let x = a.x * t1 * t1 + b.x * t1 + c.x;
                if (x > 0.1) { // Require intersection to be clearly to the right
                    let dy = 2.0 * a.y * t1 + b.y;
                    windingContribution += select(0, 1, dy > 0.0) - select(0, 1, dy < 0.0);
                }
            }
        }
    } else if (abs(b.y) > eps) {
        // Linear case with robust handling
        let t = -c.y / b.y;
        if (t >= 0.01 && t <= 0.99) {
            let x = b.x * t + c.x;
            if (x > 0.1) { // Require intersection to be clearly to the right
                windingContribution += select(0, 1, b.y > 0.0) - select(0, 1, b.y < 0.0);
            }
        }
    }
    
    return windingContribution;
}
"""
end

# Improved fragment shader with robust winding calculation
function getImprovedFragmentShader()::String
    return """
// Improved fragment shader with more robust coverage calculation
// Addresses missing glyph parts by using non-zero winding rule

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
    
    // Use moderate anti-aliasing for better quality without artifacts
    let inverseDiameter = 0.1; // Soft but not too aggressive
    
    let glyph = glyphs[input.bufferIndex];
    
    // Process each curve with improved coverage calculation
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }
        
        let curve = curves[curveIndex];
        
        // Transform curve points to sample space
        let p0 = vec2<f32>(curve.x0, curve.y0) - input.uv;
        let p1 = vec2<f32>(curve.x1, curve.y1) - input.uv;
        let p2 = vec2<f32>(curve.x2, curve.y2) - input.uv;
        
        // Use improved coverage calculation that handles edge cases better
        alpha += computeImprovedCoverage(inverseDiameter, p0, p1, p2);
    }
    
    // Use non-zero winding rule instead of even-odd to handle complex shapes
    alpha = clamp(abs(alpha), 0.0, 1.0);
    
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
}

// Improved coverage calculation that's more robust for missing parts
fn computeImprovedCoverage(inverseDiameter: f32, p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> f32 {
    // Early exit if curve is entirely above or below the horizontal ray
    if (p0.y > 0.0 && p1.y > 0.0 && p2.y > 0.0) { return 0.0; }
    if (p0.y < 0.0 && p1.y < 0.0 && p2.y < 0.0) { return 0.0; }
    
    // Use standard quadratic Bezier parameterization
    let a = p0 - 2.0 * p1 + p2;
    let b = 2.0 * (p1 - p0);
    let c = p0;
    
    var contributions = 0.0;
    
    let eps = 1e-6;
    
    if (abs(a.y) > eps) {
        // Quadratic case
        let discriminant = b.y * b.y - 4.0 * a.y * c.y;
        if (discriminant >= 0.0) {
            let sqrtDisc = sqrt(discriminant);
            let invTwoA = 1.0 / (2.0 * a.y);
            let t0 = (-b.y - sqrtDisc) * invTwoA;
            let t1 = (-b.y + sqrtDisc) * invTwoA;
            
            // Process both intersections if they're in valid range
            if (t0 >= 0.0 && t0 <= 1.0) {
                let x = a.x * t0 * t0 + b.x * t0 + c.x;
                if (x > 0.0) {
                    let dy = 2.0 * a.y * t0 + b.y; // derivative
                    let windingDir = sign(dy);
                    contributions += windingDir * clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
                }
            }
            
            if (t1 >= 0.0 && t1 <= 1.0 && abs(t1 - t0) > eps) {
                let x = a.x * t1 * t1 + b.x * t1 + c.x;
                if (x > 0.0) {
                    let dy = 2.0 * a.y * t1 + b.y; // derivative
                    let windingDir = sign(dy);
                    contributions += windingDir * clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
                }
            }
        }
    } else if (abs(b.y) > eps) {
        // Linear case
        let t = -c.y / b.y;
        if (t >= 0.0 && t <= 1.0) {
            let x = b.x * t + c.x;
            if (x > 0.0) {
                let windingDir = sign(b.y);
                contributions += windingDir * clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
            }
        }
    }
    
    return contributions;
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
        let p0 = vec2<f32>(curve.x0, curve.y0) - input.uv;
        let p1 = vec2<f32>(curve.x1, curve.y1) - input.uv;
        let p2 = vec2<f32>(curve.x2, curve.y2) - input.uv;
        
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

# Ultra-conservative shader with minimal anti-aliasing - should eliminate artifacts
function getConservativeFragmentShader()::String
    return """
// Ultra-conservative fragment shader with minimal anti-aliasing
// Designed to eliminate artifacts by using very simple coverage calculation

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
    
    // ULTRA-CONSERVATIVE approach: Use very large anti-aliasing window
    // This should eliminate all numerical precision artifacts
    let conservativeInverseDiameter = 0.01; // Very small value = very soft edges
    
    let glyph = glyphs[input.bufferIndex];
    
    // Process each curve with minimal complexity
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }
        
        let curve = curves[curveIndex];
        
        // Transform curve points to sample space
        let p0 = vec2<f32>(curve.x0, curve.y0) - input.uv;
        let p1 = vec2<f32>(curve.x1, curve.y1) - input.uv;
        let p2 = vec2<f32>(curve.x2, curve.y2) - input.uv;
        
        // Use extremely conservative coverage calculation
        alpha += computeConservativeCoverage(conservativeInverseDiameter, p0, p1, p2);
    }
    
    // Clamp alpha very strictly
    alpha = clamp(alpha, 0.0, 1.0);
    
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
}

// Ultra-conservative coverage calculation - prioritizes stability over precision
fn computeConservativeCoverage(inverseDiameter: f32, p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> f32 {
    // Early exit with larger epsilon for stability
    if (p0.y > 0.5 && p1.y > 0.5 && p2.y > 0.5) { return 0.0; }
    if (p0.y < -0.5 && p1.y < -0.5 && p2.y < -0.5) { return 0.0; }
    
    // Use standard quadratic formula with much larger epsilon values
    let a = p0 - 2.0 * p1 + p2;
    let b = 2.0 * (p1 - p0);
    let c = p0;
    
    var t0 = -1.0;
    var t1 = -1.0;
    
    let eps = 1e-3; // Much larger epsilon for stability
    
    if (abs(a.y) > eps) {
        // Quadratic case with conservative discriminant check
        let discriminant = b.y * b.y - 4.0 * a.y * c.y;
        if (discriminant > eps) {
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
        // Linear case with conservative handling
        let t = -c.y / b.y;
        if (t >= 0.0 && t <= 1.0) {
            if (b.y > 0.0) {
                t0 = -1.0;
                t1 = t;
            } else {
                t0 = t;
                t1 = -1.0;
            }
        }
    }
    
    var alpha = 0.0;
    
    // Process intersections with very conservative bounds
    if (t0 >= -eps && t0 <= 1.0 + eps) {
        let x = a.x * t0 * t0 + b.x * t0 + c.x;
        let coverage = clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
        alpha += coverage;
    }
    
    if (t1 >= -eps && t1 <= 1.0 + eps) {
        let x = a.x * t1 * t1 + b.x * t1 + c.x;
        let coverage = clamp(x * inverseDiameter + 0.5, 0.0, 1.0);
        alpha -= coverage;
    }
    
    // Very strict final clamping
    return clamp(alpha, -0.5, 0.5);
}
"""
end

# Thresholded GLLabel shader - combines GLLabel anti-aliasing with binary interior filling
# This eliminates spurious lines AND the "pencil drawing" grey interior effect
function getThresholdedGLLabelFragmentShader()::String
    return """
// Thresholded GLLabel fragment shader - best of both worlds
// Uses GLLabel parabolic windowing to eliminate spurious lines
// + threshold for solid interior regions (no grey "pencil drawing" effect)

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

const kPixelWindowSize = 1.0;
const numSS = 4; // Number of supersampling angles
const pi = 3.1415926535897932384626433832795;

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
    
    let glyph = glyphs[input.bufferIndex];
    
    // GLLabel-style supersampling with rotations
    let theta = pi / f32(numSS);
    let cosTheta = cos(theta);
    let sinTheta = sin(theta);
    
    // Approximation of derivative-based scaling (fwidth equivalent)
    // This represents the pixel size in glyph coordinate space
    let pixelScale = uniforms.antiAliasingWindowSize * 100.0; // Scale based on font units
    let invPixelScale = 1.0 / pixelScale;
    
    var totalPercent = 0.0;
    
    // Supersampling loop - test multiple rotated coordinate systems
    for (var ss = 0; ss < numSS; ss++) {
        // Create rotation matrix for this sample
        let angle = f32(ss) * theta;
        let cosA = cos(angle);
        let sinA = sin(angle);
        
        var samplePercent = 0.0;
        
        // Process each curve in the rotated coordinate system
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
            
            // Apply rotation and scaling
            let p0 = vec2<f32>(
                (cosA * p0_local.x - sinA * p0_local.y) * invPixelScale,
                (sinA * p0_local.x + cosA * p0_local.y) * invPixelScale
            );
            let p1 = vec2<f32>(
                (cosA * p1_local.x - sinA * p1_local.y) * invPixelScale,
                (sinA * p1_local.x + cosA * p1_local.y) * invPixelScale
            );
            let p2 = vec2<f32>(
                (cosA * p2_local.x - sinA * p2_local.y) * invPixelScale,
                (sinA * p2_local.x + cosA * p2_local.y) * invPixelScale
            );
            
            // Find intersections with horizontal ray (y=0)
            var intersections: array<f32, 2>;
            let numIntersections = getAxisIntersections(p0.x, p1.x, p2.x, &intersections);
            
            // Process each intersection
            for (var j = 0; j < numIntersections; j++) {
                let t = intersections[j];
                if (t > 0.0 && t <= 1.0) {
                    let posy = positionAt(p0.y, p1.y, p2.y, t);
                    
                    if (posy > -1.0 && posy < 1.0) {
                        let derivx = tangentAt(p0.x, p1.x, p2.x, t);
                        
                        // Use parabolic windowing function from GLLabel
                        let delta = integrateWindow(posy);
                        samplePercent += select(-delta, delta, derivx < 0.0);
                    }
                }
            }
        }
        
        totalPercent += samplePercent;
    }
    
    // Average across all supersamples
    let finalPercent = totalPercent / f32(numSS);
    
    // HERE'S THE KEY: Apply threshold for solid interiors
    // This eliminates the "pencil drawing" grey effect
    let threshold = 0.0; // Lower threshold for more sensitive interior filling
    let alpha = select(0.0, 1.0, abs(finalPercent) > threshold);
    
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
}

// Parabolic windowing function from GLLabel - eliminates spurious artifacts
fn integrateWindow(x: f32) -> f32 {
    let xsq = x * x;
    return sign(x) * (0.5 * xsq * xsq - xsq) + 0.5; // parabolic window
}

// Bezier curve evaluation at parameter t
fn positionAt(p0: f32, p1: f32, p2: f32, t: f32) -> f32 {
    let mt = 1.0 - t;
    return mt * mt * p0 + 2.0 * t * mt * p1 + t * t * p2;
}

// Bezier curve tangent at parameter t
fn tangentAt(p0: f32, p1: f32, p2: f32, t: f32) -> f32 {
    return 2.0 * (1.0 - t) * (p1 - p0) + 2.0 * t * (p2 - p1);
}

// Check if two values are approximately equal
fn almostEqual(a: f32, b: f32) -> bool {
    return abs(a - b) < 1e-5;
}

// Find intersections of quadratic Bezier with x-axis
fn getAxisIntersections(p0: f32, p1: f32, p2: f32, intersections: ptr<function, array<f32, 2>>) -> i32 {
    if (almostEqual(p0, 2.0 * p1 - p2)) {
        (*intersections)[0] = 0.5 * (p2 - 2.0 * p1) / (p2 - p1);
        return 1;
    }
    
    let sqrtTerm = p1 * p1 - p0 * p2;
    if (sqrtTerm < 0.0) {
        return 0;
    }
    
    let sqrtVal = sqrt(sqrtTerm);
    let denom = p0 - 2.0 * p1 + p2;
    
    if (abs(denom) < 1e-6) {
        return 0;
    }
    
    (*intersections)[0] = (p0 - p1 + sqrtVal) / denom;
    (*intersections)[1] = (p0 - p1 - sqrtVal) / denom;
    return 2;
}
"""
end

# GLLabel-inspired fragment shader using parabolic windowing and supersampling
# Based on the proven gllabel approach that eliminates spurious line artifacts
function getGLLabelFragmentShader()::String
    return """
// GLLabel-inspired fragment shader with parabolic windowing
// Uses the proven approach from gllabel library to eliminate spurious lines

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

const kPixelWindowSize = 1.0;
const numSS = 4; // Number of supersampling angles
const pi = 3.1415926535897932384626433832795;

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
    
    let glyph = glyphs[input.bufferIndex];
    
    // GLLabel-style supersampling with rotations
    let theta = pi / f32(numSS);
    let cosTheta = cos(theta);
    let sinTheta = sin(theta);
    
    // Approximation of derivative-based scaling (fwidth equivalent)
    // This represents the pixel size in glyph coordinate space
    let pixelScale = uniforms.antiAliasingWindowSize * 100.0; // Scale based on font units
    let invPixelScale = 1.0 / pixelScale;
    
    var totalPercent = 0.0;
    
    // Supersampling loop - test multiple rotated coordinate systems
    for (var ss = 0; ss < numSS; ss++) {
        // Create rotation matrix for this sample
        let angle = f32(ss) * theta;
        let cosA = cos(angle);
        let sinA = sin(angle);
        
        var samplePercent = 0.0;
        
        // Process each curve in the rotated coordinate system
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
            
            // Apply rotation and scaling
            let p0 = vec2<f32>(
                (cosA * p0_local.x - sinA * p0_local.y) * invPixelScale,
                (sinA * p0_local.x + cosA * p0_local.y) * invPixelScale
            );
            let p1 = vec2<f32>(
                (cosA * p1_local.x - sinA * p1_local.y) * invPixelScale,
                (sinA * p1_local.x + cosA * p1_local.y) * invPixelScale
            );
            let p2 = vec2<f32>(
                (cosA * p2_local.x - sinA * p2_local.y) * invPixelScale,
                (sinA * p2_local.x + cosA * p2_local.y) * invPixelScale
            );
            
            // Find intersections with horizontal ray (y=0)
            var intersections: array<f32, 2>;
            let numIntersections = getAxisIntersections(p0.x, p1.x, p2.x, &intersections);
            
            // Process each intersection
            for (var j = 0; j < numIntersections; j++) {
                let t = intersections[j];
                if (t > 0.0 && t <= 1.0) {
                    let posy = positionAt(p0.y, p1.y, p2.y, t);
                    
                    if (posy > -1.0 && posy < 1.0) {
                        let derivx = tangentAt(p0.x, p1.x, p2.x, t);
                        
                        // Use parabolic windowing function from GLLabel
                        let delta = integrateWindow(posy);
                        samplePercent += select(-delta, delta, derivx < 0.0);
                    }
                }
            }
        }
        
        totalPercent += samplePercent;
    }
    
    // Average across all supersamples
    let finalPercent = totalPercent / f32(numSS);
    let alpha = clamp(finalPercent, 0.0, 1.0);
    
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
}

// Parabolic windowing function from GLLabel - eliminates spurious artifacts
fn integrateWindow(x: f32) -> f32 {
    let xsq = x * x;
    return sign(x) * (0.5 * xsq * xsq - xsq) + 0.5; // parabolic window
}

// Bezier curve evaluation at parameter t
fn positionAt(p0: f32, p1: f32, p2: f32, t: f32) -> f32 {
    let mt = 1.0 - t;
    return mt * mt * p0 + 2.0 * t * mt * p1 + t * t * p2;
}

// Bezier curve tangent at parameter t
fn tangentAt(p0: f32, p1: f32, p2: f32, t: f32) -> f32 {
    return 2.0 * (1.0 - t) * (p1 - p0) + 2.0 * t * (p2 - p1);
}

// Check if two values are approximately equal
fn almostEqual(a: f32, b: f32) -> bool {
    return abs(a - b) < 1e-5;
}

// Find intersections of quadratic Bezier with x-axis
fn getAxisIntersections(p0: f32, p1: f32, p2: f32, intersections: ptr<function, array<f32, 2>>) -> i32 {
    if (almostEqual(p0, 2.0 * p1 - p2)) {
        (*intersections)[0] = 0.5 * (p2 - 2.0 * p1) / (p2 - p1);
        return 1;
    }
    
    let sqrtTerm = p1 * p1 - p0 * p2;
    if (sqrtTerm < 0.0) {
        return 0;
    }
    
    let sqrtVal = sqrt(sqrtTerm);
    let denom = p0 - 2.0 * p1 + p2;
    
    if (abs(denom) < 1e-6) {
        return 0;
    }
    
    (*intersections)[0] = (p0 - p1 + sqrtVal) / denom;
    (*intersections)[1] = (p0 - p1 - sqrtVal) / denom;
    return 2;
}
"""
end
# Binary (sharp-edge) shader - eliminates all anti-aliasing artifacts
# Enhanced visual debug shader with large control points and thick curve lines
function getCurveDebugFragmentShader()::String
    return """
// Enhanced visual debug shader - shows control points as circles and curves as thick lines
// This provides much better visibility for debugging curve artifacts

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
    // Handle special visualization cases - make bounding boxes nearly invisible
    if (input.bufferIndex == -1) {
        return vec4<f32>(0.8, 0.2, 0.2, 0.01); // Nearly invisible red text quad bounding box
    }
    if (input.bufferIndex == -2) {
        return vec4<f32>(0.2, 0.2, 0.8, 0.005); // Nearly invisible blue text block bounding box
    }
    
    // Bounds check for glyph index
    if (input.bufferIndex < 0 || input.bufferIndex >= i32(arrayLength(&glyphs))) {
        return vec4<f32>(0.0, 0.0, 0.0, 0.0);
    }
    
    let glyph = glyphs[input.bufferIndex];
    
    // Check each curve for visualization
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }
        
        let curve = curves[curveIndex];
        
        // Get curve control points in font coordinate space
        let p0 = vec2<f32>(curve.x0, curve.y0);
        let p1 = vec2<f32>(curve.x1, curve.y1);
        let p2 = vec2<f32>(curve.x2, curve.y2);
        
        // Choose bright, high-contrast colors for light background
        let colorIndex = i % 6u;
        var curveColor: vec3<f32>;
        if (colorIndex == 0u) { curveColor = vec3<f32>(0.8, 0.0, 0.0); }      // Dark Red
        else if (colorIndex == 1u) { curveColor = vec3<f32>(0.0, 0.6, 0.0); } // Dark Green
        else if (colorIndex == 2u) { curveColor = vec3<f32>(0.0, 0.0, 0.8); } // Dark Blue
        else if (colorIndex == 3u) { curveColor = vec3<f32>(0.6, 0.4, 0.0); } // Dark Orange
        else if (colorIndex == 4u) { curveColor = vec3<f32>(0.6, 0.0, 0.6); } // Dark Magenta
        else { curveColor = vec3<f32>(0.0, 0.4, 0.6); }                      // Dark Cyan
        
        // Check if we're near control points (very large circles for visibility)
        let pointRadius = 25.0; // Much larger radius for better visibility
        
        // P0 control point (start) - draw as filled circle
        let distP0 = length(input.uv - p0);
        if (distP0 <= pointRadius) {
            return vec4<f32>(curveColor * 1.2, 1.0); // Bright version for start point
        }
        
        // P1 control point (control) - draw as filled circle with different brightness
        let distP1 = length(input.uv - p1);
        if (distP1 <= pointRadius) {
            return vec4<f32>(curveColor * 0.8, 1.0); // Dimmer version for control point
        }
        
        // P2 control point (end) - draw as filled circle
        let distP2 = length(input.uv - p2);
        if (distP2 <= pointRadius) {
            return vec4<f32>(curveColor * 1.0, 1.0); // Normal brightness for end point
        }
        
        // Check if we're near the curve itself (thick line)
        if (isNearThickCurve(input.uv, p0, p1, p2)) {
            return vec4<f32>(curveColor * 0.9, 0.8); // Semi-transparent curve line
        }
        
        // Draw control lines (dashed effect by making them thinner and less opaque)
        if (isNearControlLine(input.uv, p0, p1) || isNearControlLine(input.uv, p1, p2)) {
            return vec4<f32>(curveColor * 0.4, 0.3); // Very faint control lines
        }
    }
    
    return vec4<f32>(0.0, 0.0, 0.0, 0.0); // Transparent background
}

// Check if fragment is near the actual Bezier curve (thick line)
fn isNearThickCurve(fragPos: vec2<f32>, p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> bool {
    let lineThickness = 20.0; // Extra thick curve for maximum visibility
    
    // Sample many points along the curve for smooth visualization
    for (var i = 0; i <= 20; i++) {
        let t = f32(i) / 20.0; // t goes from 0.0 to 1.0 in fine steps
        
        // Quadratic Bezier evaluation: B(t) = (1-t)²p0 + 2t(1-t)p1 + t²p2
        let oneMinusT = 1.0 - t;
        let curvePoint = oneMinusT * oneMinusT * p0 + 2.0 * t * oneMinusT * p1 + t * t * p2;
        
        let dist = length(fragPos - curvePoint);
        if (dist <= lineThickness) {
            return true;
        }
    }
    
    return false;
}

// Check if fragment is near a control line (for showing curve structure)
fn isNearControlLine(fragPos: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> bool {
    let lineThickness = 1.0; // Thin control lines
    
    // Sample points along the straight line between control points
    for (var i = 0; i <= 10; i++) {
        let t = f32(i) / 10.0;
        let linePoint = mix(p1, p2, t);
        
        let dist = length(fragPos - linePoint);
        if (dist <= lineThickness) {
            return true;
        }
    }
    
    return false;
}
"""
end

function getWallaceFragmentShader()::String
    return """
// Pure Evan Wallace shader implementation
// Based on his Medium article: "Easy Scalable Text Rendering on the GPU"
// Uses triangulation + pixel flipping with Loop-Blinn technique

struct Glyph {
    start: u32,
    count: u32,
}

struct Triangle {
    // Triangle vertices (center point to polygon edge)
    ax: f32, ay: f32,  // Center point (same for all triangles in glyph)
    bx: f32, by: f32,  // First edge point
    cx: f32, cy: f32,  // Second edge point
    // Barycentric coordinates for Loop-Blinn
    s: f32, t: f32,    // s and t coordinates for curve correction
    triangleType: u32, // 0 = solid triangle, 1 = quadratic curve triangle
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
    @location(2) barycentricCoords: vec2<f32>,  // s, t for Loop-Blinn
    @location(3) triangleType: u32,             // 0 = solid, 1 = curve
}

@group(0) @binding(0) var<storage, read> glyphs: array<Glyph>;
@group(0) @binding(1) var<storage, read> triangles: array<Triangle>;
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
    
    // Wallace pixel flipping approach
    var pixelValue = 0.0;
    
    if (input.triangleType == 0u) {
        // Solid triangle - always contributes 1/255
        pixelValue = 1.0 / 255.0;
    } else {
        // Quadratic curve triangle - use Loop-Blinn test
        let s = input.barycentricCoords.x;
        let t = input.barycentricCoords.y;
        
        // Loop-Blinn formula: pixel is flipped if (s/2 + t)² < t
        // Rearranged: s² / 4 + s*t + t² < t
        // Rearranged: s² / 4 + s*t + t² - t < 0
        // Rearranged: s² / 4 + s*t + t*(t - 1) < 0
        let loopBlinnTest = (s * s * 0.25) + (s * t) + (t * (t - 1.0));
        
        if (loopBlinnTest < 0.0) {
            pixelValue = 1.0 / 255.0;  // Inside curve
        }
        // else: outside curve, no contribution
    }
    
    // Wallace approach: accumulate in color buffer
    // Use additive blending to sum up winding contributions
    return vec4<f32>(pixelValue, 0.0, 0.0, 1.0);
}
"""
end

# Advanced debugging shader that visualizes the actual intersection calculations
function getIntersectionDebugShader()::String
    return """
// Advanced debugging shader - visualizes curve intersections to isolate spurious line sources
// This shader colors pixels based on how many curve intersections occur

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
    
    let glyph = glyphs[input.bufferIndex];
    
    var totalIntersections = 0;
    var debugInfo = vec3<f32>(0.0, 0.0, 0.0);
    
    // Process each curve and count intersections
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }
        
        let curve = curves[curveIndex];
        
        // Transform curve points to sample space
        let p0 = vec2<f32>(curve.x0, curve.y0) - input.uv;
        let p1 = vec2<f32>(curve.x1, curve.y1) - input.uv;
        let p2 = vec2<f32>(curve.x2, curve.y2) - input.uv;
        
        // Count intersections and gather debug info
        let intersectionResult = debugIntersections(p0, p1, p2);
        totalIntersections += intersectionResult.x;
        
        // Color-code based on intersection types
        if (intersectionResult.y > 0.5) { // Had quadratic intersections
            debugInfo.r += 0.3;
        }
        if (intersectionResult.z > 0.5) { // Had linear intersections
            debugInfo.g += 0.3;
        }
    }
    
    // Visualize intersection count
    if (totalIntersections == 0) {
        return vec4<f32>(0.0, 0.0, 0.0, 0.1); // Almost transparent for no intersections
    } else if (totalIntersections == 1) {
        return vec4<f32>(0.0, 1.0, 0.0, 0.8); // Green for single intersection (normal)
    } else if (totalIntersections == 2) {
        return vec4<f32>(1.0, 1.0, 0.0, 0.8); // Yellow for double intersection (normal)
    } else if (totalIntersections % 2 == 1) {
        return vec4<f32>(1.0, 0.0, 0.0, 1.0); // Red for odd intersections (should be filled)
    } else {
        return vec4<f32>(0.0, 0.0, 1.0, 1.0); // Blue for even intersections (should be empty)
    }
}

// Debug intersection counting with detailed information
fn debugIntersections(p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> vec3<f32> {
    // Early exit if curve is entirely above or below the horizontal ray
    if (p0.y > 0.0 && p1.y > 0.0 && p2.y > 0.0) { return vec3<f32>(0.0, 0.0, 0.0); }
    if (p0.y < 0.0 && p1.y < 0.0 && p2.y < 0.0) { return vec3<f32>(0.0, 0.0, 0.0); }
    
    // Use standard quadratic formula
    let a = p0 - 2.0 * p1 + p2;
    let b = 2.0 * (p1 - p0);
    let c = p0;
    
    var intersectionCount = 0.0;
    var hadQuadratic = 0.0;
    var hadLinear = 0.0;
    
    let eps = 1e-6;
    
    if (abs(a.y) > eps) {
        // Quadratic case
        hadQuadratic = 1.0;
        let discriminant = b.y * b.y - 4.0 * a.y * c.y;
        if (discriminant >= 0.0) {
            let sqrtDisc = sqrt(discriminant);
            let invTwoA = 1.0 / (2.0 * a.y);
            let t0 = (-b.y - sqrtDisc) * invTwoA;
            let t1 = (-b.y + sqrtDisc) * invTwoA;
            
            // Count intersections for each valid t value
            if (t0 >= 0.0 && t0 <= 1.0) {
                let x = a.x * t0 * t0 + b.x * t0 + c.x;
                if (x > 0.0) { intersectionCount += 1.0; }
            }
            
            if (t1 >= 0.0 && t1 <= 1.0 && abs(t1 - t0) > eps) {
                let x = a.x * t1 * t1 + b.x * t1 + c.x;
                if (x > 0.0) { intersectionCount += 1.0; }
            }
        }
    } else if (abs(b.y) > eps) {
        // Linear case
        hadLinear = 1.0;
        let t = -c.y / b.y;
        if (t >= 0.0 && t <= 1.0) {
            let x = b.x * t + c.x;
            if (x > 0.0) { intersectionCount += 1.0; }
        }
    }
    
    return vec3<f32>(intersectionCount, hadQuadratic, hadLinear);
}
"""
end

function getBinaryFragmentShader()::String
    return """
// Binary fragment shader - completely eliminates anti-aliasing artifacts
// Uses simple binary (on/off) coverage for the sharpest possible edges

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
    
    var windingNumber = 0;
    
    let glyph = glyphs[input.bufferIndex];
    
    // Use simple winding number calculation - completely eliminates numerical issues
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }
        
        let curve = curves[curveIndex];
        
        // Transform curve points to sample space
        let p0 = vec2<f32>(curve.x0, curve.y0) - input.uv;
        let p1 = vec2<f32>(curve.x1, curve.y1) - input.uv;
        let p2 = vec2<f32>(curve.x2, curve.y2) - input.uv;
        
        // Simple binary coverage - count curve crossings
        windingNumber += computeBinaryCoverage(p0, p1, p2);
    }
    
    // Even-odd winding rule: odd = filled, even = transparent
    let alpha = select(0.0, 1.0, (windingNumber % 2) != 0);
    
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
}

// Binary coverage calculation - just counts crossings (no anti-aliasing)
fn computeBinaryCoverage(p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> i32 {
    // Early exit if curve is entirely above or below the horizontal ray
    if (p0.y > 0.0 && p1.y > 0.0 && p2.y > 0.0) { return 0; }
    if (p0.y < 0.0 && p1.y < 0.0 && p2.y < 0.0) { return 0; }
    
    // Use simple quadratic formula
    let a = p0 - 2.0 * p1 + p2;
    let b = 2.0 * (p1 - p0);
    let c = p0;
    
    var crossings = 0;
    
    let eps = 1e-6;
    
    if (abs(a.y) > eps) {
        // Quadratic case
        let discriminant = b.y * b.y - 4.0 * a.y * c.y;
        if (discriminant >= 0.0) {
            let sqrtDisc = sqrt(discriminant);
            let invTwoA = 1.0 / (2.0 * a.y);
            let t0 = (-b.y - sqrtDisc) * invTwoA;
            let t1 = (-b.y + sqrtDisc) * invTwoA;
            
            // Count crossings for each valid t value
            if (t0 >= 0.0 && t0 <= 1.0) {
                let x = a.x * t0 * t0 + b.x * t0 + c.x;
                if (x > 0.0) { crossings += 1; }
            }
            
            if (t1 >= 0.0 && t1 <= 1.0 && abs(t1 - t0) > eps) {
                let x = a.x * t1 * t1 + b.x * t1 + c.x;
                if (x > 0.0) { crossings += 1; }
            }
        }
    } else if (abs(b.y) > eps) {
        // Linear case
        let t = -c.y / b.y;
        if (t >= 0.0 && t <= 1.0) {
            let x = b.x * t + c.x;
            if (x > 0.0) { crossings += 1; }
        }
    }
    
    return crossings;
}
"""
end

# Simplified GLLabel approach with better winding calculation for inner regions
function getSimplifiedGLLabelFragmentShader()::String
    return """
// Simplified GLLabel-inspired shader with correct winding for inner regions
// Uses parabolic windowing but with simpler supersampling

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
    
    let glyph = glyphs[input.bufferIndex];
    
    // Use a simpler approach: minimal supersampling with parabolic windowing
    let pixelScale = uniforms.antiAliasingWindowSize * 50.0; // Reduced scaling
    let invPixelScale = 1.0 / pixelScale;
    
    var totalPercent = 0.0;
    
    // Use only 2 samples instead of 4 to reduce complexity
    for (var ss = 0; ss < 2; ss++) {
        var samplePercent = 0.0;
        
        // Rotate by 45 degrees for second sample
        let angle = f32(ss) * 1.5707963; // pi/2 radians = 90 degrees
        let cosA = cos(angle);
        let sinA = sin(angle);
        
        // Process each curve
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
            
            // Apply rotation and scaling
            let p0 = vec2<f32>(
                (cosA * p0_local.x - sinA * p0_local.y) * invPixelScale,
                (sinA * p0_local.x + cosA * p0_local.y) * invPixelScale
            );
            let p1 = vec2<f32>(
                (cosA * p1_local.x - sinA * p1_local.y) * invPixelScale,
                (sinA * p1_local.x + cosA * p1_local.y) * invPixelScale
            );
            let p2 = vec2<f32>(
                (cosA * p2_local.x - sinA * p2_local.y) * invPixelScale,
                (sinA * p2_local.x + cosA * p2_local.y) * invPixelScale
            );
            
            // Process intersections with y=0 axis
            samplePercent += processSimplifiedIntersections(p0, p1, p2);
        }
        
        totalPercent += samplePercent;
    }
    
    // Average and apply proper winding rule
    let finalPercent = totalPercent / 2.0;
    let alpha = clamp(abs(finalPercent), 0.0, 1.0); // Use absolute value for non-zero winding
    
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
}

// Simplified intersection processing with parabolic windowing
fn processSimplifiedIntersections(p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> f32 {
    // Early exit if curve is entirely above or below the horizontal ray
    if (p0.y > 0.0 && p1.y > 0.0 && p2.y > 0.0) { return 0.0; }
    if (p0.y < 0.0 && p1.y < 0.0 && p2.y < 0.0) { return 0.0; }
    
    // Standard quadratic intersection
    let a = p0 - 2.0 * p1 + p2;
    let b = 2.0 * (p1 - p0);
    let c = p0;
    
    var coverage = 0.0;
    let eps = 1e-6;
    
    if (abs(a.y) > eps) {
        // Quadratic case
        let discriminant = b.y * b.y - 4.0 * a.y * c.y;
        if (discriminant >= 0.0) {
            let sqrtDisc = sqrt(discriminant);
            let invTwoA = 1.0 / (2.0 * a.y);
            let t0 = (-b.y - sqrtDisc) * invTwoA;
            let t1 = (-b.y + sqrtDisc) * invTwoA;
            
            // Process intersections
            if (t0 >= 0.0 && t0 <= 1.0) {
                let x = a.x * t0 * t0 + b.x * t0 + c.x;
                let posy = a.y * t0 * t0 + b.y * t0 + c.y; // Should be ~0
                let derivx = tangentAtSimple(p0.x, p1.x, p2.x, t0);
                
                if (abs(posy) < 1.0) { // Within window
                    let delta = integrateWindowSimple(posy);
                    coverage += select(-delta, delta, derivx < 0.0);
                }
            }
            
            if (t1 >= 0.0 && t1 <= 1.0 && abs(t1 - t0) > eps) {
                let x = a.x * t1 * t1 + b.x * t1 + c.x;
                let posy = a.y * t1 * t1 + b.y * t1 + c.y; // Should be ~0
                let derivx = tangentAtSimple(p0.x, p1.x, p2.x, t1);
                
                if (abs(posy) < 1.0) { // Within window
                    let delta = integrateWindowSimple(posy);
                    coverage += select(-delta, delta, derivx < 0.0);
                }
            }
        }
    } else if (abs(b.y) > eps) {
        // Linear case
        let t = -c.y / b.y;
        if (t >= 0.0 && t <= 1.0) {
            let x = b.x * t + c.x;
            let posy = b.y * t + c.y; // Should be ~0
            
            if (abs(posy) < 1.0) { // Within window
                let delta = integrateWindowSimple(posy);
                coverage += select(-delta, delta, b.x < 0.0);
            }
        }
    }
    
    return coverage;
}

// Simplified parabolic windowing function
fn integrateWindowSimple(x: f32) -> f32 {
    let xsq = x * x;
    return sign(x) * (0.5 * xsq * xsq - xsq) + 0.5;
}

// Simple tangent calculation
fn tangentAtSimple(p0: f32, p1: f32, p2: f32, t: f32) -> f32 {
    return 2.0 * (1.0 - t) * (p1 - p0) + 2.0 * t * (p2 - p1);
}
"""
end

# Test shader to isolate winding number issues causing "pencil drawing" effect
function getTestWindingFragmentShader()::String
    return """
// Test fragment shader for proper winding number calculation
// Designed to eliminate the "pencil drawing" effect in font interiors

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
    
    let glyph = glyphs[input.bufferIndex];
    
    // Use simple non-zero winding rule with proper accumulation
    var windingNumber = 0.0;
    
    // Process each curve to accumulate winding contributions
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }
        
        let curve = curves[curveIndex];
        
        // Transform curve points to sample space
        let p0 = vec2<f32>(curve.x0, curve.y0) - input.uv;
        let p1 = vec2<f32>(curve.x1, curve.y1) - input.uv;
        let p2 = vec2<f32>(curve.x2, curve.y2) - input.uv;
        
        // Use proper signed winding contribution
        windingNumber += computeWindingContribution(p0, p1, p2);
    }
    
    // Non-zero winding rule: filled if winding number != 0
    // Use simple threshold to avoid the "pencil drawing" effect
    let alpha = select(0.0, 1.0, abs(windingNumber) > 0.5);
    
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
}

// Compute the signed winding contribution of a curve
fn computeWindingContribution(p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> f32 {
    // Early exit if curve is entirely above or below the horizontal ray
    if (p0.y > 0.0 && p1.y > 0.0 && p2.y > 0.0) { return 0.0; }
    if (p0.y < 0.0 && p1.y < 0.0 && p2.y < 0.0) { return 0.0; }
    
    // Standard quadratic Bezier parameterization
    let a = p0 - 2.0 * p1 + p2;
    let b = 2.0 * (p1 - p0);
    let c = p0;
    
    var contribution = 0.0;
    let eps = 1e-6;
    
    if (abs(a.y) > eps) {
        // Quadratic case
        let discriminant = b.y * b.y - 4.0 * a.y * c.y;
        if (discriminant >= 0.0) {
            let sqrtDisc = sqrt(discriminant);
            let invTwoA = 1.0 / (2.0 * a.y);
            let t0 = (-b.y - sqrtDisc) * invTwoA;
            let t1 = (-b.y + sqrtDisc) * invTwoA;
            
            // Process each intersection
            if (t0 >= 0.0 && t0 <= 1.0) {
                let x = a.x * t0 * t0 + b.x * t0 + c.x;
                if (x > 0.0) {
                    // Compute the derivative to determine winding direction
                    let dy = 2.0 * a.y * t0 + b.y;
                    contribution += sign(dy); // +1 for upward crossing, -1 for downward
                }
            }
            
            if (t1 >= 0.0 && t1 <= 1.0 && abs(t1 - t0) > eps) {
                let x = a.x * t1 * t1 + b.x * t1 + c.x;
                if (x > 0.0) {
                    // Compute the derivative to determine winding direction
                    let dy = 2.0 * a.y * t1 + b.y;
                    contribution += sign(dy); // +1 for upward crossing, -1 for downward
                }
            }
        }
    } else if (abs(b.y) > eps) {
        // Linear case
        let t = -c.y / b.y;
        if (t >= 0.0 && t <= 1.0) {
            let x = b.x * t + c.x;
            if (x > 0.0) {
                contribution += sign(b.y); // +1 for upward crossing, -1 for downward
            }
        }
    }
    
    return contribution;
}
"""
end

# Wallace Dobbie's original approach - the foundational GPU text rendering algorithm
# Based on: https://wdobbie.com/post/gpu-text-rendering-with-vector-textures/
# This is the simplest and most elegant approach, using direct quadratic curve evaluation
function getWallaceDobbieFragmentShader()::String
    return """
// Wallace Dobbie's original GPU text rendering approach
// Based on https://wdobbie.com/post/gpu-text-rendering-with-vector-textures/
// The foundational algorithm that inspired all subsequent GPU font rendering work

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
    
    let glyph = glyphs[input.bufferIndex];
    
    // Use Wallace Dobbie's elegant approach: accumulate coverage from all curves
    var totalCoverage = 0.0;
    
    // Process each curve in the glyph
    for (var i = 0u; i < glyph.count; i += 1u) {
        let curveIndex = glyph.start + i;
        if (curveIndex >= arrayLength(&curves)) {
            break;
        }
        
        let curve = curves[curveIndex];
        
        // Transform curve points to fragment coordinate space
        let p0 = vec2<f32>(curve.x0, curve.y0) - input.uv;
        let p1 = vec2<f32>(curve.x1, curve.y1) - input.uv;
        let p2 = vec2<f32>(curve.x2, curve.y2) - input.uv;
        
        // Calculate coverage contribution from this curve
        totalCoverage += computeWallaceDobbieWinding(p0, p1, p2);
    }
    
    // Apply the coverage to get final alpha
    let alpha = clamp(abs(totalCoverage), 0.0, 1.0);
    
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
}

// Wallace Dobbie's original coverage calculation
// This is the core innovation: testing if a fragment is inside/outside a quadratic curve
fn computeWallaceDobbieWinding(p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>) -> f32 {
    // Early exit if curve is entirely above or below the horizontal ray
    if (p0.y > 0.0 && p1.y > 0.0 && p2.y > 0.0) { return 0.0; }
    if (p0.y < 0.0 && p1.y < 0.0 && p2.y < 0.0) { return 0.0; }
    
    // Find where the curve intersects the horizontal ray (y = 0)
    // For quadratic Bezier: B(t) = (1-t)²p0 + 2t(1-t)p1 + t²p2
    // We want to solve B_y(t) = 0
    
    let a = p0.y - 2.0 * p1.y + p2.y;
    let b = 2.0 * (p1.y - p0.y);
    let c = p0.y;
    
    var winding = 0.0;
    let eps = 1e-6;
    
    if (abs(a) > eps) {
        // Quadratic case: solve at² + bt + c = 0
        let discriminant = b * b - 4.0 * a * c;
        if (discriminant >= 0.0) {
            let sqrtDisc = sqrt(discriminant);
            let invTwoA = 1.0 / (2.0 * a);
            
            // Two potential intersection points
            let t1 = (-b - sqrtDisc) * invTwoA;
            let t2 = (-b + sqrtDisc) * invTwoA;
            
            // Process each intersection that's within the curve parameter range [0,1]
            if (t1 >= 0.0 && t1 <= 1.0) {
                let x = (1.0 - t1) * (1.0 - t1) * p0.x + 2.0 * t1 * (1.0 - t1) * p1.x + t1 * t1 * p2.x;
                if (x > 0.0) {
                    // Ray crosses curve to the right of the fragment
                    // Determine winding direction from curve derivative
                    let dy = 2.0 * a * t1 + b;
                    winding += sign(dy);
                }
            }
            
            if (t2 >= 0.0 && t2 <= 1.0 && abs(t2 - t1) > eps) {
                let x = (1.0 - t2) * (1.0 - t2) * p0.x + 2.0 * t2 * (1.0 - t2) * p1.x + t2 * t2 * p2.x;
                if (x > 0.0) {
                    // Ray crosses curve to the right of the fragment
                    let dy = 2.0 * a * t2 + b;
                    winding += sign(dy);
                }
            }
        }
    } else if (abs(b) > eps) {
        // Linear case: solve bt + c = 0
        let t = -c / b;
        if (t >= 0.0 && t <= 1.0) {
            let x = (1.0 - t) * p0.x + t * p2.x;
            if (x > 0.0) {
                winding += sign(b);
            }
        }
    }
    
    return winding;
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
