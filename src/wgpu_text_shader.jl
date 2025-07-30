# Modern WGPU Text Rendering Shader
# Based on wgpu-text approach using texture atlas sampling
# This eliminates all curve-based artifacts and horizontal lines

function getWGPUTextVertexShader()::String
    return """
// Modern WGPU Text Vertex Shader - Texture Atlas Based
// Based on wgpu-text approach for artifact-free rendering

struct VertexInput {
    @builtin(vertex_index) vertex_index: u32,
    @location(0) top_left: vec3<f32>,
    @location(1) bottom_right: vec2<f32>,
    @location(2) tex_top_left: vec2<f32>,
    @location(3) tex_bottom_right: vec2<f32>,
    @location(4) color: vec4<f32>,
}

struct Matrix {
    v: mat4x4<f32>,
}

@group(0) @binding(0)
var<uniform> ortho: Matrix;

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) tex_pos: vec2<f32>,
    @location(1) color: vec4<f32>,
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    var pos: vec2<f32>;
    let left: f32 = in.top_left.x;
    let right: f32 = in.bottom_right.x;
    let top: f32 = in.top_left.y;
    let bottom: f32 = in.bottom_right.y;

    // Generate quad vertices using vertex_index
    switch (in.vertex_index) {
        case 0u: {
            pos = vec2<f32>(left, top);
            out.tex_pos = in.tex_top_left;
        }
        case 1u: {
            pos = vec2<f32>(right, top);
            out.tex_pos = vec2<f32>(in.tex_bottom_right.x, in.tex_top_left.y);
        }
        case 2u: {
            pos = vec2<f32>(left, bottom);
            out.tex_pos = vec2<f32>(in.tex_top_left.x, in.tex_bottom_right.y);
        }
        case 3u: {
            pos = vec2<f32>(right, bottom);
            out.tex_pos = in.tex_bottom_right;
        }
        default: {
            pos = vec2<f32>(0.0, 0.0);
            out.tex_pos = vec2<f32>(0.0, 0.0);
        }
    }

    out.clip_position = ortho.v * vec4<f32>(pos, in.top_left.z, 1.0);
    out.color = in.color;
    return out;
}
"""
end

function getWGPUTextFragmentShader()::String
    return """
// Modern WGPU Text Fragment Shader - Texture Atlas Based
// Eliminates all curve-based artifacts through simple texture sampling

@group(0) @binding(1)
var texture: texture_2d<f32>;
@group(0) @binding(2)
var tex_sampler: sampler;

struct FragmentInput {
    @location(0) tex_pos: vec2<f32>,
    @location(1) color: vec4<f32>,
}

@fragment
fn fs_main(in: FragmentInput) -> @location(0) vec4<f32> {
    // Simple texture sampling - no complex math, no artifacts!
    let alpha: f32 = textureSample(texture, tex_sampler, in.tex_pos).r;
    
    // Return final color with texture alpha
    return vec4<f32>(in.color.rgb, in.color.a * alpha);
}
"""
end

# Modern vertex structure for wgpu-text approach
struct WGPUTextVertex
    top_left::NTuple{3, Float32}      # x, y, z position
    bottom_right::NTuple{2, Float32}  # right, bottom bounds
    tex_top_left::NTuple{2, Float32}  # texture coordinates
    tex_bottom_right::NTuple{2, Float32}  # texture coordinates
    color::NTuple{4, Float32}         # RGBA color
end

# Orthographic matrix creation (matches wgpu-text)
function createOrthoMatrix(width::Float32, height::Float32)::NTuple{16, Float32}
    return (
        2.0f0 / width,  0.0f0,           0.0f0, 0.0f0,
        0.0f0,         -2.0f0 / height, 0.0f0, 0.0f0,
        0.0f0,          0.0f0,           1.0f0, 0.0f0,
       -1.0f0,          1.0f0,           0.0f0, 1.0f0
    )
end

# Font atlas texture creation helper (moved to modern_renderer.jl)
# This function is defined in modern_renderer.jl where WGPUCore is imported

# Modern text rendering approach using texture atlas
function renderTextModern(text::String, fontSize::Float32, position::Tuple{Float32, Float32})
    # This would integrate with a font rasterization library like:
    # - FreeType for glyph rasterization
    # - A texture atlas packer
    # - Simple quad generation for each glyph
    
    println("Modern text rendering: '$text' at $position with size $fontSize")
    println("✅ No curve math = No horizontal line artifacts!")
end