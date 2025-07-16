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
    
    # Data storage
    glyphs::Vector{Glyph}
    curves::Vector{BufferCurve}
    vertices::Vector{BufferVertex}
    
    function FontRenderer(device::WGPUCore.GPUDevice, queue::WGPUCore.GPUQueue)
        new(device, queue, nothing, nothing, nothing,
            nothing, nothing, nothing, nothing,
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
    
    # Debug: Print first few normalized curves to check they're in 0-1 range
    println("\nFirst 5 normalized curves:")
    for i in 1:min(5, length(renderer.curves))
        curve = renderer.curves[i]
        println("  Curve $i: p0=($(curve.x0), $(curve.y0)) p1=($(curve.x1), $(curve.y1)) p2=($(curve.x2), $(curve.y2))")
    end
    
    # Create GPU buffers
    createGPUBuffers(renderer)
    
    # Create bind group 
    createBindGroup(renderer)
end

function generateVertexData(renderer::FontRenderer, text::String)
    empty!(renderer.vertices)
    
    # Use screen coordinates with proper scaling
    # Assuming font size of 64 units, scale to reasonable screen size
    scale = 0.5f0  # Much smaller scale factor for font size
    
    # Start from reasonable screen position
    xOffset = 50.0f0   # Start from left margin
    yOffset = 300.0f0  # Center vertically (screen height is 600)
    
    println("Generating vertex data for text: \"$text\"")
    
    for (i, char) in enumerate(text)
        if haskey(glyphs, char)
            glyph = glyphs[char]
            
            println("  Character '$char': bufferIndex=$(glyph.bufferIndex), width=$(glyph.width), height=$(glyph.height), advance=$(glyph.advance)")
            
            # Calculate glyph quad dimensions
            width = glyph.width * scale  
            height = glyph.height * scale
            bearingX = glyph.bearingX * scale
            bearingY = glyph.bearingY * scale
            
            # Define quad vertices with proper positioning
            x1 = xOffset + bearingX
            y1 = yOffset + bearingY - height  # Bottom of glyph
            x2 = x1 + width                   # Right edge
            y2 = yOffset + bearingY           # Top of glyph
            
            println("    Quad: ($x1, $y1) to ($x2, $y2)")
            
            # Only generate vertices if glyph has actual dimensions
            if width > 0 && height > 0
                # First triangle: top-left, bottom-left, top-right
                # Fix UV coordinates to match curve normalization (Y-flipped)
                push!(renderer.vertices, BufferVertex(x1, y2, 0.0f0, 1.0f0, glyph.bufferIndex))
                push!(renderer.vertices, BufferVertex(x1, y1, 0.0f0, 0.0f0, glyph.bufferIndex))
                push!(renderer.vertices, BufferVertex(x2, y2, 1.0f0, 1.0f0, glyph.bufferIndex))
                
                # Second triangle: bottom-left, bottom-right, top-right
                push!(renderer.vertices, BufferVertex(x1, y1, 0.0f0, 0.0f0, glyph.bufferIndex))
                push!(renderer.vertices, BufferVertex(x2, y1, 1.0f0, 0.0f0, glyph.bufferIndex))
                push!(renderer.vertices, BufferVertex(x2, y2, 1.0f0, 1.0f0, glyph.bufferIndex))
            end
            
            # Advance position for next character - use advance instead of width
            # Add some spacing to prevent overlap
            advanceWidth = max(glyph.advance * scale, width * 1.2f0)
            xOffset += advanceWidth
            
            println("    Advanced by $advanceWidth, next xOffset: $xOffset")
        else
            println("  Character '$char': not found in glyphs")
        end
    end
    
    println("Generated $(length(renderer.vertices)) vertices")
end

# Normalize curve coordinates to UV space (0.0 to 1.0) per glyph
function normalizeCurves(renderer::FontRenderer, bufferGlyphs::Vector{BufferGlyph})
    # We need to normalize curves relative to their glyph's bounding box
    # so that they map correctly to the UV coordinates (0,0) to (1,1) of each glyph quad
    
    for (i, glyph) in enumerate(renderer.glyphs)
        bufferGlyph = bufferGlyphs[i]
        
        # Get the curves for this glyph
        startIdx = Int(bufferGlyph.start) + 1  # Convert to 1-based indexing
        endIdx = startIdx + Int(bufferGlyph.count) - 1
        
        if startIdx <= length(renderer.curves) && endIdx <= length(renderer.curves)
            # Get glyph dimensions in FreeType units
            glyphWidth = Float32(glyph.width)
            glyphHeight = Float32(glyph.height)
            bearingX = Float32(glyph.bearingX)
            bearingY = Float32(glyph.bearingY)
            
            # println("\nGlyph $(i) normalization:")
            # println("  width=$glyphWidth, height=$glyphHeight")
            # println("  bearingX=$bearingX, bearingY=$bearingY")
            
            # Skip if glyph has no dimensions (like space characters)
            if glyphWidth == 0 || glyphHeight == 0
                continue
            end
            
            # Process each curve in this glyph
            for j in startIdx:endIdx
                curve = renderer.curves[j]
                
                # Debug: Show original curve coordinates
                # if j <= startIdx + 2  # Show first 3 curves per glyph
                #     println("  Original curve $(j-startIdx+1): p0=($(curve.x0), $(curve.y0)) p1=($(curve.x1), $(curve.y1)) p2=($(curve.x2), $(curve.y2))")
                # end
                
                # Normalize curve coordinates to UV space (0,0) to (1,1)
                # The curves are relative to the glyph's origin, so we need to:
                # 1. Translate by bearing to get glyph-relative coordinates
                # 2. Scale by glyph dimensions to get UV coordinates
                # 3. Flip Y axis (FreeType Y goes down, UV Y goes up)
                
                # Transform curve points to UV coordinates
                # Normalize to 0-1 range based on glyph bounding box
                # The glyph's actual bounds are from bearingX to bearingX + width
                # and from bearingY - height to bearingY
                x0 = (curve.x0 - bearingX) / glyphWidth
                y0 = (bearingY - curve.y0) / glyphHeight  # Flip Y: higher Y values in FreeType = lower Y in UV
                x1 = (curve.x1 - bearingX) / glyphWidth
                y1 = (bearingY - curve.y1) / glyphHeight  # Flip Y
                x2 = (curve.x2 - bearingX) / glyphWidth
                y2 = (bearingY - curve.y2) / glyphHeight  # Flip Y
                
                # Debug: Show normalized curve coordinates
                # if j <= startIdx + 2  # Show first 3 curves per glyph
                #     println("  Normalized curve $(j-startIdx+1): p0=($x0, $y0) p1=($x1, $y1) p2=($x2, $y2)")
                # end
                
                # Update the curve with normalized coordinates
                renderer.curves[j] = BufferCurve(x0, y0, x1, y1, x2, y2)
            end
        end
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
    # Assuming viewport size of 800x600 - this should be parameterized later
    left = 0.0f0
    right = 800.0f0
    bottom = 0.0f0
    top = 600.0f0
    near = -1.0f0
    far = 1.0f0
    
    # Column-major orthographic projection matrix (WGSL format)
    ortho = (
        2.0f0 / (right - left), 0.0f0, 0.0f0, 0.0f0,
        0.0f0, 2.0f0 / (top - bottom), 0.0f0, 0.0f0,
        0.0f0, 0.0f0, -2.0f0 / (far - near), 0.0f0,
        -(right + left) / (right - left), -(top + bottom) / (top - bottom), -(far + near) / (far - near), 1.0f0
    )
    
    uniforms = FontUniforms(
        (1.0f0, 1.0f0, 1.0f0, 1.0f0),  # White color
        ortho,  # Proper orthographic projection matrix
        1.0f0,  # Anti-aliasing window size
        0,      # Disable super-sampling AA for now
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
    
    println("Font bind group created successfully")
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
