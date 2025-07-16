#!/usr/bin/env julia

using WGPUFontRenderer
using WGPUCore
using WGPUCanvas
using GLFW

function test_indexing_fixes()
    println("=== Testing Indexing Fixes ===")
    
    # Test 1: Font processing
    println("\n1. Testing font processing...")
    try
        prepareGlyphsForText("Hello")
        println("✓ Font processing successful")
        
        # Check if we have valid glyphs
        if !isempty(WGPUFontRenderer.glyphs)
            println("✓ Glyphs created: $(length(WGPUFontRenderer.glyphs))")
            
            # Check first glyph
            first_glyph = first(values(WGPUFontRenderer.glyphs))
            println("  First glyph bufferIndex: $(first_glyph.bufferIndex)")
            println("  First glyph curveCount: $(first_glyph.curveCount)")
        else
            println("✗ No glyphs created")
            return false
        end
        
        # Check if we have valid curves
        if !isempty(WGPUFontRenderer.bufferCurves)
            println("✓ Curves created: $(length(WGPUFontRenderer.bufferCurves))")
            
            # Check first curve
            first_curve = WGPUFontRenderer.bufferCurves[1]
            println("  First curve: p0=($(first_curve.x0), $(first_curve.y0))")
            println("               p1=($(first_curve.x1), $(first_curve.y1))")
            println("               p2=($(first_curve.x2), $(first_curve.y2))")
        else
            println("✗ No curves created")
            return false
        end
        
        # Check buffer glyphs
        if !isempty(WGPUFontRenderer.bufferGlyphs)
            println("✓ BufferGlyphs created: $(length(WGPUFontRenderer.bufferGlyphs))")
            
            # Check first buffer glyph
            first_buffer_glyph = WGPUFontRenderer.bufferGlyphs[1]
            println("  First buffer glyph: start=$(first_buffer_glyph.start), count=$(first_buffer_glyph.count)")
        else
            println("✗ No buffer glyphs created")
            return false
        end
        
    catch e
        println("✗ Font processing failed: $e")
        return false
    end
    
    # Test 2: Renderer creation
    println("\n2. Testing renderer creation...")
    try
        canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
        device = WGPUCore.getDefaultDevice(canvas)
        renderTextureFormat = WGPUCore.getPreferredFormat(canvas)
        
        # Create font renderer
        fontRenderer = createFontRenderer(device, device.queue)
        initializeRenderer(fontRenderer, renderTextureFormat)
        
        println("✓ Renderer created successfully")
        
        # Test 3: Data loading
        println("\n3. Testing data loading...")
        loadFontData(fontRenderer, "Test")
        
        println("✓ Font data loaded successfully")
        println("  Vertices: $(length(fontRenderer.vertices))")
        println("  Curves: $(length(fontRenderer.curves))")
        println("  Glyphs: $(length(fontRenderer.glyphs))")
        
        # Validate that bufferIndex values are reasonable
        for (i, vertex) in enumerate(fontRenderer.vertices)
            if vertex.bufferIndex < 0 || vertex.bufferIndex >= length(fontRenderer.glyphs)
                println("✗ Invalid bufferIndex $(vertex.bufferIndex) in vertex $i")
                return false
            end
        end
        println("✓ All vertex buffer indices are valid")
        
        # Clean up
        WGPUCore.destroyWindow(canvas)
        
    catch e
        println("✗ Renderer test failed: $e")
        return false
    end
    
    println("\n✓ All indexing tests passed!")
    return true
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    test_indexing_fixes()
end
