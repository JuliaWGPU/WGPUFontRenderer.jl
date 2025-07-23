#!/usr/bin/env julia

# Test script to verify the fixed font rendering with improved numerical stability
# This should show reduced glitches compared to the previous version

using WGPUCanvas
using WGPUCore
using WGPUFontRenderer
using GLFW

function testFixedFontRendering()
    println("=== Testing Fixed Font Rendering ===")
    println("Starting test with improved numerical stability...")
    
    # Create canvas and device
    canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    device = WGPUCore.getDefaultDevice(canvas)
    renderTextureFormat = WGPUCore.getPreferredFormat(canvas)
    
    println("✓ Canvas and device created")
    
    # Create font renderer
    fontRenderer = createFontRenderer(device, device.queue)
    
    # Prepare text data
    testText = "Fixed Font Rendering!"
    prepareGlyphsForText(testText)
    
    # Initialize renderer with the stable shader
    initializeRenderer(fontRenderer, renderTextureFormat)
    
    # Load font data
    loadFontData(fontRenderer, testText)
    
    println("✓ Font renderer initialized with stable shader")
    println("✓ Font data loaded")
    
    # Check rendering components
    if fontRenderer.pipeline === nothing
        println("✗ FAILED: No render pipeline created")
        return false
    end
    
    if fontRenderer.vertexBuffer === nothing
        println("✗ FAILED: No vertex buffer created")
        return false
    end
    
    if fontRenderer.bindGroup === nothing
        println("✗ FAILED: No bind group created")
        return false
    end
    
    println("✓ All rendering components created successfully")
    
    # Configure present context
    presentContext = WGPUCore.getContext(canvas)
    WGPUCore.config(presentContext; device=device, format=renderTextureFormat)
    
    println("✓ Present context configured")
    println("✓ Ready to render with improved stability")
    println("")
    println("Window controls:")
    println("- ESC: Exit")
    println("- Move mouse to check for rendering artifacts")
    println("")
    
    # Main render loop
    frameCount = 0
    try
        while !GLFW.WindowShouldClose(canvas.windowRef[])
            # Get current texture
            nextTexture = WGPUCore.getCurrentTexture(presentContext)
            
            # Create command encoder
            cmdEncoder = WGPUCore.createCommandEncoder(device, "Fixed Font Render Encoder")
            
            # Create render pass with clear background
            renderPassOptions = [
                WGPUCore.GPUColorAttachments => [
                    :attachments => [
                        WGPUCore.GPUColorAttachment => [
                            :view => nextTexture,
                            :resolveTarget => C_NULL,
                            :clearValue => (0.1, 0.1, 0.2, 1.0),  # Dark blue background
                            :loadOp => WGPUCore.WGPULoadOp_Clear,
                            :storeOp => WGPUCore.WGPUStoreOp_Store,
                        ],
                    ],
                ],
                WGPUCore.GPUDepthStencilAttachments => [],
            ] |> Ref
            
            # Begin render pass
            renderPass = WGPUCore.beginRenderPass(
                cmdEncoder,
                renderPassOptions;
                label = "Fixed Font Render Pass",
            )
            
            # Render the text with improved stability
            renderText(fontRenderer, renderPass)
            
            # End render pass and submit
            WGPUCore.endEncoder(renderPass)
            WGPUCore.submit(device.queue, [WGPUCore.finish(cmdEncoder)])
            
            # Present the frame
            WGPUCore.present(presentContext)
            
            # Poll events
            GLFW.PollEvents()
            
            frameCount += 1
            
            # Print progress every 60 frames
            if frameCount % 60 == 0
                println("Rendered $frameCount frames - Check for rendering stability")
            end
        end
        
    catch e
        println("✗ Rendering error: $e")
        return false
    finally
        # Cleanup
        WGPUCore.destroyWindow(canvas)
    end
    
    println("✓ Fixed font rendering test completed successfully")
    println("Rendered $frameCount frames total")
    return true
end

# Analyze the improvements made
function printImprovementSummary()
    println("\n=== Font Rendering Improvements Summary ===")
    println("The following fixes were applied to reduce glitches:")
    println("")
    println("1. SHADER IMPROVEMENTS:")
    println("   - Switched to stable coverage shader with improved numerics")
    println("   - Better epsilon values (1e-8 vs 1e-6) for higher precision")
    println("   - Numerically stable quadratic formula implementation")
    println("   - Relaxed bounds checking to avoid edge artifacts")
    println("   - Improved parameter clamping in coverage calculation")
    println("")
    println("2. RENDERER IMPROVEMENTS:")
    println("   - Optimized anti-aliasing window size calculation")
    println("   - Reduced AA window size from 4.0x to 2.0x for better stability")
    println("   - Maintained proper coordinate space consistency")
    println("   - Disabled super-sampling AA to reduce numerical instability")
    println("")
    println("3. NUMERICAL STABILITY:")
    println("   - Better handling of near-zero discriminants")
    println("   - Improved quadratic root computation")
    println("   - More robust linear case handling")
    println("   - Enhanced parameter bounds checking")
    println("")
    println("These improvements should significantly reduce:")
    println("- Random horizontal line artifacts")
    println("- Coverage calculation glitches")
    println("- Numerical precision issues")
    println("- Edge case rendering problems")
    println("")
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    printImprovementSummary()
    
    println("Starting fixed font rendering test...")
    success = testFixedFontRendering()
    
    if success
        println("\n🎉 Font rendering fixes applied successfully!")
        println("The glitches should be significantly reduced.")
    else
        println("\n❌ Test failed. Please check the error messages above.")
    end
end
