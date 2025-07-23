#!/usr/bin/env julia

# Comparison test to show the difference between the old and new font rendering
# Run this to switch between stable and original shaders to see the improvement

using WGPUCanvas
using WGPUCore
using WGPUFontRenderer
using GLFW

# Override the fragment shader selection for comparison
global use_stable_shader = true

# Modified getFragmentShader function for comparison
function WGPUFontRenderer.getFragmentShader()::String
    if use_stable_shader
        println("Using STABLE shader with improved numerics...")
        return WGPUFontRenderer.getStableCoverageShader()
    else
        println("Using ORIGINAL shader (may show glitches)...")
        return WGPUFontRenderer.getComplexFragmentShader()
    end
end

function compareRendering()
    println("=== Font Rendering Comparison Tool ===")
    println("This tool allows you to compare the old vs new font rendering")
    println("")
    
    while true
        println("Select rendering mode:")
        println("1. Stable shader (fixed version)")
        println("2. Original shader (may show glitches)")
        println("3. Exit")
        print("Choice (1-3): ")
        
        choice = readline()
        
        if choice == "1"
            global use_stable_shader = true
            testRendering("STABLE (Fixed)")
        elseif choice == "2"
            global use_stable_shader = false
            testRendering("ORIGINAL (May have glitches)")
        elseif choice == "3"
            println("Exiting comparison tool...")
            break
        else
            println("Invalid choice. Please enter 1, 2, or 3.")
        end
    end
end

function testRendering(mode::String)
    println("\n=== Testing $mode Rendering ===")
    
    # Create canvas and device
    canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    device = WGPUCore.getDefaultDevice(canvas)
    renderTextureFormat = WGPUCore.getPreferredFormat(canvas)
    
    # Create font renderer
    fontRenderer = createFontRenderer(device, device.queue)
    
    # Prepare complex text that might show glitches
    testText = "The quick brown fox jumps over the lazy dog!"
    prepareGlyphsForText(testText)
    
    # Initialize renderer
    initializeRenderer(fontRenderer, renderTextureFormat)
    loadFontData(fontRenderer, testText)
    
    println("✓ Font renderer initialized with $mode shader")
    
    # Configure present context
    presentContext = WGPUCore.getContext(canvas)
    WGPUCore.config(presentContext; device=device, format=renderTextureFormat)
    
    println("✓ Window created - Look for rendering artifacts")
    println("Controls:")
    println("- ESC: Close window and return to menu")
    println("- Move mouse around to test different rendering conditions")
    if !use_stable_shader
        println("- Watch for horizontal lines, glitches, or coverage errors")
    else
        println("- Should show stable, clean font rendering")
    end
    println("")
    
    # Render loop
    frameCount = 0
    try
        while !GLFW.WindowShouldClose(canvas.windowRef[])
            # Get current texture
            nextTexture = WGPUCore.getCurrentTexture(presentContext)
            
            # Create command encoder
            cmdEncoder = WGPUCore.createCommandEncoder(device, "$mode Render Encoder")
            
            # Create render pass
            renderPassOptions = [
                WGPUCore.GPUColorAttachments => [
                    :attachments => [
                        WGPUCore.GPUColorAttachment => [
                            :view => nextTexture,
                            :resolveTarget => C_NULL,
                            :clearValue => (0.1, 0.1, 0.2, 1.0),
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
                label = "$mode Render Pass",
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
            
            frameCount += 1
        end
        
    catch e
        println("✗ Rendering error: $e")
    finally
        # Cleanup
        WGPUCore.destroyWindow(canvas)
    end
    
    println("✓ $mode rendering test completed")
    println("Rendered $frameCount frames")
    println("")
end

function printComparisonInfo()
    println("=== Rendering Comparison Information ===")
    println("")
    println("STABLE SHADER IMPROVEMENTS:")
    println("• Uses numerically stable quadratic formula")
    println("• Better epsilon values (1e-8) for higher precision")
    println("• Improved bounds checking to avoid edge artifacts")
    println("• More robust handling of near-zero discriminants")
    println("• Optimized anti-aliasing window size")
    println("")
    println("ISSUES THE STABLE SHADER FIXES:")
    println("• Random horizontal line artifacts")
    println("• Coverage calculation glitches")
    println("• Numerical precision problems")
    println("• Edge case rendering errors")
    println("• Inconsistent anti-aliasing")
    println("")
    println("WHAT TO LOOK FOR:")
    println("• Original shader may show:")
    println("  - Horizontal lines across glyphs")
    println("  - Flickering or unstable coverage")
    println("  - Artifacts at glyph edges")
    println("• Stable shader should show:")
    println("  - Clean, consistent font rendering")
    println("  - Smooth anti-aliasing")
    println("  - No random artifacts")
    println("")
end

# Run the comparison
if abspath(PROGRAM_FILE) == @__FILE__
    printComparisonInfo()
    compareRendering()
end
