#!/usr/bin/env julia

using WGPUFontRenderer
using WGPUCore
using WGPUCanvas
using GLFW

function test_visual_rendering()
    println("=== Visual Rendering Test ===")
    
    # Create canvas and device
    canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    device = WGPUCore.getDefaultDevice(canvas)
    renderTextureFormat = WGPUCore.getPreferredFormat(canvas)
    
    # Create font renderer
    fontRenderer = createFontRenderer(device, device.queue)
    initializeRenderer(fontRenderer, renderTextureFormat)
    
    # Load font data
    text = "Hello World!"
    loadFontData(fontRenderer, text)
    
    println("✓ Font renderer initialized successfully")
    println("  - Text: \"$text\"")
    println("  - Vertices: $(length(fontRenderer.vertices))")
    println("  - Curves: $(length(fontRenderer.curves))")
    println("  - Glyphs: $(length(fontRenderer.glyphs))")
    
    # Setup rendering context
    presentContext = WGPUCore.getContext(canvas)
    WGPUCore.config(presentContext; device=device, format=renderTextureFormat)
    
    println("\n✓ Rendering context configured")
    println("Press ESC to exit, or close the window")
    
    # Main render loop
    frameCount = 0
    try
        while !GLFW.WindowShouldClose(canvas.windowRef[])
            # Handle ESC key
            if GLFW.GetKey(canvas.windowRef[], 256) == 1  # ESC key
                break
            end
            
            # Get current surface texture
            currentTextureView = WGPUCore.getCurrentTexture(presentContext)
            
            # Create command encoder
            cmdEncoder = WGPUCore.createCommandEncoder(device, "Font Render Encoder")
            
            # Create render pass
            renderPassOptions = [
                WGPUCore.GPUColorAttachments => [
                    :attachments => [
                        WGPUCore.GPUColorAttachment => [
                            :view => currentTextureView,
                            :resolveTarget => C_NULL,
                            :clearValue => (0.1, 0.1, 0.1, 1.0),  # Dark gray background
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
                label = "Font Render Pass",
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
            
            # Print frame info occasionally
            frameCount += 1
            if frameCount % 60 == 0
                println("Frame $frameCount rendered successfully")
            end
            
            # Small delay to prevent excessive CPU usage
            sleep(0.016)  # ~60 FPS
        end
        
    catch e
        println("✗ Rendering error: $e")
        rethrow(e)
    finally
        # Cleanup
        WGPUCore.destroyWindow(canvas)
        println("✓ Visual rendering test completed")
    end
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    test_visual_rendering()
end
