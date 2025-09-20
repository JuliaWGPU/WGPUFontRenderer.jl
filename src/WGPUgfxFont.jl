# WGPUgfx Font Integration - Direct inclusion in WGPUFontRenderer module

mutable struct FontRenderableUI <: WGPUgfx.RenderableUI
    # WGPUgfx required fields
    gpuDevice
    topology
    vertexData
    colorData
    indexData
    uvData
    uniformData
    uniformBuffer
    indexBuffer
    vertexBuffer
    textureData
    texture
    textureView
    sampler
    pipelineLayouts
    renderPipelines
    cshaders
    
    # Font renderer specific fields
    fontRenderer::Any  # Using Any to avoid circular dependency issues
    text::String
    position::Vector{Float32}  # [x, y] position
    scale::Float32
    color::Vector{Float32}     # [r, g, b, a] color
end

function defaultFontRenderableUI(device::WGPUCore.GPUDevice, queue::WGPUCore.GPUQueue, text::String="Hello World";
                                 position=[10.0f0, 50.0f0], scale=1.0f0, color=[0.0f0, 0.0f0, 0.0f0, 1.0f0])
    # Create the font renderer
    fontRenderer = createFontRenderer(device, queue)
    
    # Initialize with a default surface format (will be updated when prepared)
    surfaceFormat = WGPUCore.WGPUTextureFormat_BGRA8UnormSrgb
    initializeRenderer(fontRenderer, surfaceFormat)
    
    # Load font data for the text
    loadFontData(fontRenderer, text)
    
    # Set initial position
    setPosition(fontRenderer, text, position[1], position[2])
    
    # Create a simple quad for the background (optional)
    vertexData = zeros(Float32, 4, 6)  # Empty for now, will be updated during rendering
    colorData = zeros(Float32, 4, 6)   # Empty for now
    indexData = zeros(UInt32, 1, 6)    # Empty for now
    uvData = zeros(Float32, 2, 6)      # Empty for now
    textureData = nothing
    
    FontRenderableUI(
        nothing,        # gpuDevice (will be set during prepare)
        "TriangleList", # topology
        vertexData,
        colorData,
        indexData,
        uvData,
        nothing,        # uniformData
        nothing,        # uniformBuffer
        nothing,        # indexBuffer
        nothing,        # vertexBuffer
        textureData,
        nothing,        # texture
        nothing,        # textureView
        nothing,        # sampler
        Dict(),         # pipelineLayouts
        Dict(),         # renderPipelines
        Dict(),         # cshaders
        fontRenderer,   # fontRenderer
        text,           # text
        position,       # position
        scale,          # scale
        color           # color
    )
end

# Required RenderableUI interface methods
function WGPUgfx.isTextureDefined(f::FontRenderableUI)
    return f.textureData !== nothing
end

function WGPUgfx.isNormalDefined(f::FontRenderableUI)
    return false  # Font rendering doesn't use normals
end

function WGPUgfx.prepareObject(gpuDevice, fontObj::FontRenderableUI)
    # Store the GPU device
    fontObj.gpuDevice = gpuDevice
    
    # Update the font renderer's buffers
    createGPUBuffers(fontObj.fontRenderer)
    createBindGroup(fontObj.fontRenderer)
    
    # Create uniform buffer for basic transformation
    uniformData = Matrix{Float32}(I, 4, 4)  # Identity matrix
    (uniformBuffer, _) = WGPUCore.createBufferWithData(
        gpuDevice,
        "Font Uniform Buffer",
        uniformData,
        ["Uniform", "CopyDst", "CopySrc"]
    )
    fontObj.uniformData = uniformData
    fontObj.uniformBuffer = uniformBuffer
    
    # Create vertex and index buffers (empty placeholders since we use our own rendering)
    vertexData = zeros(Float32, 4 * 6)  # 6 vertices, 4 components each
    indexData = collect(UInt32(0):UInt32(5))  # Simple indices
    
    (vertexBuffer, _) = WGPUCore.createBufferWithData(
        gpuDevice,
        "Font Vertex Buffer",
        vertexData,
        ["Vertex", "CopySrc"]
    )
    
    (indexBuffer, _) = WGPUCore.createBufferWithData(
        gpuDevice,
        "Font Index Buffer",
        indexData,
        "Index"
    )
    
    fontObj.vertexBuffer = vertexBuffer
    fontObj.indexBuffer = indexBuffer
    
    return fontObj
end

function WGPUgfx.preparePipeline(gpuDevice, renderer, fontObj::FontRenderableUI, camera; binding=0)
    # For font rendering, we'll use the existing font renderer pipeline
    # but we need to store the pipeline layout for WGPUgfx compatibility
    scene = renderer.scene
    uniformBuffer = fontObj.uniformBuffer
    
    # BindingLayouts - simplified for font rendering
    bindingLayouts = [
        WGPUCore.WGPUBufferEntry => [
            :binding => binding,
            :visibility => ["Vertex", "Fragment"],
            :type => "Uniform"
        ]
    ]
    
    # Bindings
    bindings = [
        WGPUCore.GPUBuffer => [
            :binding => binding,
            :buffer => uniformBuffer,
            :offset => 0,
            :size => uniformBuffer.size
        ]
    ]
    
    pipelineLayout = WGPUCore.createPipelineLayout(
        gpuDevice,
        "Font Pipeline Layout",
        bindingLayouts,
        bindings
    )
    fontObj.pipelineLayouts[camera.id] = pipelineLayout
    
    # Store reference to the existing font renderer pipeline
    # This is a placeholder since we'll use our own rendering
    fontObj.renderPipelines[camera.id] = nothing
end

function WGPUgfx.render(renderPass::WGPUCore.GPURenderPassEncoder, renderPassOptions, fontObj::FontRenderableUI, camId::Int)
    # Use our font renderer to render the text
    if fontObj.fontRenderer.pipeline !== nothing && fontObj.fontRenderer.bindGroup !== nothing
        renderText(fontObj.fontRenderer, renderPass)
    end
end

# Font-specific methods
function setText!(fontObj::FontRenderableUI, text::String)
    fontObj.text = text
    loadFontData(fontObj.fontRenderer, text)
    setPosition(fontObj.fontRenderer, text, fontObj.position[1], fontObj.position[2])
    createGPUBuffers(fontObj.fontRenderer)
    createBindGroup(fontObj.fontRenderer)
end

function setPosition!(fontObj::FontRenderableUI, x::Float32, y::Float32)
    fontObj.position = [x, y]
    setPosition(fontObj.fontRenderer, fontObj.text, x, y)
    createGPUBuffers(fontObj.fontRenderer)
    createBindGroup(fontObj.fontRenderer)
end

function animatePosition!(fontObj::FontRenderableUI, time::Float32)
    # Simple animation example - move text in a circle
    radius = 50.0f0
    x = fontObj.position[1] + radius * cos(time)
    y = fontObj.position[2] + radius * sin(time)
    setPosition!(fontObj, x, y)
end