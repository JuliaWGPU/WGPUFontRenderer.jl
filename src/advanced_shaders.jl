# Advanced WGSL Shaders for GPU Vertex Font Rendering
# Optimized for text editor use with instanced rendering

# Advanced vertex shader with instanced rendering
function getAdvancedVertexShader()::String
    return """
// Advanced vertex shader for instanced glyph rendering
// Perfect for text editors with thousands of characters

struct AdvancedUniforms {
    view_projection: mat4x4<f32>,
    viewport_size: vec2<f32>,
    scroll_offset: vec2<f32>,
    font_size: f32,
    line_height: f32,
    time: f32,
    padding: f32,
}

struct VertexInput {
    // Per-vertex data (shared quad)
    @location(0) position: vec2<f32>,      // Quad vertex position (0-1)
    @location(1) uv: vec2<f32>,            // Quad UV coordinates (0-1)
    
    // Per-instance data (unique per glyph)
    @location(2) instance_position: vec2<f32>,   // Glyph screen position
    @location(3) instance_size: vec2<f32>,       // Glyph size
    @location(4) instance_uv_min: vec2<f32>,     // Glyph UV min in atlas
    @location(5) instance_uv_max: vec2<f32>,     // Glyph UV max in atlas
    @location(6) instance_color: vec4<f32>,      // Glyph color
    @location(7) glyph_index: u32,               // Glyph index for effects
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,            // Interpolated atlas UV
    @location(1) color: vec4<f32>,         // Glyph color
    @location(2) glyph_info: vec2<f32>,    // Additional glyph data
}

@group(0) @binding(0) var<uniform> uniforms: AdvancedUniforms;

@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;
    
    // Calculate world position for this glyph instance
    // Scale the unit quad by instance size and translate by instance position
    let world_pos = input.instance_position + input.position * input.instance_size;
    
    // Apply scroll offset
    let scrolled_pos = world_pos - uniforms.scroll_offset;
    
    // Transform to clip space
    let clip_pos = vec4<f32>(scrolled_pos, 0.0, 1.0);
    output.position = uniforms.view_projection * clip_pos;
    
    // Interpolate UV coordinates within the glyph's atlas region
    output.uv = mix(input.instance_uv_min, input.instance_uv_max, input.uv);
    
    // Pass through color
    output.color = input.instance_color;
    
    // Pack additional glyph information
    output.glyph_info = vec2<f32>(f32(input.glyph_index), uniforms.time);
    
    return output;
}
"""
end

# Advanced fragment shader with font atlas sampling
function getAdvancedFragmentShader()::String
    return """
// Advanced fragment shader for GPU font rendering
// Uses font atlas texture for high-quality glyph rendering

struct FragmentInput {
    @location(0) uv: vec2<f32>,           // Atlas UV coordinates
    @location(1) color: vec4<f32>,        // Glyph color
    @location(2) glyph_info: vec2<f32>,   // Glyph index and time
}

@group(0) @binding(1) var font_atlas: texture_2d<f32>;
@group(0) @binding(2) var atlas_sampler: sampler;

@fragment
fn fs_main(input: FragmentInput) -> @location(0) vec4<f32> {
    // Sample the font atlas at the interpolated UV coordinates
    let atlas_sample = textureSample(font_atlas, atlas_sampler, input.uv);
    
    // For now, use a simple colored rectangle approach
    // In a full implementation, this would use the atlas alpha channel
    // let alpha = atlas_sample.r;  // Assuming single-channel font atlas
    
    // Placeholder: Create a simple pattern based on character
    let char_code = u32(input.glyph_info.x);
    let color_variation = sin(f32(char_code) * 0.1) * 0.2 + 0.8;
    
    // Create a simple glyph visualization
    let center = vec2<f32>(0.5, 0.5);
    let dist_to_center = distance(input.uv, center);
    let alpha = 1.0 - smoothstep(0.3, 0.5, dist_to_center);
    
    // Apply color with variation
    var final_color = input.color;
    final_color.rgb *= color_variation;
    final_color.a *= alpha;
    
    return final_color;
}
"""
end

# Simple solid color shader for testing
function getAdvancedSolidShader()::String
    return """
// Simple solid color fragment shader for testing instanced rendering

struct FragmentInput {
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) glyph_info: vec2<f32>,
}

@fragment
fn fs_main(input: FragmentInput) -> @location(0) vec4<f32> {
    // Use character code to create different colors
    let char_code = u32(input.glyph_info.x) % 6u;
    
    var base_color: vec3<f32>;
    switch (char_code) {
        case 0u: { base_color = vec3<f32>(1.0, 0.2, 0.2); }      // Red
        case 1u: { base_color = vec3<f32>(0.2, 1.0, 0.2); }      // Green  
        case 2u: { base_color = vec3<f32>(0.2, 0.2, 1.0); }      // Blue
        case 3u: { base_color = vec3<f32>(1.0, 1.0, 0.2); }      // Yellow
        case 4u: { base_color = vec3<f32>(1.0, 0.2, 1.0); }      // Magenta
        default: { base_color = vec3<f32>(0.2, 1.0, 1.0); }      // Cyan
    }
    
    return vec4<f32>(base_color, 1.0);
}
"""
end

# Font atlas-based fragment shader (for future font atlas implementation)
function getAdvancedAtlasShader()::String
    return """
// Font atlas-based fragment shader for production text rendering

struct FragmentInput {
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>, 
    @location(2) glyph_info: vec2<f32>,
}

@group(0) @binding(1) var font_atlas: texture_2d<f32>;
@group(0) @binding(2) var atlas_sampler: sampler;

@fragment
fn fs_main(input: FragmentInput) -> @location(0) vec4<f32> {
    // Sample the font atlas
    let atlas_sample = textureSample(font_atlas, atlas_sampler, input.uv);
    
    // Font atlas typically stores distance field or alpha information
    // For SDF (Signed Distance Field) fonts:
    let distance = atlas_sample.r;
    let alpha = smoothstep(0.5 - 0.1, 0.5 + 0.1, distance);
    
    // For simple alpha-based fonts:
    // let alpha = atlas_sample.a;
    
    // Apply text color with atlas alpha
    var final_color = input.color;
    final_color.a *= alpha;
    
    // Optional: Add subtle effects
    let char_index = input.glyph_info.x;
    let time = input.glyph_info.y;
    
    // Cursor blinking effect for specific character (example)
    if (char_index == 0.0) {
        let blink = sin(time * 3.0) * 0.5 + 0.5;
        final_color.a *= blink;
    }
    
    return final_color;
}
"""
end

# Shader variant with text effects (outline, shadow, etc.)
function getAdvancedEffectsShader()::String
    return """
// Advanced effects shader with outline, shadow, and other text effects

struct AdvancedUniforms {
    view_projection: mat4x4<f32>,
    viewport_size: vec2<f32>,
    scroll_offset: vec2<f32>,
    font_size: f32,
    line_height: f32,
    time: f32,
    padding: f32,
}

struct FragmentInput {
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) glyph_info: vec2<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: AdvancedUniforms;
@group(0) @binding(1) var font_atlas: texture_2d<f32>;
@group(0) @binding(2) var atlas_sampler: sampler;

@fragment
fn fs_main(input: FragmentInput) -> @location(0) vec4<f32> {
    let uv = input.uv;
    
    // Sample main glyph
    let main_sample = textureSample(font_atlas, atlas_sampler, uv).r;
    
    // Calculate outline by sampling surrounding pixels
    let texel_size = 1.0 / vec2<f32>(textureDimensions(font_atlas));
    let outline_width = 2.0 * texel_size.x;
    
    // Sample 8 surrounding points for outline
    var outline_alpha = 0.0;
    for (var i = -1; i <= 1; i += 1) {
        for (var j = -1; j <= 1; j += 1) {
            if (i == 0 && j == 0) { continue; }
            let offset = vec2<f32>(f32(i), f32(j)) * outline_width;
            let sample_uv = uv + offset;
            outline_alpha = max(outline_alpha, textureSample(font_atlas, atlas_sampler, sample_uv).r);
        }
    }
    
    // Create outline effect
    let main_alpha = smoothstep(0.5 - 0.1, 0.5 + 0.1, main_sample);
    let outline_mask = smoothstep(0.4, 0.6, outline_alpha) * (1.0 - main_alpha);
    
    // Combine main text and outline
    let outline_color = vec3<f32>(0.0, 0.0, 0.0); // Black outline
    var final_color = mix(
        vec4<f32>(outline_color, outline_mask),
        input.color * main_alpha,
        main_alpha
    );
    
    // Add shadow effect
    let shadow_offset = vec2<f32>(2.0, -2.0) * texel_size;
    let shadow_sample = textureSample(font_atlas, atlas_sampler, uv + shadow_offset).r;
    let shadow_alpha = smoothstep(0.4, 0.6, shadow_sample) * 0.5;
    
    if (main_alpha < 0.1 && outline_mask < 0.1) {
        final_color = vec4<f32>(0.0, 0.0, 0.0, shadow_alpha);
    }
    
    return final_color;
}
"""
end

export getAdvancedVertexShader, getAdvancedFragmentShader
export getAdvancedSolidShader, getAdvancedAtlasShader, getAdvancedEffectsShader
