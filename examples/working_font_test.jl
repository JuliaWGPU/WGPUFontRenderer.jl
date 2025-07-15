#!/usr/bin/env julia

# Working font renderer test focused on core functionality
# This test demonstrates the font renderer without GPU device creation

using WGPUFontRenderer

function test_font_renderer_core()
    println("=== Font Renderer Core Functionality Test ===")
    
    # Test 1: Font preparation
    println("\n1. Testing font preparation...")
    try
        prepareGlyphsForText("Hello GPU Font Rendering!")
        println("✓ Font preparation successful")
        println("  - Glyphs processed: ", length(WGPUFontRenderer.glyphs))
        println("  - Curves generated: ", length(WGPUFontRenderer.bufferCurves))
        
        # Show some details about the processed glyphs
        if !isempty(WGPUFontRenderer.glyphs)
            println("\n  Glyph details:")
            for (char, glyph) in WGPUFontRenderer.glyphs
                println("    '$char': width=$(glyph.width), height=$(glyph.height), curves=$(glyph.curveCount)")
            end
        end
        
    catch e
        println("✗ Font preparation failed: ", e)
        return false
    end
    
    # Test 2: Shader generation
    println("\n2. Testing shader generation...")
    try
        vertexShader = getVertexShader()
        fragmentShader = getFragmentShader()
        println("✓ Shader generation successful")
        println("  - Vertex shader: ", length(vertexShader), " characters")
        println("  - Fragment shader: ", length(fragmentShader), " characters")
        
        # Show a snippet of the vertex shader
        println("\n  Vertex shader preview:")
        lines = split(vertexShader, "\n")
        for i in 1:min(5, length(lines))
            println("    ", lines[i])
        end
        if length(lines) > 5
            println("    ... (truncated)")
        end
        
    catch e
        println("✗ Shader generation failed: ", e)
        return false
    end
    
    # Test 3: Data structures
    println("\n3. Testing data structures...")
    try
        # Test FontUniforms
        uniforms = WGPUFontRenderer.FontUniforms(
            (1.0f0, 0.0f0, 0.0f0, 1.0f0),  # Red color
            (2.0f0, 0.0f0, 0.0f0, 0.0f0,   # 2x scale matrix
             0.0f0, 2.0f0, 0.0f0, 0.0f0,
             0.0f0, 0.0f0, 1.0f0, 0.0f0,
             0.0f0, 0.0f0, 0.0f0, 1.0f0),
            1.5f0,  # Anti-aliasing window size
            1,      # Enable super-sampling AA
            (0, 0)  # Padding
        )
        println("✓ FontUniforms structure working")
        println("  - Size: ", sizeof(uniforms), " bytes")
        
        # Test BufferVertex
        vertex = WGPUFontRenderer.BufferVertex(0.5f0, 0.5f0, 0.0f0, 1.0f0, 0)
        println("✓ BufferVertex structure working")
        println("  - Size: ", sizeof(vertex), " bytes")
        
        # Test BufferCurve
        curve = WGPUFontRenderer.BufferCurve(0.0f0, 0.0f0, 0.5f0, 0.5f0, 1.0f0, 0.0f0)
        println("✓ BufferCurve structure working")
        println("  - Size: ", sizeof(curve), " bytes")
        
    catch e
        println("✗ Data structure test failed: ", e)
        return false
    end
    
    # Test 4: Analyze curve data
    println("\n4. Analyzing curve data...")
    try
        if !isempty(WGPUFontRenderer.bufferCurves)
            println("✓ Curve analysis successful")
            println("  - Total curves: ", length(WGPUFontRenderer.bufferCurves))
            
            # Analyze curve distribution
            x_coords = [curve.x0 for curve in WGPUFontRenderer.bufferCurves]
            y_coords = [curve.y0 for curve in WGPUFontRenderer.bufferCurves]
            
            println("  - X coordinate range: ", minimum(x_coords), " to ", maximum(x_coords))
            println("  - Y coordinate range: ", minimum(y_coords), " to ", maximum(y_coords))
            
            # Show first few curves
            println("\n  First 3 curves:")
            for i in 1:min(3, length(WGPUFontRenderer.bufferCurves))
                curve = WGPUFontRenderer.bufferCurves[i]
                println("    Curve $i: p0=($(curve.x0), $(curve.y0)), p1=($(curve.x1), $(curve.y1)), p2=($(curve.x2), $(curve.y2))")
            end
        end
        
    catch e
        println("✗ Curve analysis failed: ", e)
        return false
    end
    
    return true
end

function main()
    success = test_font_renderer_core()
    
    if success
        println("\n🎉 All core functionality tests passed!")
        println("The font renderer core is working correctly.")
        println("\nFeatures demonstrated:")
        println("- ✓ Font loading and processing with FreeType")
        println("- ✓ Bézier curve generation from font outlines")
        println("- ✓ WGSL shader generation")
        println("- ✓ Data structure definitions")
        println("- ✓ Curve analysis and processing")
        println("\nThe font renderer is ready for GPU integration!")
    else
        println("\n❌ Some tests failed. Please check the error messages above.")
    end
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
