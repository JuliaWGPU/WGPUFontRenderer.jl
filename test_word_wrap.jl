#!/usr/bin/env julia

# Test script for word wrap functionality with longer content

using WGPUFontRenderer
using WGPUCore
using WGPUCanvas
using GLFW

function test_word_wrap()
    println("=== Word Wrap Test with Long Content ===")
    
    # Create canvas and device
    canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    device = WGPUCore.getDefaultDevice(canvas)
    renderTextureFormat = WGPUCore.getPreferredFormat(canvas)
    
    # Create font renderer
    fontRenderer = createFontRenderer(device, device.queue)
    initializeRenderer(fontRenderer, renderTextureFormat)
    
    # Use much longer text that will definitely exceed the text block bounds
    longText = "The quick brown fox jumps over the lazy dog. This is a longer sentence that should definitely wrap within the blue bounding box if word wrapping is implemented correctly. We need to see how the text flows and whether it respects the container boundaries. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
    
    loadFontData(fontRenderer, longText)
    
    println("✓ Font renderer initialized successfully")
    println("  - Text: \"$(longText[1:min(50, length(longText))])...\"")
    println("  - Text length: $(length(longText)) characters")
    println("  - Vertices: $(length(fontRenderer.vertices))")
    println("  - Curves: $(length(fontRenderer.curves))")
    println("  - Glyphs: $(length(fontRenderer.glyphs))")
    
    # Analyze vertex distribution
    text_quad_boxes = filter(v -> v.bufferIndex == -1, fontRenderer.vertices)
    text_block_boxes = filter(v -> v.bufferIndex == -2, fontRenderer.vertices)
    text_vertices = filter(v -> v.bufferIndex >= 0, fontRenderer.vertices)
    
    println("\n✓ Vertex analysis:")
    println("  - Text quad bounding boxes (red): $(length(text_quad_boxes))")
    println("  - Text block bounding box (blue): $(length(text_block_boxes))")
    println("  - Text vertices: $(length(text_vertices))")
    
    # Setup rendering context
    presentContext = WGPUCore.getContext(canvas)
    WGPUCore.config(presentContext; device=device, format=renderTextureFormat)
    
    println("\n✓ Rendering context configured")
    println("Look for:")
    println("  - Blue rectangle showing text block bounds (10,30) to (400,200)")
    println("  - Red rectangles around each character")
    println("  - Text should extend beyond the blue box if word wrap is NOT working")
    println("  - Text should wrap within the blue box if word wrap IS working")
    println("\nPress ESC to exit, or close the window")
    
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
                println("Frame $frameCount rendered - observing word wrap behavior...")
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
        println("✓ Word wrap test completed")
        println("\nObservations:")
        println("- If text extends horizontally beyond the blue box: Word wrap NOT implemented")
        println("- If text wraps within the blue box: Word wrap IS working")
        println("- Red boxes show individual character positions")
        println("- Total characters that should fit in ~390px wide container")
    end
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    test_word_wrap()
end
