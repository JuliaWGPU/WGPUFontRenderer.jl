# Modern WGPU Text Renderer
# Based on wgpu-text approach using texture atlas sampling
# Eliminates horizontal line artifacts through simple texture-based rendering

using WGPUCore
using WGPUNative
using FreeType

include("wgpu_text_shader.jl")
include("reference_font_loader.jl")

# Modern font renderer using texture atlas approach with reference font loading
mutable struct ModernFontRenderer
    device::WGPUCore.GPUDevice
    queue::WGPUCore.GPUQueue
    pipeline::Union{WGPUCore.GPURenderPipeline, Nothing}
    bindGroupLayout::Union{WGPUCore.GPUBindGroupLayout, Nothing}
    bindGroup::Union{WGPUCore.GPUBindGroup, Nothing}
    
    # Reference font loader (proper FreeType-based loading)
    fontLoader::Union{ReferenceFontLoader, Nothing}
    
    # Modern approach: texture atlas instead of curve buffers
    fontAtlasTexture::Union{WGPUCore.GPUTexture, Nothing}
    fontAtlasView::Union{WGPUCore.GPUTextureView, Nothing}
    sampler::Union{WGPUCore.GPUSampler, Nothing}
    
    # Simplified buffers
    uniformBuffer::Union{WGPUCore.GPUBuffer, Nothing}
    vertexBuffer::Union{WGPUCore.GPUBuffer, Nothing}
    
    # Window dimensions
    windowWidth::Float32
    windowHeight::Float32
    
    # Vertex data (much simpler than curve-based approach)
    vertices::Vector{WGPUTextVertex}
    
    function ModernFontRenderer(device::WGPUCore.GPUDevice, queue::WGPUCore.GPUQueue, width::Float32 = 800.0f0, height::Float32 = 600.0f0)
        new(device, queue, nothing, nothing, nothing,
            nothing,  # fontLoader
            nothing, nothing, nothing,
            nothing, nothing,
            width, height,
            WGPUTextVertex[])
    end
end

# Initialize modern renderer with texture-based approach
function initializeModernRenderer(renderer::ModernFontRenderer, surfaceFormat::Union{String, Any})
    
    # Create modern shaders (much simpler than curve-based)
    vertexShaderSource = Vector{UInt8}(getWGPUTextVertexShader())
    vertexShaderCode = WGPUCore.loadWGSL(vertexShaderSource)
    vertexShader = WGPUCore.createShaderModule(
        renderer.device,
        "Modern Font Vertex Shader",
        vertexShaderCode.shaderModuleDesc,
        nothing,
        nothing
    )
    
    fragmentShaderSource = Vector{UInt8}(getWGPUTextFragmentShader())
    fragmentShaderCode = WGPUCore.loadWGSL(fragmentShaderSource)
    fragmentShader = WGPUCore.createShaderModule(
        renderer.device,
        "Modern Font Fragment Shader",
        fragmentShaderCode.shaderModuleDesc,
        nothing,
        nothing
    )
    
    # Load reference font using gpu-font-rendering approach
    println("📚 Loading reference font using gpu-font-rendering approach...")
    renderer.fontLoader = loadReferenceFont()
    
    # Create font atlas texture from reference loader
    renderer.fontAtlasTexture = createWGPUFontAtlas(renderer.fontLoader, renderer.device)
    renderer.fontAtlasView = WGPUCore.createView(renderer.fontAtlasTexture)
    
    # Create sampler for texture atlas
    samplerDesc = [
        :addressModeU => "ClampToEdge",
        :addressModeV => "ClampToEdge",
        :addressModeW => "ClampToEdge",
        :magFilter => "Linear",
        :minFilter => "Linear",
        :mipmapFilter => "Nearest"
    ]
    renderer.sampler = WGPUCore.createSampler(renderer.device, samplerDesc)
    
    # Create bind group layout (much simpler than curve-based)
    bindGroupLayoutEntries = [
        WGPUCore.WGPUBufferEntry => [
            :binding => 0,
            :visibility => ["Vertex", "Fragment"],
            :type => "Uniform"
        ],
        WGPUCore.WGPUTextureEntry => [
            :binding => 1,
            :visibility => ["Fragment"],
            :sampleType => "Float",
            :viewDimension => "2d"
        ],
        WGPUCore.WGPUSamplerEntry => [
            :binding => 2,
            :visibility => ["Fragment"],
            :type => "Filtering"
        ]
    ]
    
    # Create dummy buffer for layout creation
    dummyBuffer = WGPUCore.createBuffer(
        "Dummy Buffer",
        renderer.device,
        64,  # Size for matrix uniform
        ["Uniform"],
        false
    )
    
    # Create bind group entries
    dummyBindGroupEntries = [
        WGPUCore.GPUBuffer => [
            :binding => 0,
            :buffer => dummyBuffer,
            :offset => 0,
            :size => 64
        ],
        WGPUCore.GPUTextureView => [
            :binding => 1,
            :view => renderer.fontAtlasView
        ],
        WGPUCore.GPUSampler => [
            :binding => 2,
            :sampler => renderer.sampler
        ]
    ]
    
    # Create pipeline layout
    pipelineLayout = WGPUCore.createPipelineLayout(
        renderer.device,
        "Modern Font Pipeline Layout",
        bindGroupLayoutEntries,
        dummyBindGroupEntries
    )
    
    # Create render pipeline (much simpler vertex layout)
    renderPipelineOptions = [
        WGPUCore.GPUVertexState => [
            :_module => vertexShader,
            :entryPoint => "vs_main",
            :buffers => [
                WGPUCore.GPUVertexBufferLayout => [
                    :arrayStride => sizeof(WGPUTextVertex),
                    :stepMode => "Instance",  # Instance rendering for efficiency
                    :attributes => [
                        WGPUCore.GPUVertexAttribute => [
                            :format => "Float32x3",
                            :offset => 0,
                            :shaderLocation => 0
                        ],
                        WGPUCore.GPUVertexAttribute => [
                            :format => "Float32x2",
                            :offset => 12,
                            :shaderLocation => 1
                        ],
                        WGPUCore.GPUVertexAttribute => [
                            :format => "Float32x2",
                            :offset => 20,
                            :shaderLocation => 2
                        ],
                        WGPUCore.GPUVertexAttribute => [
                            :format => "Float32x2",
                            :offset => 28,
                            :shaderLocation => 3
                        ],
                        WGPUCore.GPUVertexAttribute => [
                            :format => "Float32x4",
                            :offset => 36,
                            :shaderLocation => 4
                        ]
                    ]
                ]
            ]
        ],
        WGPUCore.GPUFragmentState => [
            :_module => fragmentShader,
            :entryPoint => "fs_main",
            :targets => [
                WGPUCore.GPUColorTargetState => [
                    :format => surfaceFormat,
                    :color => [:srcFactor => "SrcAlpha", :dstFactor => "OneMinusSrcAlpha", :operation => "Add"],
                    :alpha => [:srcFactor => "One", :dstFactor => "OneMinusSrcAlpha", :operation => "Add"]
                ]
            ]
        ],
        WGPUCore.GPUPrimitiveState => [
            :topology => "TriangleStrip",  # Efficient for quads
            :frontFace => "CCW",
            :cullMode => "None",
            :stripIndexFormat => "Uint16"
        ],
        WGPUCore.GPUDepthStencilState => [
            :format => WGPUNative.LibWGPU.WGPUTextureFormat_Depth24Plus,
            :depthWriteEnabled => true,
            :depthCompare => WGPUNative.LibWGPU.WGPUCompareFunction_Less
        ],
        WGPUCore.GPUMultiSampleState => [
            :count => 1,
            :mask => typemax(UInt32),
            :alphaToCoverageEnabled => false
        ]
    ]

    renderer.pipeline = WGPUCore.createRenderPipeline(
        renderer.device,
        pipelineLayout,
        renderPipelineOptions;
        label = "Modern Font Render Pipeline"
    )
    
    renderer.bindGroupLayout = pipelineLayout.bindGroupLayout
    
    println("✅ Modern font renderer initialized - No curve math, no artifacts!")
end

# Generate vertex data using reference font loader (proper glyph metrics)
function generateModernVertexData(renderer::ModernFontRenderer, text::String)
    if renderer.fontLoader === nothing
        @warn "Font loader not initialized"
        return
    end
    
    empty!(renderer.vertices)
    
    # Text layout parameters matching gpu-font-rendering
    worldSize = renderer.fontLoader.worldSize
    fontSize = worldSize * 800.0f0  # Scale up for visibility
    xOffset = 50.0f0
    yOffset = 300.0f0
    
    println("🔤 Generating vertex data using reference font metrics...")
    
    # Process each character using proper font metrics
    previousGlyphIndex = UInt32(0)
    for char in text
        charcode = UInt32(char)
        
        if charcode == UInt32(' ')
            # Space character - advance without rendering
            if haskey(renderer.fontLoader.glyphs, charcode)
                glyph = renderer.fontLoader.glyphs[charcode]
                xOffset += Float32(glyph.advance) / renderer.fontLoader.emSize * fontSize
            else
                xOffset += fontSize * 0.3f0  # Default space width
            end
            continue
        end
        
        # Get glyph data (fallback to undefined glyph if not found)
        glyph = get(renderer.fontLoader.glyphs, charcode, renderer.fontLoader.glyphs[UInt32(0)])
        
        # Apply kerning if available (matching gpu-font-rendering approach)
        if previousGlyphIndex != 0 && glyph.index != 0
            # Simplified kerning - in full implementation would use FT_Get_Kerning
            # For now, use default spacing
        end
        
        # Only create quad for glyphs with curves (non-whitespace)
        if glyph.curveCount > 0
            # Calculate glyph bounds using proper metrics
            bearingX = Float32(glyph.bearingX) / renderer.fontLoader.emSize
            bearingY = Float32(glyph.bearingY) / renderer.fontLoader.emSize
            width = Float32(glyph.width) / renderer.fontLoader.emSize
            height = Float32(glyph.height) / renderer.fontLoader.emSize
            
            # Apply dilation (matching gpu-font-rendering)
            dilation = renderer.fontLoader.dilation / renderer.fontLoader.emSize
            
            # Calculate quad bounds
            left = xOffset + (bearingX - dilation) * fontSize
            right = xOffset + (bearingX + width + dilation) * fontSize
            top = yOffset + (bearingY + dilation) * fontSize
            bottom = yOffset + (bearingY - height - dilation) * fontSize
            
            # Use atlas coordinates from font loader
            texLeft = glyph.atlasX
            texRight = glyph.atlasX + glyph.atlasWidth
            texTop = glyph.atlasY
            texBottom = glyph.atlasY + glyph.atlasHeight
            
            # Create vertex for this character quad
            vertex = WGPUTextVertex(
                (left, top, 0.0f0),           # top_left position
                (right, bottom),              # bottom_right bounds
                (texLeft, texTop),            # tex_top_left (real atlas coords)
                (texRight, texBottom),        # tex_bottom_right (real atlas coords)
                (1.0f0, 1.0f0, 1.0f0, 1.0f0) # white color
            )
            
            push!(renderer.vertices, vertex)
        end
        
        # Advance cursor
        xOffset += Float32(glyph.advance) / renderer.fontLoader.emSize * fontSize
        previousGlyphIndex = glyph.index
    end
    
    println("✅ Generated $(length(renderer.vertices)) character quads using reference font metrics!")
end

# Create GPU buffers (much simpler than curve-based approach)
function createModernGPUBuffers(renderer::ModernFontRenderer)
    # Create orthographic projection matrix
    orthoMatrix = createOrthoMatrix(renderer.windowWidth, renderer.windowHeight)
    
    # Create uniform buffer with just the matrix
    uniformBytes = Vector{UInt8}(undef, 64)  # 4x4 matrix = 64 bytes
    ptr = Ptr{NTuple{16, Float32}}(pointer(uniformBytes))
    unsafe_store!(ptr, orthoMatrix)
    
    (renderer.uniformBuffer, _) = WGPUCore.createBufferWithData(
        renderer.device,
        "Modern Font Uniform Buffer",
        uniformBytes,
        ["Uniform", "CopyDst"]
    )
    
    # Create vertex buffer
    if !isempty(renderer.vertices)
        vertexBytes = Vector{UInt8}(undef, sizeof(WGPUTextVertex) * length(renderer.vertices))
        ptr = Ptr{WGPUTextVertex}(pointer(vertexBytes))
        unsafe_copyto!(ptr, pointer(renderer.vertices), length(renderer.vertices))
        
        (renderer.vertexBuffer, _) = WGPUCore.createBufferWithData(
            renderer.device,
            "Modern Font Vertex Buffer",
            vertexBytes,
            ["Vertex", "CopyDst"]
        )
    end
    
    println("✅ Modern GPU buffers created - Simple texture-based approach!")
end

# Create bind group for modern renderer
function createModernBindGroup(renderer::ModernFontRenderer)
    if renderer.bindGroupLayout === nothing || renderer.uniformBuffer === nothing
        @warn "Modern renderer not properly initialized"
        return
    end
    
    # Create bind group entries
    bindGroupEntries = [
        WGPUCore.GPUBuffer => [
            :binding => 0,
            :buffer => renderer.uniformBuffer,
            :offset => 0,
            :size => 64
        ],
        WGPUCore.GPUTextureView => [
            :binding => 1,
            :view => renderer.fontAtlasView
        ],
        WGPUCore.GPUSampler => [
            :binding => 2,
            :sampler => renderer.sampler
        ]
    ]
    
    cBindingsList = WGPUCore.makeBindGroupEntryList(bindGroupEntries)
    renderer.bindGroup = WGPUCore.createBindGroup(
        "Modern Font Bind Group",
        renderer.device,
        renderer.bindGroupLayout,
        cBindingsList
    )
    
    println("✅ Modern bind group created - Ready for artifact-free rendering!")
end

# Render text using modern approach
function renderModernText(renderer::ModernFontRenderer, renderPass::WGPUCore.GPURenderPassEncoder)
    if renderer.pipeline === nothing || renderer.vertexBuffer === nothing
        @warn "Modern font renderer not properly initialized"
        return
    end
    
    # Set pipeline and bind group
    WGPUCore.setPipeline(renderPass, renderer.pipeline)
    
    if renderer.bindGroup !== nothing
        WGPUCore.setBindGroup(renderPass, 0, renderer.bindGroup, UInt32[], 0, 99)
    end
    
    # Set vertex buffer
    WGPUCore.setVertexBuffer(renderPass, 0, renderer.vertexBuffer, 0, renderer.vertexBuffer.size)
    
    # Draw using triangle strip (4 vertices per character quad)
    instanceCount = length(renderer.vertices)
    WGPUCore.draw(renderPass, 4; instanceCount = instanceCount, firstVertex = 0, firstInstance = 0)
    
    println("✅ Modern text rendered - No curves, no artifacts!")
end

# Complete modern font loading pipeline
function loadModernFontData(renderer::ModernFontRenderer, text::String)
    println("🚀 Loading font data using modern texture-based approach...")
    
    # Generate simple vertex data (no complex curve processing)
    generateModernVertexData(renderer, text)
    
    # Create GPU buffers (much simpler)
    createModernGPUBuffers(renderer)
    
    # Create bind group
    createModernBindGroup(renderer)
    
    println("✅ Modern font data loaded - Eliminated all curve-based complexity!")
end