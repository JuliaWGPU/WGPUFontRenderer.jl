# WGPUFontRenderer.jl - Julia implementation following gpu-font-renderer
# Based on: https://github.com/GreenLightning/gpu-font-rendering

using WGPUCore
using FreeType

# Font Renderer State - following gpu-font-renderer structure
mutable struct FontRenderer
    device::WGPUCore.GPUDevice
    queue::WGPUCore.GPUQueue
    pipeline::Union{WGPUCore.GPURenderPipeline, Nothing}
    bindGroupLayout::Union{WGPUCore.GPUBindGroupLayout, Nothing}
    bindGroup::Union{WGPUCore.GPUBindGroup, Nothing}
    
    # GPU Buffers - following gpu-font-renderer pattern
    glyphBuffer::Union{WGPUCore.GPUBuffer, Nothing}
    curveBuffer::Union{WGPUCore.GPUBuffer, Nothing}
    uniformBuffer::Union{WGPUCore.GPUBuffer, Nothing}
    vertexBuffer::Union{WGPUCore.GPUBuffer, Nothing}
    
    # Window dimensions for proper scaling
    windowWidth::Float32
    windowHeight::Float32
    
    # Data storage
    glyphs::Vector{Glyph}
    curves::Vector{BufferCurve}
    vertices::Vector{BufferVertex}
    
    function FontRenderer(device::WGPUCore.GPUDevice, queue::WGPUCore.GPUQueue, width::Float32 = 800.0f0, height::Float32 = 600.0f0)
        new(device, queue, nothing, nothing, nothing,
            nothing, nothing, nothing, nothing,
            width, height,
            Glyph[], BufferCurve[], BufferVertex[])
    end
end

# Uniform data structure for shader
struct FontUniforms
    color::NTuple{4, Float32}
    projection::NTuple{16, Float32}  # 4x4 projection matrix
    antiAliasingWindowSize::Float32
    enableSuperSamplingAntiAliasing::UInt32
    padding::NTuple{2, UInt32}  # Padding for alignment
end

# Create font renderer - following gpu-font-renderer initialization pattern
function createFontRenderer(device::WGPUCore.GPUDevice, queue::WGPUCore.GPUQueue)::FontRenderer
    renderer = FontRenderer(device, queue)
    return renderer
end

# Initialize renderer with WGPUCore - similar to gpu-font-renderer's setup
function initializeRenderer(renderer::FontRenderer, surfaceFormat::Union{String, Any})
    
    # Create shaders first
    vertexShaderSource = Vector{UInt8}(getVertexShader())
    vertexShaderCode = WGPUCore.loadWGSL(vertexShaderSource)
    vertexShader = WGPUCore.createShaderModule(
        renderer.device,
        "Font Vertex Shader",
        vertexShaderCode.shaderModuleDesc,
        nothing,
        nothing
    )
    
    fragmentShaderSource = Vector{UInt8}(getFragmentShader())
    fragmentShaderCode = WGPUCore.loadWGSL(fragmentShaderSource)
    fragmentShader = WGPUCore.createShaderModule(
        renderer.device,
        "Font Fragment Shader",
        fragmentShaderCode.shaderModuleDesc,
        nothing,
        nothing
    )
    
    # Create bind group layout entries using WGPUCore API
    bindGroupLayoutEntries = [
        WGPUCore.WGPUBufferEntry => [
            :binding => 0,
            :visibility => ["Vertex", "Fragment"],
            :type => "ReadOnlyStorage"
        ],
        WGPUCore.WGPUBufferEntry => [
            :binding => 1,
            :visibility => ["Vertex", "Fragment"],
            :type => "ReadOnlyStorage"
        ],
        WGPUCore.WGPUBufferEntry => [
            :binding => 2,
            :visibility => ["Vertex", "Fragment"],
            :type => "Uniform"
        ]
    ]
    
    # Create dummy buffer to satisfy WGPUCore API requirements
    dummyBuffer = WGPUCore.createBuffer(
        "Dummy Buffer",
        renderer.device,
        16,  # Small size
        ["Storage", "Uniform"],  # Both usages for compatibility
        false
    )
    
    # Create dummy bind group entries that match the layout entries
    dummyBindGroupEntries = [
        WGPUCore.GPUBuffer => [
            :binding => 0,
            :buffer => dummyBuffer,
            :offset => 0,
            :size => 16
        ],
        WGPUCore.GPUBuffer => [
            :binding => 1,
            :buffer => dummyBuffer,
            :offset => 0,
            :size => 16
        ],
        WGPUCore.GPUBuffer => [
            :binding => 2,
            :buffer => dummyBuffer,
            :offset => 0,
            :size => 16
        ]
    ]
    
    # Create pipeline layout using WGPUCore API
    pipelineLayout = WGPUCore.createPipelineLayout(
        renderer.device,
        "Font Pipeline Layout",
        bindGroupLayoutEntries,
        dummyBindGroupEntries
    )
    
    # Create render pipeline - following gpu-font-renderer structure
    renderPipelineOptions = [
        WGPUCore.GPUVertexState => [
            :_module => vertexShader,
            :entryPoint => "vs_main",
            :buffers => [
                WGPUCore.GPUVertexBufferLayout => [
                    :arrayStride => sizeof(BufferVertex),
                    :stepMode => "Vertex",
                    :attributes => [
                        WGPUCore.GPUVertexAttribute => [
                            :format => "Float32x2",
                            :offset => 0,
                            :shaderLocation => 0
                        ],
                        WGPUCore.GPUVertexAttribute => [
                            :format => "Float32x2",
                            :offset => 8,
                            :shaderLocation => 1
                        ],
                        WGPUCore.GPUVertexAttribute => [
                            :format => "Sint32",
                            :offset => 16,
                            :shaderLocation => 2
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
            :topology => "TriangleList",
            :frontFace => "CCW",
            :cullMode => "None",
            :stripIndexFormat => "Undefined"
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
        pipelineLayout,
        renderPipelineOptions;
        label = "Font Render Pipeline"
    )
    
    # Store bind group layout for later use
    renderer.bindGroupLayout = pipelineLayout.bindGroupLayout
end


# Load font data and create buffers - following gpu-font-renderer pattern
function loadFontData(renderer::FontRenderer, text::String)
    # Prepare glyph data for the text
    prepareGlyphsForText(text)
    
# Update renderer's data from global buffers
    renderer.glyphs = collect(values(glyphs))
    renderer.curves = bufferCurves
    
    # Normalize curve coordinates to UV space
    normalizeCurves(renderer, bufferGlyphs)
    
    # Generate vertex data for rendering
    generateVertexData(renderer, text)
    
    # Debug output disabled for cleaner console
    
    # Create GPU buffers
    createGPUBuffers(renderer)
    
    # Create bind group 
    createBindGroup(renderer)
end

function generateVertexData(renderer::FontRenderer, text::String)
    empty!(renderer.vertices)
    
    # Use screen coordinates with proper scaling
    # Font has units per em (stored in fontEmSize), so we need to scale appropriately
    # Much smaller scale for readable text size
    scale = 0.01f0  # Further reduced scale for fitting text within the window
    
    # Define text block bounds for word wrap
    textBlockLeft = 10.0f0
    textBlockTop = 30.0f0
    textBlockRight = 400.0f0  # 400 pixels wide text block
    textBlockBottom = 200.0f0  # 200 pixels tall text block
    textBlockWidth = textBlockRight - textBlockLeft  # 390 pixels
    textBlockHeight = textBlockBottom - textBlockTop  # 170 pixels
    
    # Add text block bounding box visualization (bufferIndex = -2)
    # First triangle: bottom-left, bottom-right, top-left (counter-clockwise)
    push!(renderer.vertices, BufferVertex(textBlockLeft, textBlockBottom, 0.0f0, 0.0f0, -2))  # Bottom-left
    push!(renderer.vertices, BufferVertex(textBlockRight, textBlockBottom, 0.0f0, 0.0f0, -2))  # Bottom-right
    push!(renderer.vertices, BufferVertex(textBlockLeft, textBlockTop, 0.0f0, 0.0f0, -2))  # Top-left
    
    # Second triangle: bottom-right, top-right, top-left (counter-clockwise)
    push!(renderer.vertices, BufferVertex(textBlockRight, textBlockBottom, 0.0f0, 0.0f0, -2))  # Bottom-right
    push!(renderer.vertices, BufferVertex(textBlockRight, textBlockTop, 0.0f0, 0.0f0, -2))  # Top-right
    push!(renderer.vertices, BufferVertex(textBlockLeft, textBlockTop, 0.0f0, 0.0f0, -2))  # Top-left
    
    # Word wrap implementation
    xOffset = textBlockLeft + 5.0f0   # Start with small left padding
    yOffset = textBlockTop + 20.0f0   # Start with some top padding
    lineHeight = 16.0f0  # Line height in pixels
    
    # Split text into words for proper word wrapping
    words = split(text, ' ')
    
    for (wordIndex, word) in enumerate(words)
        # Calculate word width before placing it
        wordWidth = 0.0f0
        for char in word
            if haskey(glyphs, char)
                glyph = glyphs[char]
                charWidth = glyph.advance * scale
                wordWidth += charWidth
            end
        end
        
        # Check if word fits on current line
        if xOffset + wordWidth > textBlockRight - 5.0f0  # Account for right padding
            # Move to next line
            xOffset = textBlockLeft + 5.0f0  # Reset to left margin
            yOffset += lineHeight
            
            # Check if we've exceeded the text block height
            if yOffset + lineHeight > textBlockBottom - 5.0f0
                break  # Stop rendering if we exceed the text block bounds
            end
        end
        
        # Render each character in the word
        for char in word
            if haskey(glyphs, char)
                glyph = glyphs[char]
                
                # Calculate glyph quad dimensions in screen coordinates
                width = glyph.width * scale  
                height = glyph.height * scale
                bearingX = glyph.bearingX * scale
                bearingY = glyph.bearingY * scale

                # Define quad vertices with correct orientation
                x1 = xOffset + bearingX
                y1 = yOffset - bearingY + height  # Bottom of glyph
                x2 = x1 + width
                y2 = yOffset - bearingY           # Top of glyph
                
                # Only generate vertices if glyph has actual dimensions
                if width > 0.0f0 && height > 0.0f0
                    # Generate UV coordinates in font units (same coordinate space as curves)
                    u0 = Float32(glyph.bearingX)
                    v0 = Float32(glyph.bearingY - glyph.height)
                    u1 = Float32(glyph.bearingX + glyph.width)
                    v1 = Float32(glyph.bearingY)

                    # Draw bounding box around the text quad as a simple filled rectangle
                    # First triangle: bottom-left, bottom-right, top-left (counter-clockwise)
                    push!(renderer.vertices, BufferVertex(x1, y1, u0, v0, -1))  # Bottom-left
                    push!(renderer.vertices, BufferVertex(x2, y1, u1, v0, -1))  # Bottom-right
                    push!(renderer.vertices, BufferVertex(x1, y2, u0, v1, -1))  # Top-left
                    
                    # Second triangle: bottom-right, top-right, top-left (counter-clockwise)
                    push!(renderer.vertices, BufferVertex(x2, y1, u1, v0, -1))  # Bottom-right
                    push!(renderer.vertices, BufferVertex(x2, y2, u1, v1, -1))  # Top-right
                    push!(renderer.vertices, BufferVertex(x1, y2, u0, v1, -1))  # Top-left

                    # First triangle: bottom-left, bottom-right, top-left (counter-clockwise)
                    push!(renderer.vertices, BufferVertex(x1, y1, u0, v0, glyph.bufferIndex))
                    push!(renderer.vertices, BufferVertex(x2, y1, u1, v0, glyph.bufferIndex))
                    push!(renderer.vertices, BufferVertex(x1, y2, u0, v1, glyph.bufferIndex))
                    
                    # Second triangle: bottom-right, top-right, top-left (counter-clockwise)
                    push!(renderer.vertices, BufferVertex(x2, y1, u1, v0, glyph.bufferIndex))
                    push!(renderer.vertices, BufferVertex(x2, y2, u1, v1, glyph.bufferIndex))
                    push!(renderer.vertices, BufferVertex(x1, y2, u0, v1, glyph.bufferIndex))
                end
                
                # Advance position for next character
                advanceWidth = glyph.advance * scale
                xOffset += advanceWidth
            end
        end
        
        # Add space after word (except for the last word)
        if wordIndex < length(words)
            if haskey(glyphs, ' ')
                spaceGlyph = glyphs[' ']
                spaceWidth = spaceGlyph.advance * scale
                xOffset += spaceWidth
            else
                # Fallback space width if space character not available
                xOffset += 4.0f0 * scale
            end
        end
    end
end

# Keep curves in font units (for coverage calculation)
function normalizeCurves(renderer::FontRenderer, bufferGlyphs::Vector{BufferGlyph})
    # For the coverage calculation to work correctly, both UVs and curves
    # must be in the same coordinate space (font units)
    # The curves are already in font units from the font processing,
    # so we don't need to normalize them
    
    
    # Debug removed for non-intrusive output
    for i in 1:min(3, length(renderer.curves))
        curve = renderer.curves[i]
    end
end

function createGPUBuffers(renderer::FontRenderer)
    # Create glyph buffer using BufferGlyph type from global buffer
    # The global bufferGlyphs contains the mapping from glyphs to curves
    if !isempty(bufferGlyphs)
        glyphBytes = Vector{UInt8}(undef, sizeof(BufferGlyph) * length(bufferGlyphs))
        ptr = Ptr{BufferGlyph}(pointer(glyphBytes))
        unsafe_copyto!(ptr, pointer(bufferGlyphs), length(bufferGlyphs))
        
        (renderer.glyphBuffer, _) = WGPUCore.createBufferWithData(
            renderer.device,
            "Glyph Buffer",
            glyphBytes,
            ["Storage", "CopySrc"]
        )
    end
    
    # Create curve buffer  
    if !isempty(renderer.curves)
        curveBytes = Vector{UInt8}(undef, sizeof(BufferCurve) * length(renderer.curves))
        ptr = Ptr{BufferCurve}(pointer(curveBytes))
        unsafe_copyto!(ptr, pointer(renderer.curves), length(renderer.curves))
        
        (renderer.curveBuffer, _) = WGPUCore.createBufferWithData(
            renderer.device,
            "Curve Buffer",
            curveBytes,
            ["Storage", "CopySrc"]
        )
    end
    
# Create uniform buffer with proper orthographic projection
    # Create orthographic projection matrix for screen coordinates
    # Dynamically calculate viewport size based on window dimensions
    left = 0.0f0
    right = renderer.windowWidth  # Use window width dynamically
    bottom = renderer.windowHeight  # Use window height dynamically
    top = 0.0f0
    near = -1.0f0
    far = 1.0f0
    
    # Column-major orthographic projection matrix (WGSL format)
    ortho = (
        2.0f0 / (right - left), 0.0f0, 0.0f0, 0.0f0,
        0.0f0, 2.0f0 / (top - bottom), 0.0f0, 0.0f0,
        0.0f0, 0.0f0, -2.0f0 / (far - near), 0.0f0,
        -(right + left) / (right - left), -(top + bottom) / (top - bottom), -(far + near) / (far - near), 1.0f0
    )
    
    # Calculate appropriate anti-aliasing window size based on font scale
    # The scale factor used in vertex generation is 0.02, so 1 screen pixel = 50 font units
    pixelSizeInFontUnits = 1.0f0 / 0.02f0  # = 50.0 font units per screen pixel
    
    # Use the exact reference implementation approach for anti-aliasing
    # The reference uses antiAliasingWindowSize = 1.0 for normal anti-aliasing
    aaWindowSize = 1.0f0  # Match reference implementation default
    
    uniforms = FontUniforms(
        (1.0f0, 1.0f0, 1.0f0, 1.0f0),  # White color
        ortho,  # Proper orthographic projection matrix
        aaWindowSize,  # Reference implementation anti-aliasing window size
        0,      # Disable super-sampling AA to fix horizontal/vertical lines
        (0, 0)  # Padding
    )
    
    uniformBytes = Vector{UInt8}(undef, sizeof(FontUniforms))
    ptr = Ptr{FontUniforms}(pointer(uniformBytes))
    unsafe_store!(ptr, uniforms)
    
    (renderer.uniformBuffer, _) = WGPUCore.createBufferWithData(
        renderer.device,
        "Font Uniform Buffer",
        uniformBytes,
        ["Uniform", "CopyDst"]
    )
    
    # Create vertex buffer
    if !isempty(renderer.vertices)
        vertexBytes = Vector{UInt8}(undef, sizeof(BufferVertex) * length(renderer.vertices))
        ptr = Ptr{BufferVertex}(pointer(vertexBytes))
        unsafe_copyto!(ptr, pointer(renderer.vertices), length(renderer.vertices))
        
        (renderer.vertexBuffer, _) = WGPUCore.createBufferWithData(
            renderer.device,
            "Vertex Buffer",
            vertexBytes,
            ["Vertex", "CopyDst"]
        )
    end
end

# Create bind group - following gpu-font-renderer pattern
function createBindGroup(renderer::FontRenderer)
    if renderer.bindGroupLayout === nothing
        @warn "Bind group layout not initialized"
        return
    end
    
    # Check if all required buffers are created
    if renderer.glyphBuffer === nothing || renderer.curveBuffer === nothing || renderer.uniformBuffer === nothing
        @warn "Required buffers not created yet"
        return
    end
    
    # Create bind group entries using WGPUCore API
    bindGroupEntries = [
        WGPUCore.GPUBuffer => [
            :binding => 0,
            :buffer => renderer.glyphBuffer,
            :offset => 0,
            :size => renderer.glyphBuffer.size
        ],
        WGPUCore.GPUBuffer => [
            :binding => 1,
            :buffer => renderer.curveBuffer,
            :offset => 0,
            :size => renderer.curveBuffer.size
        ],
        WGPUCore.GPUBuffer => [
            :binding => 2,
            :buffer => renderer.uniformBuffer,
            :offset => 0,
            :size => renderer.uniformBuffer.size
        ]
    ]
    
    # Create bind group using WGPUCore API
    cBindingsList = WGPUCore.makeBindGroupEntryList(bindGroupEntries)
    renderer.bindGroup = WGPUCore.createBindGroup(
        "Font Bind Group",
        renderer.device,
        renderer.bindGroupLayout,
        cBindingsList
    )
    
    # Debug output disabled for clean console
end


function renderText(renderer::FontRenderer, renderPass::WGPUCore.GPURenderPassEncoder)
    if renderer.pipeline === nothing || renderer.vertexBuffer === nothing
        @warn "Font renderer not properly initialized"
        return
    end
    
    # Set pipeline and bind group
    WGPUCore.setPipeline(renderPass, renderer.pipeline)
    
    # Set bind group if available
    if renderer.bindGroup !== nothing
        WGPUCore.setBindGroup(renderPass, 0, renderer.bindGroup, UInt32[], 0, 99)
    end
    
    # Set vertex buffer
    WGPUCore.setVertexBuffer(renderPass, 0, renderer.vertexBuffer, 0, renderer.vertexBuffer.size)
    
    # Draw vertices
    vertexCount = length(renderer.vertices)
    WGPUCore.draw(renderPass, vertexCount; instanceCount = 1, firstVertex = 0, firstInstance = 0)
end
