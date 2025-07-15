# Minimal test to isolate the font rendering issue

using WGPUCore
using WGPUFontRenderer

function minimal_test()
    println("Starting minimal font test...")
    
    # Test font processor only (no canvas creation)
    try
        println("Testing font preparation...")
        prepareGlyphsForText("Hello World")
        println("✓ Font processing completed successfully")
        println("  - Number of glyphs processed: ", length(WGPUFontRenderer.glyphs))
        println("  - Number of curves generated: ", length(WGPUFontRenderer.bufferCurves))
    catch e
        println("✗ Font processing failed: ", e)
        return
    end
    
    # Test shader generation
    try
        println("\nTesting shader generation...")
        vs = getVertexShader()
        fs = getFragmentShader()
        println("✓ Shader generation successful")
        println("  - Vertex shader length: ", length(vs))
        println("  - Fragment shader length: ", length(fs))
    catch e
        println("✗ Shader generation failed: ", e)
        return
    end
    
    # Test basic data structures
    try
        println("\nTesting data structures...")
        # Test FontUniforms structure
        uniforms = WGPUFontRenderer.FontUniforms(
            (1.0f0, 1.0f0, 1.0f0, 1.0f0),
            (1.0f0, 0.0f0, 0.0f0, 0.0f0,
             0.0f0, 1.0f0, 0.0f0, 0.0f0,
             0.0f0, 0.0f0, 1.0f0, 0.0f0,
             0.0f0, 0.0f0, 0.0f0, 1.0f0),
            1.0f0,
            0,
            (0, 0)
        )
        println("✓ FontUniforms created successfully")
        println("  - Size: ", sizeof(uniforms), " bytes")
    catch e
        println("✗ Data structure test failed: ", e)
        return
    end
    
    println("\n✓ All minimal tests completed successfully!")
end

# Run the minimal test
if abspath(PROGRAM_FILE) == @__FILE__
    minimal_test()
end
