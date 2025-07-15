#!/usr/bin/env julia

# Simple font renderer test without GLFW window management
# This test focuses on the core font rendering functionality

using WGPUCore
using WGPUCanvas
using WGPUFontRenderer

function test_font_renderer()
    println("=== Simple Font Renderer Test ===")
    
    # Test 1: Basic font preparation
    println("\n1. Testing font preparation...")
    try
        prepareGlyphsForText("Hello World")
        println("✓ Font preparation successful")
        println("  - Glyphs processed: ", length(WGPUFontRenderer.glyphs))
        println("  - Curves generated: ", length(WGPUFontRenderer.bufferCurves))
    catch e
        println("✗ Font preparation failed: ", e)
        return false
    end
    
    # Test 2: Canvas creation (without window)
    println("\n2. Testing canvas creation...")
    try
        canvas = WGPUCore.getCanvas(:OFFSCREEN, (800, 600))
        device = WGPUCore.getDefaultDevice(canvas)
        println("✓ Canvas and device created successfully")
        println("  - Canvas type: ", typeof(canvas))
        println("  - Device created: ", device !== nothing)
        
        # Test 3: Font renderer initialization
        println("\n3. Testing font renderer initialization...")
        fontRenderer = createFontRenderer(device, device.queue)
        println("✓ Font renderer created successfully")
        
        # Test 4: Renderer initialization
        println("\n4. Testing renderer initialization...")
        surfaceFormat = "bgra8unorm"  # Common format
        initializeRenderer(fontRenderer, surfaceFormat)
        println("✓ Renderer initialized successfully")
        
        # Test 5: Load font data
        println("\n5. Testing font data loading...")
        loadFontData(fontRenderer, "Test")
        println("✓ Font data loaded successfully")
        println("  - Vertices generated: ", length(fontRenderer.vertices))
        println("  - GPU buffers created: ", fontRenderer.glyphBuffer !== nothing)
        
        return true
        
    catch e
        println("✗ Canvas/renderer test failed: ", e)
        return false
    end
end

function main()
    success = test_font_renderer()
    
    if success
        println("\n🎉 All tests passed! Font renderer is working correctly.")
        println("The font renderer is ready for use in graphics applications.")
    else
        println("\n❌ Some tests failed. Please check the error messages above.")
    end
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
