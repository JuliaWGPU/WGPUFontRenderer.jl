#!/usr/bin/env julia

using WGPUCanvas
using WGPUCore
using WGPUFontRenderer
using GLFW

# Test font rendering with large scale
function test_font_rendering_large_scale()
    println("Testing font rendering with large scale...")
    
    # Create canvas and device
    canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    device = WGPUCore.getDefaultDevice(canvas)
    renderTextureFormat = WGPUCore.getPreferredFormat(canvas)
    
    # Create font renderer
    fontRenderer = createFontRenderer(device, device.queue)
    
    # Prepare text data - use short text for visibility
    text = "Hi"
    prepareGlyphsForText(text)
    
    # Initialize renderer
    initializeRenderer(fontRenderer, renderTextureFormat)
    
    # Load font data
    loadFontData(fontRenderer, text)
    
    println("Font renderer initialized successfully")
    println("Number of vertices: ", length(fontRenderer.vertices))
    
    # Print vertex info for debugging
    for (i, vertex) in enumerate(fontRenderer.vertices)
        println("Vertex $i: pos=($(vertex.x), $(vertex.y)), uv=($(vertex.u), $(vertex.v)), bufferIndex=$(vertex.bufferIndex)")
    end
    
    println("Press ESC to exit")
    
    # Simple render loop using actual font renderer
    presentContext = WGPUCore.getContext(canvas)
    WGPUCore.config(presentContext; device = device, format = renderTextureFormat)
    
    try
        while !GLFW.WindowShouldClose(canvas.windowRef[])
            nextTexture = WGPUCore.getCurrentTexture(presentContext)
            cmdEncoder = WGPUCore.createCommandEncoder(device, "Font Test Encoder")
            
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
            
            renderPass = WGPUCore.beginRenderPass(cmdEncoder, renderPassOptions; label = "Font Test Pass")
            
            # Use the actual font renderer
            renderText(fontRenderer, renderPass)
            
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
test_font_rendering_large_scale()
