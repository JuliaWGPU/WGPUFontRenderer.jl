# Advanced GPU Vertex Font Renderer
# Text Editor Foundation with Instanced Rendering
# Based on modern GPU text rendering techniques

using WGPUCore
using FreeType

# Advanced glyph instance data for GPU rendering
struct GlyphInstance
    # Position and scale
    position::NTuple{2, Float32}      # Screen position (x, y)
    size::NTuple{2, Float32}          # Glyph size (width, height)
    
    # UV coordinates in font atlas
    uv_min::NTuple{2, Float32}        # UV top-left
    uv_max::NTuple{2, Float32}        # UV bottom-right
    
    # Color and effects
    color::NTuple{4, Float32}         # RGBA color
    
    # Font metadata
    glyph_index::UInt32               # Index into glyph data
    padding::NTuple{3, UInt32}        # Alignment padding
end

# Text layout and formatting info
struct TextBlock
    start_char::UInt32                # Starting character index
    char_count::UInt32                # Number of characters
    line_number::UInt32               # Line number in document
    column::UInt32                    # Starting column
    
    # Layout properties
    baseline_y::Float32               # Baseline position
    line_height::Float32              # Line height
    advance_x::Float32                # Total advance width
    
    # Styling
    font_size::Float32                # Font size
    style_flags::UInt32               # Bold, italic, underline flags
end

# Advanced font renderer for text editor
mutable struct AdvancedFontRenderer
    device::WGPUCore.GPUDevice
    queue::WGPUCore.GPUQueue
    
    # Rendering pipeline
    pipeline::Union{WGPUCore.GPURenderPipeline, Nothing}
    bind_group_layout::Union{WGPUCore.GPUBindGroupLayout, Nothing}
    bind_group::Union{WGPUCore.GPUBindGroup, Nothing}
    
    # Buffers
    vertex_buffer::Union{WGPUCore.GPUBuffer, Nothing}      # Quad vertices
    instance_buffer::Union{WGPUCore.GPUBuffer, Nothing}    # Glyph instances
    uniform_buffer::Union{WGPUCore.GPUBuffer, Nothing}     # View/projection uniforms
    
    # Font atlas data
    atlas_texture::Union{WGPUCore.GPUTexture, Nothing}     # Font atlas texture
    atlas_sampler::Union{WGPUCore.GPUSampler, Nothing}     # Texture sampler
    
    # Text layout
    glyph_instances::Vector{GlyphInstance}
    text_blocks::Vector{TextBlock}
    
    # Font metrics
    font_size::Float32
    line_height::Float32
    char_width::Float32               # Average character width for monospace
    
    # Viewport
    viewport_width::Float32
    viewport_height::Float32
    scroll_x::Float32
    scroll_y::Float32
    
    function AdvancedFontRenderer(device::WGPUCore.GPUDevice, queue::WGPUCore.GPUQueue)
        new(device, queue, nothing, nothing, nothing,
            nothing, nothing, nothing, nothing, nothing,
            GlyphInstance[], TextBlock[],
            16.0f0, 20.0f0, 8.0f0,
            800.0f0, 600.0f0, 0.0f0, 0.0f0)
    end
end

# Uniforms for advanced renderer
struct AdvancedUniforms
    view_projection::NTuple{16, Float32}    # Combined view-projection matrix
    viewport_size::NTuple{2, Float32}       # Viewport dimensions
    scroll_offset::NTuple{2, Float32}       # Scroll position
    font_size::Float32                      # Base font size
    line_height::Float32                    # Line height
    time::Float32                           # Animation time
    padding::Float32                        # Alignment
end

# Create the advanced renderer
function createAdvancedRenderer(device::WGPUCore.GPUDevice, queue::WGPUCore.GPUQueue)::AdvancedFontRenderer
    return AdvancedFontRenderer(device, queue)
end

# Initialize the advanced rendering pipeline
function initializeAdvancedRenderer!(renderer::AdvancedFontRenderer, surface_format::String)
    # Create shaders
    vertex_shader_source = Vector{UInt8}(getAdvancedVertexShader())
    vertex_shader_code = WGPUCore.loadWGSL(vertex_shader_source)
    vertex_shader = WGPUCore.createShaderModule(
        renderer.device,
        "Advanced Font Vertex Shader",
        vertex_shader_code.shaderModuleDesc,
        nothing, nothing
    )
    
    fragment_shader_source = Vector{UInt8}(getAdvancedFragmentShader())
    fragment_shader_code = WGPUCore.loadWGSL(fragment_shader_source)
    fragment_shader = WGPUCore.createShaderModule(
        renderer.device,
        "Advanced Font Fragment Shader", 
        fragment_shader_code.shaderModuleDesc,
        nothing, nothing
    )
    
    # Create bind group layout
    bind_group_layout_entries = [
        # Uniforms
        WGPUCore.WGPUBufferEntry => [
            :binding => 0,
            :visibility => ["Vertex", "Fragment"],
            :type => "Uniform"
        ],
        # Font atlas texture
        WGPUCore.WGPUTextureEntry => [
            :binding => 1,
            :visibility => ["Fragment"],
            :sampleType => "Float",
            :viewDimension => "2d"
        ],
        # Texture sampler
        WGPUCore.WGPUSamplerEntry => [
            :binding => 2,
            :visibility => ["Fragment"],
            :type => "Filtering"
        ]
    ]
    
    # Create dummy resources for pipeline creation
    dummy_buffer = WGPUCore.createBuffer("Dummy", renderer.device, 64, ["Uniform"], false)
    dummy_texture = WGPUCore.createTexture(
        renderer.device,
        [32, 32, 1],
        "2d",
        "RGBA8Unorm",
        ["TextureBinding", "CopyDst"],
        1, 1, "Opaque"
    )
    dummy_sampler = WGPUCore.createSampler(renderer.device)
    
    dummy_bind_group_entries = [
        WGPUCore.GPUBuffer => [:binding => 0, :buffer => dummy_buffer, :offset => 0, :size => 64],
        WGPUCore.GPUTexture => [:binding => 1, :texture => dummy_texture],
        WGPUCore.GPUSampler => [:binding => 2, :sampler => dummy_sampler]
    ]
    
    # Create pipeline layout
    pipeline_layout = WGPUCore.createPipelineLayout(
        renderer.device,
        "Advanced Font Pipeline Layout",
        bind_group_layout_entries,
        dummy_bind_group_entries
    )
    
    # Define vertex attributes for instanced rendering
    vertex_attributes = [
        # Quad vertex positions (per vertex)
        WGPUCore.GPUVertexAttribute => [
            :format => "Float32x2",
            :offset => 0,
            :shaderLocation => 0
        ],
        # Quad UV coordinates (per vertex)  
        WGPUCore.GPUVertexAttribute => [
            :format => "Float32x2",
            :offset => 8,
            :shaderLocation => 1
        ]
    ]
    
    instance_attributes = [
        # Instance position (per instance)
        WGPUCore.GPUVertexAttribute => [
            :format => "Float32x2",
            :offset => 0,
            :shaderLocation => 2
        ],
        # Instance size (per instance)
        WGPUCore.GPUVertexAttribute => [
            :format => "Float32x2", 
            :offset => 8,
            :shaderLocation => 3
        ],
        # Instance UV min (per instance)
        WGPUCore.GPUVertexAttribute => [
            :format => "Float32x2",
            :offset => 16,
            :shaderLocation => 4
        ],
        # Instance UV max (per instance)
        WGPUCore.GPUVertexAttribute => [
            :format => "Float32x2",
            :offset => 24,
            :shaderLocation => 5
        ],
        # Instance color (per instance)
        WGPUCore.GPUVertexAttribute => [
            :format => "Float32x4",
            :offset => 32,
            :shaderLocation => 6
        ],
        # Glyph index (per instance)
        WGPUCore.GPUVertexAttribute => [
            :format => "Uint32",
            :offset => 48,
            :shaderLocation => 7
        ]
    ]
    
    # Create render pipeline
    render_pipeline_options = [
        WGPUCore.GPUVertexState => [
            :_module => vertex_shader,
            :entryPoint => "vs_main",
            :buffers => [
                # Vertex buffer (positions and UVs)
                WGPUCore.GPUVertexBufferLayout => [
                    :arrayStride => 16,  # 2 * Float32x2
                    :stepMode => "Vertex",
                    :attributes => vertex_attributes
                ],
                # Instance buffer (per-glyph data)
                WGPUCore.GPUVertexBufferLayout => [
                    :arrayStride => sizeof(GlyphInstance),
                    :stepMode => "Instance", 
                    :attributes => instance_attributes
                ]
            ]
        ],
        WGPUCore.GPUFragmentState => [
            :_module => fragment_shader,
            :entryPoint => "fs_main",
            :targets => [
                WGPUCore.GPUColorTargetState => [
                    :format => surface_format,
                    :color => [:srcFactor => "SrcAlpha", :dstFactor => "OneMinusSrcAlpha", :operation => "Add"],
                    :alpha => [:srcFactor => "One", :dstFactor => "OneMinusSrcAlpha", :operation => "Add"]
                ]
            ]
        ],
        WGPUCore.GPUPrimitiveState => [
            :topology => "TriangleList",
            :frontFace => "CCW", 
            :cullMode => "None"
        ],
        WGPUCore.GPUDepthStencilState => [],
        WGPUCore.GPUMultiSampleState => [
            :count => 1,
            :mask => typemax(UInt32),
            :alphaToCoverageEnabled => false
        ]
    ]
    
    renderer.pipeline = WGPUCore.createRenderPipeline(
        renderer.device,
        pipeline_layout,
        render_pipeline_options;
        label = "Advanced Font Render Pipeline"
    )
    
    renderer.bind_group_layout = pipeline_layout.bindGroupLayout
    
    # Create quad vertex buffer (will be shared by all glyph instances)
    createQuadVertexBuffer!(renderer)
    
    println("✓ Advanced font renderer initialized")
end

# Create the shared quad vertex buffer
function createQuadVertexBuffer!(renderer::AdvancedFontRenderer)
    # Define a unit quad (will be scaled per instance)
    quad_vertices = Float32[
        # Position (x,y), UV (u,v)
        0.0, 0.0,  0.0, 0.0,  # Bottom-left
        1.0, 0.0,  1.0, 0.0,  # Bottom-right  
        0.0, 1.0,  0.0, 1.0,  # Top-left
        1.0, 0.0,  1.0, 0.0,  # Bottom-right
        1.0, 1.0,  1.0, 1.0,  # Top-right
        0.0, 1.0,  0.0, 1.0   # Top-left
    ]
    
    vertex_bytes = reinterpret(UInt8, quad_vertices)
    
    (renderer.vertex_buffer, _) = WGPUCore.createBufferWithData(
        renderer.device,
        "Quad Vertex Buffer",
        vertex_bytes,
        ["Vertex"]
    )
end

# Update viewport settings
function setViewport!(renderer::AdvancedFontRenderer, width::Float32, height::Float32)
    renderer.viewport_width = width
    renderer.viewport_height = height
    updateUniforms!(renderer)
end

# Update scroll position
function setScroll!(renderer::AdvancedFontRenderer, x::Float32, y::Float32)
    renderer.scroll_x = x
    renderer.scroll_y = y
    updateUniforms!(renderer)
end

# Update font settings
function setFontSettings!(renderer::AdvancedFontRenderer, size::Float32, line_height::Float32)
    renderer.font_size = size
    renderer.line_height = line_height
    renderer.char_width = size * 0.6f0  # Approximate monospace character width
    updateUniforms!(renderer)
end

# Create/update uniform buffer
function updateUniforms!(renderer::AdvancedFontRenderer)
    # Create orthographic projection matrix
    left = 0.0f0
    right = renderer.viewport_width
    bottom = renderer.viewport_height  
    top = 0.0f0
    near = -1.0f0
    far = 1.0f0
    
    # View matrix with scroll offset
    view_matrix = (
        1.0f0, 0.0f0, 0.0f0, 0.0f0,
        0.0f0, 1.0f0, 0.0f0, 0.0f0, 
        0.0f0, 0.0f0, 1.0f0, 0.0f0,
        -renderer.scroll_x, -renderer.scroll_y, 0.0f0, 1.0f0
    )
    
    # Projection matrix
    proj_matrix = (
        2.0f0 / (right - left), 0.0f0, 0.0f0, 0.0f0,
        0.0f0, 2.0f0 / (top - bottom), 0.0f0, 0.0f0,
        0.0f0, 0.0f0, -2.0f0 / (far - near), 0.0f0,
        -(right + left) / (right - left), -(top + bottom) / (top - bottom), -(far + near) / (far - near), 1.0f0
    )
    
    # Combine view and projection (MVP matrix)
    uniforms = AdvancedUniforms(
        proj_matrix,  # For now, just use projection; view will be handled in vertex shader
        (renderer.viewport_width, renderer.viewport_height),
        (renderer.scroll_x, renderer.scroll_y),
        renderer.font_size,
        renderer.line_height,
        0.0f0,  # time
        0.0f0   # padding
    )
    
    uniform_bytes = Vector{UInt8}(undef, sizeof(AdvancedUniforms))
    ptr = Ptr{AdvancedUniforms}(pointer(uniform_bytes))
    unsafe_store!(ptr, uniforms)
    
    if renderer.uniform_buffer === nothing
        (renderer.uniform_buffer, _) = WGPUCore.createBufferWithData(
            renderer.device,
            "Advanced Uniform Buffer",
            uniform_bytes,
            ["Uniform", "CopyDst"]
        )
    else
        # Update existing buffer
        WGPUCore.writeBuffer(renderer.queue, renderer.uniform_buffer, 0, uniform_bytes)
    end
end

# Layout text into glyph instances
function layoutText!(renderer::AdvancedFontRenderer, text::String, start_x::Float32 = 0.0f0, start_y::Float32 = 0.0f0)
    empty!(renderer.glyph_instances)
    empty!(renderer.text_blocks)
    
    x = start_x
    y = start_y
    line_number = 0
    char_index = 0
    
    for char in text
        if char == '\n'
            # New line
            x = start_x
            y += renderer.line_height
            line_number += 1
            char_index += 1
            continue
        end
        
        # Skip non-printable characters for now
        if !isprint(char)
            char_index += 1
            continue
        end
        
        # Create glyph instance
        glyph_instance = GlyphInstance(
            (x, y),                           # position
            (renderer.char_width, renderer.font_size),  # size
            (0.0f0, 0.0f0),                  # uv_min (placeholder)
            (1.0f0, 1.0f0),                  # uv_max (placeholder) 
            (1.0f0, 1.0f0, 1.0f0, 1.0f0),    # color (white)
            UInt32(char),                     # glyph_index (use char code for now)
            (0, 0, 0)                        # padding
        )
        
        push!(renderer.glyph_instances, glyph_instance)
        
        # Advance cursor
        x += renderer.char_width
        char_index += 1
    end
    
    # Update instance buffer
    updateInstanceBuffer!(renderer)
    
    println("✓ Laid out $(length(renderer.glyph_instances)) glyphs")
end

# Update the GPU instance buffer
function updateInstanceBuffer!(renderer::AdvancedFontRenderer)
    if isempty(renderer.glyph_instances)
        return
    end
    
    instance_bytes = Vector{UInt8}(undef, sizeof(GlyphInstance) * length(renderer.glyph_instances))
    ptr = Ptr{GlyphInstance}(pointer(instance_bytes))
    unsafe_copyto!(ptr, pointer(renderer.glyph_instances), length(renderer.glyph_instances))
    
    if renderer.instance_buffer === nothing
        (renderer.instance_buffer, _) = WGPUCore.createBufferWithData(
            renderer.device,
            "Glyph Instance Buffer",
            instance_bytes,
            ["Vertex", "CopyDst"]
        )
    else
        # Update existing buffer or recreate if size changed
        WGPUCore.writeBuffer(renderer.queue, renderer.instance_buffer, 0, instance_bytes)
    end
end

# Create bind group for rendering
function createAdvancedBindGroup!(renderer::AdvancedFontRenderer)
    if renderer.bind_group_layout === nothing || renderer.uniform_buffer === nothing
        @warn "Cannot create bind group: missing layout or uniform buffer"
        return
    end
    
    # Create a placeholder texture for now
    if renderer.atlas_texture === nothing
        renderer.atlas_texture = WGPUCore.createTexture(
            renderer.device,
            [256, 256, 1],
            "2d", 
            "RGBA8Unorm",
            ["TextureBinding", "CopyDst"],
            1, 1, "Opaque"
        )
    end
    
    if renderer.atlas_sampler === nothing
        renderer.atlas_sampler = WGPUCore.createSampler(renderer.device)
    end
    
    bind_group_entries = [
        WGPUCore.GPUBuffer => [
            :binding => 0,
            :buffer => renderer.uniform_buffer,
            :offset => 0,
            :size => sizeof(AdvancedUniforms)
        ],
        WGPUCore.GPUTexture => [
            :binding => 1,
            :texture => renderer.atlas_texture
        ],
        WGPUCore.GPUSampler => [
            :binding => 2,
            :sampler => renderer.atlas_sampler
        ]
    ]
    
    c_bindings_list = WGPUCore.makeBindGroupEntryList(bind_group_entries)
    renderer.bind_group = WGPUCore.createBindGroup(
        "Advanced Font Bind Group",
        renderer.device,
        renderer.bind_group_layout,
        c_bindings_list
    )
    
    println("✓ Advanced bind group created")
end

# Render the text
function renderAdvancedText!(renderer::AdvancedFontRenderer, render_pass::WGPUCore.GPURenderPassEncoder)
    if renderer.pipeline === nothing || 
       renderer.vertex_buffer === nothing || 
       renderer.instance_buffer === nothing ||
       isempty(renderer.glyph_instances)
        return
    end
    
    # Set pipeline and bind group
    WGPUCore.setPipeline(render_pass, renderer.pipeline)
    
    if renderer.bind_group !== nothing
        WGPUCore.setBindGroup(render_pass, 0, renderer.bind_group, UInt32[], 0, 99)
    end
    
    # Set vertex buffers
    WGPUCore.setVertexBuffer(render_pass, 0, renderer.vertex_buffer, 0, renderer.vertex_buffer.size)
    WGPUCore.setVertexBuffer(render_pass, 1, renderer.instance_buffer, 0, renderer.instance_buffer.size)
    
    # Draw instanced quads (6 vertices per quad, N instances)
    instance_count = length(renderer.glyph_instances)
    WGPUCore.draw(render_pass, 6, instance_count, 0, 0)
end

# Convenience function to setup a complete text editor renderer
function setupTextEditor(device::WGPUCore.GPUDevice, queue::WGPUCore.GPUQueue, surface_format::String)
    renderer = createAdvancedRenderer(device, queue)
    initializeAdvancedRenderer!(renderer, surface_format)
    setViewport!(renderer, 800.0f0, 600.0f0)
    setFontSettings!(renderer, 14.0f0, 18.0f0)
    updateUniforms!(renderer)
    createAdvancedBindGroup!(renderer)
    return renderer
end

# Additional utility functions for the demo
function addGlyphInstance!(renderer::AdvancedFontRenderer, instance::GlyphInstance)
    push!(renderer.glyph_instances, instance)
end

function updateViewport!(renderer::AdvancedFontRenderer, width::Int, height::Int)
    setViewport!(renderer, Float32(width), Float32(height))
end

function updateScrollPosition!(renderer::AdvancedFontRenderer, scroll::SVector{2, Float32})
    setScroll!(renderer, scroll[1], scroll[2])
end

function renderInstances!(renderer::AdvancedFontRenderer, render_pass)
    renderAdvancedText!(renderer, render_pass)
end

# Create a simplified renderer function that matches the demo expectations
function createAdvancedFontRenderer(device, width::Int, height::Int)
    queue = WGPUCore.getQueue(device)
    surface_format = "BGRA8Unorm"  # Default format
    
    renderer = setupTextEditor(device, queue, surface_format)
    setViewport!(renderer, Float32(width), Float32(height))
    return renderer
end

export AdvancedFontRenderer, GlyphInstance, TextBlock, AdvancedUniforms
export createAdvancedRenderer, initializeAdvancedRenderer!, setViewport!, setScroll!
export setFontSettings!, layoutText!, renderAdvancedText!, setupTextEditor
export addGlyphInstance!, updateViewport!, updateScrollPosition!, renderInstances!, createAdvancedFontRenderer
