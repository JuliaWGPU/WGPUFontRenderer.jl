#!/usr/bin/env julia

using WGPUCanvas
using WGPUCore
using WGPUFontRenderer
using GLFW

# Create a simple test with solid color rectangles instead of complex font rendering
function test_simple_solid_rendering()
    println("Testing solid color rendering...")
    
    # Create canvas and device
    canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    device = WGPUCore.getDefaultDevice(canvas)
    renderTextureFormat = WGPUCore.getPreferredFormat(canvas)
    
    # Create font renderer
    fontRenderer = createFontRenderer(device, device.queue)
    
    # Prepare text data
    text = "Hello GPU Font Rendering!"
    prepareGlyphsForText(text)
    
    # Initialize renderer
    initializeRenderer(fontRenderer, renderTextureFormat)
    
    # Load font data
    loadFontData(fontRenderer, text)
    
    println("Font renderer initialized successfully")
    
    # Now test rendering with a simple modification
    # Let's create a simple shader that just renders solid colored rectangles
    simple_vertex_shader = """
    struct VertexInput {
        @location(0) position: vec2<f32>,
        @location(1) uv: vec2<f32>,
        @location(2) bufferIndex: i32,
    }
    
    struct VertexOutput {
        @builtin(position) position: vec4<f32>,
        @location(0) uv: vec2<f32>,
    }
    
    @vertex
    fn vs_main(input: VertexInput) -> VertexOutput {
        var output: VertexOutput;
        output.position = vec4<f32>(input.position, 0.0, 1.0);
        output.uv = input.uv;
        return output;
    }
    """
    
    simple_fragment_shader = """
    struct FragmentInput {
        @location(0) uv: vec2<f32>,
    }
    
    @fragment
    fn fs_main(input: FragmentInput) -> @location(0) vec4<f32> {
        // Simple solid color based on UV coordinates
        return vec4<f32>(1.0, 0.0, 0.0, 1.0);  // Red color
    }
    """
    
    # Create new shaders
    println("Creating simple test shaders...")
    
    vertexShaderSource = Vector{UInt8}(simple_vertex_shader)
    vertexShaderCode = WGPUCore.loadWGSL(vertexShaderSource)
    testVertexShader = WGPUCore.createShaderModule(
        device,
        "Test Vertex Shader",
        vertexShaderCode.shaderModuleDesc,
        nothing,
        nothing
    )
    
    fragmentShaderSource = Vector{UInt8}(simple_fragment_shader)
    fragmentShaderCode = WGPUCore.loadWGSL(fragmentShaderSource)
    testFragmentShader = WGPUCore.createShaderModule(
        device,
        "Test Fragment Shader",
        fragmentShaderCode.shaderModuleDesc,
        nothing,
        nothing
    )
    
    # Create simple pipeline (no bind groups needed)
    bindingLayouts = []
    bindings = []
    
    pipelineLayout = WGPUCore.createPipelineLayout(
        device,
        "Simple Pipeline Layout",
        bindingLayouts,
        bindings
    )
    
    renderpipelineOptions = [
        WGPUCore.GPUVertexState => [
            :_module => testVertexShader,
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
            :_module => testFragmentShader,
            :entryPoint => "fs_main",
            :targets => [
                WGPUCore.GPUColorTargetState => [
                    :format => renderTextureFormat,
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
    
    testPipeline = WGPUCore.createRenderPipeline(
        device,
        pipelineLayout,
        renderpipelineOptions;
        label = "Simple Test Pipeline"
    )
    
    println("Simple test pipeline created")
    
    # Override the original pipeline
    fontRenderer.pipeline = testPipeline
    
    println("Press ESC to exit")
    
    # Simple render loop
    presentContext = WGPUCore.getContext(canvas)
    WGPUCore.config(presentContext; device = device, format = renderTextureFormat)
    
    try
        while !GLFW.WindowShouldClose(canvas.windowRef[])
            nextTexture = WGPUCore.getCurrentTexture(presentContext)
            cmdEncoder = WGPUCore.createCommandEncoder(device, "Simple Test Encoder")
            
            renderPassOptions = [
                WGPUCore.GPUColorAttachments => [
                    :attachments => [
                        WGPUCore.GPUColorAttachment => [
                            :view => nextTexture,
                            :resolveTarget => C_NULL,
                            :clearValue => (0.0, 0.0, 0.0, 1.0),
                            :loadOp => WGPUCore.WGPULoadOp_Clear,
                            :storeOp => WGPUCore.WGPUStoreOp_Store
                        ]
                    ]
                ],
                WGPUCore.GPUDepthStencilAttachments => []
            ] |> Ref
            
            renderPass = WGPUCore.beginRenderPass(cmdEncoder, renderPassOptions; label = "Simple Test Pass")
            
            # Set pipeline and vertex buffer
            WGPUCore.setPipeline(renderPass, testPipeline)
            if fontRenderer.vertexBuffer !== nothing
                WGPUCore.setVertexBuffer(renderPass, 0, fontRenderer.vertexBuffer, 0, fontRenderer.vertexBuffer.size)
                vertexCount = length(fontRenderer.vertices)
                WGPUCore.draw(renderPass, vertexCount; instanceCount = 1, firstVertex = 0, firstInstance = 0)
            end
            
            WGPUCore.endEncoder(renderPass)
            WGPUCore.submit(device.queue, [WGPUCore.finish(cmdEncoder)])
            WGPUCore.present(presentContext)
            
            GLFW.PollEvents()
            
            # Handle exit
            if GLFW.GetKey(canvas.windowRef[], GLFW.KEY_ESCAPE) == GLFW.PRESS
                break
            end
        end
    finally
        WGPUCore.destroyWindow(canvas)
    end
    
    println("Test completed")
end

# Run the test
test_simple_solid_rendering()
