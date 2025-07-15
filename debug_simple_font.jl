# Debug simple font rendering - bypassing complex curve evaluation
# This will render a simple colored quad instead of vector curves

using WGPUCore
using WGPUCanvas
using WGPUFontRenderer
using GLFW

# Simple shader that just renders a solid color for debugging
function getDebugVertexShader()::String
    return """
struct VertexInput {
    @location(0) position: vec2<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) bufferIndex: i32,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) bufferIndex: i32,
}

@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;
    
    // Direct pass-through - no projection matrix
    output.position = vec4<f32>(input.position, 0.0, 1.0);
    output.uv = input.uv;
    output.bufferIndex = input.bufferIndex;
    
    return output;
}
"""
end

function getDebugFragmentShader()::String
    return """
struct FragmentInput {
    @location(0) uv: vec2<f32>,
    @location(1) bufferIndex: i32,
}

@fragment
fn fs_main(input: FragmentInput) -> @location(0) vec4<f32> {
    // Simple debug: render white with some transparency based on UV
    // This will show us if the vertex positions are working correctly
    let alpha = 1.0 - (input.uv.x * 0.3 + input.uv.y * 0.3);
    return vec4<f32>(1.0, 1.0, 1.0, alpha);
}
"""
end

mutable struct DebugFontApp
    canvas::WGPUCore.AbstractWGPUCanvas
    device::WGPUCore.GPUDevice
    queue::WGPUCore.GPUQueue
    pipeline::Union{WGPUCore.GPURenderPipeline, Nothing}
    vertexBuffer::Union{WGPUCore.GPUBuffer, Nothing}
    vertices::Vector{BufferVertex}
    
    function DebugFontApp()
        new()
    end
end

function init_debug_app(app::DebugFontApp)
    # Initialize WGPU
    app.canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    app.device = WGPUCore.getDefaultDevice(app.canvas)
    app.queue = app.device.queue
    
    # Get surface format
    surfaceFormat = WGPUCore.getPreferredFormat(app.canvas)
    
    # Configure context
    presentContext = WGPUCore.getContext(app.canvas)
    WGPUCore.config(presentContext; device=app.device, format=surfaceFormat)
    
    # Create debug shaders
    vertexShaderSource = Vector{UInt8}(getDebugVertexShader())
    vertexShaderCode = WGPUCore.loadWGSL(vertexShaderSource)
    vertexShader = WGPUCore.createShaderModule(
        app.device,
        "Debug Font Vertex Shader",
        vertexShaderCode.shaderModuleDesc,
        nothing,
        nothing
    )
    
    fragmentShaderSource = Vector{UInt8}(getDebugFragmentShader())
    fragmentShaderCode = WGPUCore.loadWGSL(fragmentShaderSource)
    fragmentShader = WGPUCore.createShaderModule(
        app.device,
        "Debug Font Fragment Shader",
        fragmentShaderCode.shaderModuleDesc,
        nothing,
        nothing
    )
    
    # Create simple pipeline layout (no bind groups needed)
    pipelineLayout = WGPUCore.createPipelineLayout(
        app.device,
        "Debug Font Pipeline Layout",
        [],  # No bind group layouts
        []   # No bind group entries
    )
    
    # Create render pipeline
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

    app.pipeline = WGPUCore.createRenderPipeline(
        app.device,
        pipelineLayout,
        renderPipelineOptions;
        label = "Debug Font Render Pipeline"
    )
    
    # Create simple vertex data for "Hello" text
    generate_debug_vertices(app)
    
    # Create vertex buffer
    if !isempty(app.vertices)
        vertexBytes = Vector{UInt8}(undef, sizeof(BufferVertex) * length(app.vertices))
        ptr = Ptr{BufferVertex}(pointer(vertexBytes))
        unsafe_copyto!(ptr, pointer(app.vertices), length(app.vertices))
        
        (app.vertexBuffer, _) = WGPUCore.createBufferWithData(
            app.device,
            "Debug Vertex Buffer",
            vertexBytes,
            ["Vertex", "CopyDst"]
        )
    end
    
    return app
end

function generate_debug_vertices(app::DebugFontApp)
    app.vertices = BufferVertex[]
    
    # Create simple quads for each letter position
    text = "Hello"
    scale = 0.1f0
    xOffset = -0.5f0  # Start more to the left
    yOffset = 0.0f0
    
    for (i, char) in enumerate(text)
        # Create a simple quad for each character
        width = 0.1f0 * scale
        height = 0.15f0 * scale
        
        x1 = xOffset
        y1 = yOffset - height/2
        x2 = xOffset + width
        y2 = yOffset + height/2
        
        # First triangle: top-left, bottom-left, top-right
        push!(app.vertices, BufferVertex(x1, y2, 0.0f0, 0.0f0, Int32(i)))
        push!(app.vertices, BufferVertex(x1, y1, 0.0f0, 1.0f0, Int32(i)))
        push!(app.vertices, BufferVertex(x2, y2, 1.0f0, 0.0f0, Int32(i)))
        
        # Second triangle: bottom-left, bottom-right, top-right
        push!(app.vertices, BufferVertex(x1, y1, 0.0f0, 1.0f0, Int32(i)))
        push!(app.vertices, BufferVertex(x2, y1, 1.0f0, 1.0f0, Int32(i)))
        push!(app.vertices, BufferVertex(x2, y2, 1.0f0, 0.0f0, Int32(i)))
        
        # Advance position
        xOffset += width + 0.02f0
    end
    
    println("Generated ", length(app.vertices), " debug vertices")
end

function render_debug_frame(app::DebugFontApp)
    try
        # Get current surface texture
        presentContext = WGPUCore.getContext(app.canvas)
        currentTextureView = WGPUCore.getCurrentTexture(presentContext)
        
        # Create command encoder
        cmdEncoder = WGPUCore.createCommandEncoder(app.device, "Debug Font Demo Encoder")
        
        # Create render pass
        renderPassOptions = [
            WGPUCore.GPUColorAttachments => [
                :attachments => [
                    WGPUCore.GPUColorAttachment => [
                        :view => currentTextureView,
                        :resolveTarget => C_NULL,
                        :clearValue => (0.2, 0.2, 0.2, 1.0),  # Dark gray background
                        :loadOp => WGPUCore.WGPULoadOp_Clear,
                        :storeOp => WGPUCore.WGPUStoreOp_Store,
                    ],
                ],
            ],
            WGPUCore.GPUDepthStencilAttachments => [],
        ]
        
        # Begin render pass
        renderPass = WGPUCore.beginRenderPass(
            cmdEncoder,
            renderPassOptions |> Ref;
            label = "Debug Font Demo Render Pass",
        )
        
        # Set pipeline
        WGPUCore.setPipeline(renderPass, app.pipeline)
        
        # Set vertex buffer
        if app.vertexBuffer !== nothing
            WGPUCore.setVertexBuffer(renderPass, 0, app.vertexBuffer, 0, app.vertexBuffer.size)
            
            # Draw vertices
            vertexCount = length(app.vertices)
            WGPUCore.draw(renderPass, vertexCount; instanceCount = 1, firstVertex = 0, firstInstance = 0)
        end
        
        # End render pass and submit
        WGPUCore.endEncoder(renderPass)
        WGPUCore.submit(app.queue, [WGPUCore.finish(cmdEncoder)])
        
        # Present the frame
        WGPUCore.present(presentContext)
        
    catch e
        @warn "Debug rendering error: $e"
    end
end

function run_debug_demo()
    println("Starting Debug Font Renderer Demo...")
    
    # Initialize application
    app = DebugFontApp()
    init_debug_app(app)
    
    println("Debug font renderer initialized successfully")
    println("Press ESC or close window to exit")
    
    # Main render loop
    try
        while true
            # Check if window should close
            if GLFW.WindowShouldClose(app.canvas.windowRef[])
                break
            end
            
            # Check for ESC key
            if GLFW.GetKey(app.canvas.windowRef[], 256) == 1  # ESC key
                break
            end
            
            # Render frame
            render_debug_frame(app)
            
            # Poll events
            GLFW.PollEvents()
            
            # Small delay to prevent excessive CPU usage
            sleep(0.016)  # ~60 FPS
        end
    catch e
        println("Debug rendering loop interrupted: ", e)
    finally
        # Cleanup
        WGPUCore.destroyWindow(app.canvas)
        println("Debug demo completed")
    end
end

# Run the demo
run_debug_demo()
