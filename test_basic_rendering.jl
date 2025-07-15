# Test basic rendering with larger text to check visibility

using WGPUCore
using WGPUCanvas
using WGPUFontRenderer
using GLFW

function test_basic_render()
    println("Testing basic font rendering...")
    
    # Create a simple app
    canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    device = WGPUCore.getDefaultDevice(canvas)
    queue = device.queue
    
    # Get surface format
    surfaceFormat = WGPUCore.getPreferredFormat(canvas)
    println("Surface format: $surfaceFormat")
    
    # Configure context
    presentContext = WGPUCore.getContext(canvas)
    WGPUCore.config(presentContext; device=device, format=surfaceFormat)
    
    # Create font renderer
    fontRenderer = createFontRenderer(device, queue)
    initializeRenderer(fontRenderer, surfaceFormat)
    
    # Use a shorter text for testing
    testText = "Hi"
    println("Test text: '$testText'")
    
    # Load font data
    loadFontData(fontRenderer, testText)
    
    # Print vertex information
    println("Number of vertices: $(length(fontRenderer.vertices))")
    if !isempty(fontRenderer.vertices)
        println("First vertex: $(fontRenderer.vertices[1])")
        println("Last vertex: $(fontRenderer.vertices[end])")
        
        # Calculate bounds
        minX = minimum(v.x for v in fontRenderer.vertices)
        maxX = maximum(v.x for v in fontRenderer.vertices)
        minY = minimum(v.y for v in fontRenderer.vertices)
        maxY = maximum(v.y for v in fontRenderer.vertices)
        println("Vertex bounds: X[$minX to $maxX], Y[$minY to $maxY]")
    end
    
    # Simple render loop
    println("Starting render loop (press ESC to exit)...")
    frameCount = 0
    
    try
        while true
            # Check if window should close
            if GLFW.WindowShouldClose(canvas.windowRef[])
                break
            end
            
            # Check for ESC key
            if GLFW.GetKey(canvas.windowRef[], 256) == 1  # ESC key
                break
            end
            
            # Get current surface texture
            currentTextureView = WGPUCore.getCurrentTexture(presentContext)
            
            # Create command encoder
            cmdEncoder = WGPUCore.createCommandEncoder(device, "Test Encoder")
            
            # Create render pass
            renderPassOptions = [
                WGPUCore.GPUColorAttachments => [
                    :attachments => [
                        WGPUCore.GPUColorAttachment => [
                            :view => currentTextureView,
                            :resolveTarget => C_NULL,
                            :clearValue => (0.0, 0.0, 0.0, 1.0),  # Black background
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
                label = "Test Render Pass",
            )
            
            # Render the text
            renderText(fontRenderer, renderPass)
            
            # End render pass and submit
            WGPUCore.endEncoder(renderPass)
            WGPUCore.submit(queue, [WGPUCore.finish(cmdEncoder)])
            
            # Present the frame
            WGPUCore.present(presentContext)
            
            # Poll events
            GLFW.PollEvents()
            
            frameCount += 1
            if frameCount % 60 == 0
                println("Rendered $frameCount frames")
            end
            
            # Small delay
            sleep(0.016)  # ~60 FPS
        end
    catch e
        println("Error: $e")
    finally
        # Cleanup
        WGPUCore.destroyWindow(canvas)
        println("Test completed")
    end
end

# Run the test
test_basic_render()
