# Evan Wallace's triangulation-based font rendering approach
# Based on his "Easy Scalable Text Rendering on the GPU" article
# Uses polygon triangulation instead of curve-based rendering

function getWallaceFragmentShader()::String
    return """
// Evan Wallace's triangulation-based font rendering
// Based on "Easy Scalable Text Rendering on the GPU"
// Uses Loop-Blinn technique for quadratic curve triangulation

struct Glyph {
    start: u32,
    count: u32,
}

struct Triangle {
    // Triangle vertices in screen space
    ax: f32, ay: f32,  // Vertex A
    bx: f32, by: f32,  // Vertex B  
    cx: f32, cy: f32,  // Vertex C
    // Barycentric coordinates for curve evaluation
    s: f32, t: f32,    // Loop-Blinn coordinates
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
    
    var alpha = 0.0;
    
    if (input.triangleType == 0u) {
        // Solid triangle - always contributes full coverage
        alpha = 1.0;
    } else {
        // Quadratic curve triangle - use Loop-Blinn test
        let s = input.barycentricCoords.x;
        let t = input.barycentricCoords.y;
        
        // Loop-Blinn formula for quadratic curves
        // The curve is defined implicitly as s² - t = 0
        // We're inside the curve if s² - t < 0
        let curveTest = s * s - t;
        
        if (curveTest < 0.0) {
            // Inside the curve
            alpha = 1.0;
            
            // Apply anti-aliasing at curve boundaries
            let edgeDistance = abs(curveTest);
            let aaWidth = uniforms.antiAliasingWindowSize * length(vec2<f32>(dpdx(curveTest), dpdy(curveTest)));
            alpha = 1.0 - smoothstep(0.0, aaWidth, edgeDistance);
        }
    }
    
    return vec4<f32>(uniforms.color.rgb, uniforms.color.a * alpha);
}
"""
end

function getWallaceVertexShader()::String
    return """
// Evan Wallace's triangulation vertex shader
struct VertexInput {
    @location(0) position: vec2<f32>,
    @location(1) depth: f32,
    @location(2) barycentricCoords: vec2<f32>,
    @location(3) triangleType: u32,
    @location(4) bufferIndex: i32,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) bufferIndex: i32,
    @location(2) barycentricCoords: vec2<f32>,
    @location(3) triangleType: u32,
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
    output.uv = input.position; // Use world position as UV for curve evaluation
    output.bufferIndex = input.bufferIndex;
    output.barycentricCoords = input.barycentricCoords;
    output.triangleType = input.triangleType;
    
    return output;
}
"""
end

# Wallace approach requires different data structures
struct WallaceTriangle
    # Triangle vertices
    ax::Float32
    ay::Float32
    bx::Float32
    by::Float32
    cx::Float32
    cy::Float32
    # Loop-Blinn coordinates
    s::Float32
    t::Float32
    triangleType::UInt32  # 0 = solid, 1 = curve
end

struct WallaceVertex
    x::Float32
    y::Float32
    z::Float32  # Depth
    s::Float32  # Barycentric coordinate
    t::Float32  # Barycentric coordinate
    triangleType::UInt32
    bufferIndex::Int32
end

# Font triangulation functions (simplified version of Wallace's approach)
function triangulateGlyph(curves::Vector{BufferCurve})::Vector{WallaceTriangle}
    triangles = WallaceTriangle[]
    
    # This is a simplified triangulation - in a full implementation,
    # you would use a proper polygon triangulation library
    for (i, curve) in enumerate(curves)
        # Create a quadratic curve triangle using Loop-Blinn technique
        # This is a simplified version - full implementation would be more complex
        
        # For quadratic curves, create triangle with proper barycentric coordinates
        triangle = WallaceTriangle(
            curve.x0, curve.y0,  # Point A
            curve.x1, curve.y1,  # Point B (control point)
            curve.x2, curve.y2,  # Point C
            0.0, 0.0,             # s, t coordinates (would be computed properly)
            1                     # Curve triangle type
        )
        push!(triangles, triangle)
    end
    
    return triangles
end

function generateWallaceVertexData(triangles::Vector{WallaceTriangle})::Vector{WallaceVertex}
    vertices = WallaceVertex[]
    
    for (i, triangle) in enumerate(triangles)
        # Generate three vertices for each triangle
        push!(vertices, WallaceVertex(
            triangle.ax, triangle.ay, 0.0f0,
            0.0f0, 0.0f0,  # Barycentric (0,0) for vertex A
            triangle.triangleType,
            Int32(i-1)
        ))
        
        push!(vertices, WallaceVertex(
            triangle.bx, triangle.by, 0.0f0,
            0.5f0, 0.0f0,  # Barycentric (0.5,0) for vertex B
            triangle.triangleType,
            Int32(i-1)
        ))
        
        push!(vertices, WallaceVertex(
            triangle.cx, triangle.cy, 0.0f0,
            1.0f0, 1.0f0,  # Barycentric (1,1) for vertex C
            triangle.triangleType,
            Int32(i-1)
        ))
    end
    
    return vertices
end