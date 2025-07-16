#!/usr/bin/env julia

using WGPUCore
using WGPUCanvas
using WGPUFontRenderer
using GLFW

function test_debug_simple()
    println("Testing simple debug font rendering...")
    
    # Create canvas and device
    canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    device = WGPUCore.getDefaultDevice(canvas)
    renderTextureFormat = WGPUCore.getPreferredFormat(canvas)
    
    # Create font renderer
    fontRenderer = createFontRenderer(device, device.queue)
    
    # Initialize renderer
    initializeRenderer(fontRenderer, renderTextureFormat)
    
    # Use single character for debugging
    testText = "A"
    
    # Load font data
    loadFontData(fontRenderer, testText)
    
    # Configure context
    presentContext = WGPUCore.getContext(canvas)
    WGPUCore.config(presentContext; device=device, format=renderTextureFormat)
    
    println("Debug renderer initialized successfully")
    println("Text to render: \"$testText\"")
    println("Look for colored rectangles (Green for 'A' at index 0)")
    println("Press ESC to exit, or close window")
    
    # Simple render loop
    try
        while !GLFW.WindowShouldClose(canvas.windowRef[])
            # Get current texture
            currentTextureView = WGPUCore.getCurrentTexture(presentContext)
            
            # Create command encoder
            cmdEncoder = WGPUCore.createCommandEncoder(device, "Debug Encoder")
            
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
                label = "Debug Render Pass",
            )
            
            # Render the text
            renderText(fontRenderer, renderPass)
            
            # End render pass and submit
            WGPUCore.endEncoder(renderPass)
            WGPUCore.submit(device.queue, [WGPUCore.finish(cmdEncoder)])
            
            # Present the frame
            WGPUCore.present(presentContext)
            
            # Poll events
            GLFW.PollEvents()
            
            # Handle ESC key - just close window to exit
            
            # Small delay
            sleep(0.016)  # ~60 FPS
        end
    catch e
        println("Rendering error: $e")
    finally
        # Cleanup
        WGPUCore.destroyWindow(canvas)
        println("Debug test completed")
    end
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    test_debug_simple()
end
