# WGPUFontRenderer.jl - Julia implementation following gpu-font-renderer
# Based on: https://github.com/GreenLightning/gpu-font-rendering

using WGPUCore
using WGPUNative
using FreeType

# Import font processing functions and global variables
include("font.jl")

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
    
    # Try binary shader to eliminate all anti-aliasing artifacts
    fragmentShaderSource = Vector{UInt8}(getBinaryFragmentShader())
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
                            :format => "Float32",
                            :offset => 8,
                            :shaderLocation => 1
                        ],
                        WGPUCore.GPUVertexAttribute => [
                            :format => "Float32x2",
                            :offset => 12,
                            :shaderLocation => 2
                        ],
                        WGPUCore.GPUVertexAttribute => [
                            :format => "Sint32",
                            :offset => 20,
                            :shaderLocation => 3
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
    
    println("DEBUG: Loaded $(length(glyphs)) glyphs from global buffer")
    println("DEBUG: Loaded $(length(bufferCurves)) curves from global buffer")
    if !isempty(bufferCurves)
        curve = bufferCurves[1]
        println("DEBUG: First curve: ($(curve.x0), $(curve.y0)) -> ($(curve.x1), $(curve.y1)) -> ($(curve.x2), $(curve.y2))")
    end
    
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
    
    # Debug output for first few vertices
    if !isempty(renderer.glyphs)
        println("DEBUG: Generating vertices for $(length(renderer.glyphs)) glyphs")
    end
    
    println("DEBUG: Total vertices before generation: $(length(renderer.vertices))")
    
    # CRITICAL FIX: Use proper font scaling that matches reference implementation
    # The reference gpu-font-rendering uses worldSize parameter for scaling
    # We need to scale from font units to screen pixels consistently
    worldSize = 100.0f0  # Even larger for very visible text (2000x reference)
    scale = worldSize / 1000.0f0  # Use standard em size of 1000 for visibility
    println("DEBUG: worldSize=$worldSize, scale=$scale")
    
    # Define text block bounds for word wrap - expand for larger font
    textBlockLeft = 10.0f0
    textBlockTop = 50.0f0
    textBlockRight = 750.0f0  # Wider text block for large font
    textBlockBottom = 500.0f0  # Taller text block for large font
    textBlockWidth = textBlockRight - textBlockLeft  # 740 pixels
    textBlockHeight = textBlockBottom - textBlockTop  # 450 pixels
    
    # Add text block bounding box visualization (bufferIndex = -2)
    # First triangle: bottom-left, bottom-right, top-left (counter-clockwise)
    push!(renderer.vertices, BufferVertex(textBlockLeft, textBlockBottom, 0.9f0, 0.0f0, 0.0f0, -2))  # Bottom-left
    push!(renderer.vertices, BufferVertex(textBlockRight, textBlockBottom, 0.9f0, 0.0f0, 0.0f0, -2))  # Bottom-right
    push!(renderer.vertices, BufferVertex(textBlockLeft, textBlockTop, 0.9f0, 0.0f0, 0.0f0, -2))  # Top-left
    
    # Second triangle: bottom-right, top-right, top-left (counter-clockwise)
    push!(renderer.vertices, BufferVertex(textBlockRight, textBlockBottom, 0.9f0, 0.0f0, 0.0f0, -2))  # Bottom-right
    push!(renderer.vertices, BufferVertex(textBlockRight, textBlockTop, 0.9f0, 0.0f0, 0.0f0, -2))  # Top-right
    push!(renderer.vertices, BufferVertex(textBlockLeft, textBlockTop, 0.9f0, 0.0f0, 0.0f0, -2))  # Top-left
    
    # Word wrap implementation - position text to be clearly visible
    xOffset = textBlockLeft + 50.0f0   # Start with reasonable padding
    yOffset = textBlockTop + 50.0f0   # Position text at top of text block with padding
    lineHeight = 80.0f0  # Large line height for visibility
    
    # Split text into words for proper word wrapping
    words = split(text, ' ')
    println("DEBUG: Split text into $(length(words)) words")
    
    for (wordIndex, word) in enumerate(words)
        println("DEBUG: Processing word $wordIndex: '$word' (length $(length(word)))")
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
        println("DEBUG: Word width check: xOffset=$xOffset, wordWidth=$wordWidth, textBlockRight=$textBlockRight")
        if xOffset + wordWidth > textBlockRight - 5.0f0  # Account for right padding
            # Move to next line
            println("DEBUG: Word doesn't fit, moving to next line")
            xOffset = textBlockLeft + 5.0f0  # Reset to left margin
            yOffset += lineHeight
            
            # Check if we've exceeded the text block height
            println("DEBUG: Height check: yOffset=$yOffset, lineHeight=$lineHeight, textBlockBottom=$textBlockBottom")
            if yOffset + lineHeight > textBlockBottom - 5.0f0
                println("DEBUG: Exceeded text block height, breaking")
                break  # Stop rendering if we exceed the text block bounds
            end
        end
        
        # Render each character in the word
        println("DEBUG: Starting character processing for word '$word'")
        for char in word
            println("DEBUG: Processing character '$char'")
            if haskey(glyphs, char)
                println("DEBUG: Found glyph for '$char'")
                glyph = glyphs[char]
                println("DEBUG: Glyph data: bufferIndex=$(glyph.bufferIndex), width=$(glyph.width), height=$(glyph.height)")
                
                # Calculate glyph quad dimensions in screen coordinates
                width = glyph.width * scale  
                height = glyph.height * scale
                bearingX = glyph.bearingX * scale
                bearingY = glyph.bearingY * scale

                # Define quad vertices to match reference implementation coordinate system
                # In the reference implementation, Y increases upward in font space
                # but we need to convert to WebGPU screen coordinates where Y increases downward
                x1 = xOffset + bearingX
                y1 = yOffset - bearingY           # Top of glyph (smaller Y value in screen coords)
                x2 = x1 + width
                y2 = yOffset - bearingY + height  # Bottom of glyph (larger Y value in screen coords)
                
                # Only generate vertices if glyph has actual dimensions
                if width > 0.0f0 && height > 0.0f0
                    # Generate UV coordinates in font units (same coordinate space as curves)
                    # Match reference implementation exactly - UVs should be in font coordinate space
                    u0 = Float32(glyph.bearingX) / fontEmSize
                    v0 = Float32(glyph.bearingY - glyph.height) / fontEmSize
                    u1 = Float32(glyph.bearingX + glyph.width) / fontEmSize
                    v1 = Float32(glyph.bearingY) / fontEmSize

                    # Draw bounding box around the text quad as a simple filled rectangle
                    # First triangle: bottom-left, bottom-right, top-left (counter-clockwise)
                    push!(renderer.vertices, BufferVertex(x1, y1, 0.5f0, u0, v0, -1))  # Bottom-left
                    push!(renderer.vertices, BufferVertex(x2, y1, 0.5f0, u1, v0, -1))  # Bottom-right
                    push!(renderer.vertices, BufferVertex(x1, y2, 0.5f0, u0, v1, -1))  # Top-left
                    
                    # Second triangle: bottom-right, top-right, top-left (counter-clockwise)
                    push!(renderer.vertices, BufferVertex(x2, y1, 0.5f0, u1, v0, -1))  # Bottom-right
                    push!(renderer.vertices, BufferVertex(x2, y2, 0.5f0, u1, v1, -1))  # Top-right
                    push!(renderer.vertices, BufferVertex(x1, y2, 0.5f0, u0, v1, -1))  # Top-left

                    # First triangle: bottom-left, bottom-right, top-left (counter-clockwise)
                    push!(renderer.vertices, BufferVertex(x1, y1, 0.0f0, u0, v0, glyph.bufferIndex))
                    push!(renderer.vertices, BufferVertex(x2, y1, 0.0f0, u1, v0, glyph.bufferIndex))
                    push!(renderer.vertices, BufferVertex(x1, y2, 0.0f0, u0, v1, glyph.bufferIndex))
                    
                    # Second triangle: bottom-right, top-right, top-left (counter-clockwise)
                    push!(renderer.vertices, BufferVertex(x2, y1, 0.0f0, u1, v0, glyph.bufferIndex))
                    push!(renderer.vertices, BufferVertex(x2, y2, 0.0f0, u1, v1, glyph.bufferIndex))
                    push!(renderer.vertices, BufferVertex(x1, y2, 0.0f0, u0, v1, glyph.bufferIndex))
                    
                    # Debug output for first character
                    if char == 'H'
                        println("DEBUG: 'H' glyph vertices: ($x1, $y1) to ($x2, $y2)")
                        println("DEBUG: Scale=$scale, xOffset=$xOffset, yOffset=$yOffset")
                        println("DEBUG: Glyph size: $(x2-x1) x $(y1-y2)")
                    end
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
    
    println("DEBUG: Total vertices after generation: $(length(renderer.vertices))")
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
        # println("DEBUG: Creating glyph buffer with $(length(bufferGlyphs)) glyphs")
        
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
    # Create orthographic projection matrix that matches the reference implementation approach
    # The reference uses: glm::ortho(0.0f, (float) width, 0.0f, (float) height, -1.0f, 1.0f)
    # For WebGPU we need to account for the Y-axis direction difference
    left = 0.0f0
    right = renderer.windowWidth
    top = renderer.windowHeight  # Flip for WebGPU coordinate system
    bottom = 0.0f0               # Flip for WebGPU coordinate system
    near = -1.0f0
    far = 1.0f0
    
    # Column-major orthographic projection matrix (WGSL format)
    # This matrix maps screen coordinates to NDC correctly for WebGPU
    ortho = (
        2.0f0 / (right - left), 0.0f0, 0.0f0, 0.0f0,
        0.0f0, 2.0f0 / (top - bottom), 0.0f0, 0.0f0,  # Flipped for WebGPU Y direction
        0.0f0, 0.0f0, -2.0f0 / (far - near), 0.0f0,
        -(right + left) / (right - left), -(top + bottom) / (top - bottom), -(far + near) / (far - near), 1.0f0
    )
    
    # CRITICAL FIX: Use reference implementation anti-aliasing approach
    # The reference implementation uses antiAliasingWindowSize = 1.0 for normal anti-aliasing
    # The actual scaling is handled by fwidth() in the shader, not here
    # With our protection against division by zero, we can use the proper reference value
    aaWindowSize = 1.0f0  # Reference implementation value with proper protection
    println("DEBUG: antiAliasingWindowSize = $aaWindowSize")
    
    uniforms = FontUniforms(
        (0.0f0, 0.0f0, 0.0f0, 1.0f0),  # Black color for visibility on light background
        ortho,  # Proper orthographic projection matrix
        aaWindowSize,  # Reference implementation anti-aliasing window size
        1,      # Enable super-sampling AA for better quality (properly implemented now)
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
