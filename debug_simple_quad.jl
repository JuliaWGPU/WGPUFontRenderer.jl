#!/usr/bin/env julia

using WGPUCanvas
using WGPUCore
using WGPUFontRenderer
using GLFW

function test_simple_quad()
    println("Testing simple quad rendering...")
    
    # Create canvas and device
    canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    device = WGPUCore.getDefaultDevice(canvas)
    renderTextureFormat = WGPUCore.getPreferredFormat(canvas)
    
    # Create simple shaders that just render solid color
    simple_vertex_shader = """
    struct VertexInput {
        @location(0) position: vec2<f32>,
        @location(1) uv: vec2<f32>,
        @location(2) bufferIndex: i32,
    }
    
    struct VertexOutput {
        @builtin(position) position: vec4<f32>,
        @location(0) color: vec3<f32>,
    }
    
    @vertex
    fn vs_main(input: VertexInput) -> VertexOutput {
        var output: VertexOutput;
        output.position = vec4<f32>(input.position, 0.0, 1.0);
        // Use UV to color the output
        output.color = vec3<f32>(input.uv, 0.5);
        return output;
    }
    """
    
    simple_fragment_shader = """
    struct FragmentInput {
        @location(0) color: vec3<f32>,
    }
    
    @fragment
    fn fs_main(input: FragmentInput) -> @location(0) vec4<f32> {
        return vec4<f32>(input.color, 1.0);
    }
    """
    
    # Create shaders
    vertexShaderSource = Vector{UInt8}(simple_vertex_shader)
    vertexShaderCode = WGPUCore.loadWGSL(vertexShaderSource)
    testVertexShader = WGPUCore.createShaderModule(
        device,
        "Simple Vertex Shader",
        vertexShaderCode.shaderModuleDesc,
        nothing,
        nothing
    )
    
    fragmentShaderSource = Vector{UInt8}(simple_fragment_shader)
    fragmentShaderCode = WGPUCore.loadWGSL(fragmentShaderSource)
    testFragmentShader = WGPUCore.createShaderModule(
        device,
        "Simple Fragment Shader",
        fragmentShaderCode.shaderModuleDesc,
        nothing,
        nothing
    )
    
    # Create simple pipeline
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
    
    # Create vertex buffer with simple quad
    vertices = [
        # First triangle
        BufferVertex(-0.5f0, -0.5f0, 0.0f0, 0.0f0, 0),  # bottom-left
        BufferVertex(0.5f0, -0.5f0, 1.0f0, 0.0f0, 0),   # bottom-right
        BufferVertex(-0.5f0, 0.5f0, 0.0f0, 1.0f0, 0),   # top-left
        
        # Second triangle
        BufferVertex(0.5f0, -0.5f0, 1.0f0, 0.0f0, 0),   # bottom-right
        BufferVertex(0.5f0, 0.5f0, 1.0f0, 1.0f0, 0),    # top-right
        BufferVertex(-0.5f0, 0.5f0, 0.0f0, 1.0f0, 0),   # top-left
    ]
    
    # Create vertex buffer
    vertexBytes = Vector{UInt8}(undef, sizeof(BufferVertex) * length(vertices))
    ptr = Ptr{BufferVertex}(pointer(vertexBytes))
    unsafe_copyto!(ptr, pointer(vertices), length(vertices))
    
    (vertexBuffer, _) = WGPUCore.createBufferWithData(
        device,
        "Test Vertex Buffer",
        vertexBytes,
        ["Vertex", "CopyDst"]
    )
    
    println("Simple quad test pipeline created")
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
            WGPUCore.setVertexBuffer(renderPass, 0, vertexBuffer, 0, vertexBuffer.size)
            WGPUCore.draw(renderPass, length(vertices); instanceCount = 1, firstVertex = 0, firstInstance = 0)
            
            WGPUCore.endEncoder(renderPass)
            WGPUCore.submit(device.queue, [WGPUCore.finish(cmdEncoder)])
            WGPUCore.present(presentContext)
            
            GLFW.PollEvents()
            
            # Handle exit
            if GLFW.GetKey(canvas.windowRef[], 256) == 1  # ESCAPE key
                break
            end
        end
    finally
        WGPUCore.destroyWindow(canvas)
    end
    
    println("Test completed")
end

# Run the test
test_simple_quad()
