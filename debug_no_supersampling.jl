# Debug script to test font rendering with super-sampling disabled
# This will help isolate whether the horizontal lines come from super-sampling or coordinate scaling

using Pkg

# Add our font renderer
Pkg.develop(path="C:\\Users\\arhik\\.julia\\dev\\WGPUFontRenderer")
using WGPUFontRenderer

# Create a simple debug test that uses the no super-sampling shader
function testNoSuperSamplingShader()
    println("Testing font rendering with super-sampling DISABLED...")
    println("This should help isolate whether horizontal lines come from:")
    println("1. Super-sampling instability (rotated ray calculation)")
    println("2. Coordinate scaling issues")
    println("3. Basic coverage calculation problems")
    
    # Prepare test text and load font data
    testText = "Hello World!"
    println("Preparing glyphs for text: '$testText'")
    
    # Use the no-super-sampling debug shader instead of the regular one
    function getDebugVertexShader()
        return getVertexShader()  # Use regular vertex shader
    end
    
    function getDebugFragmentShader()
        return getNoSuperSamplingShader()  # Use the debug shader with no super-sampling
    end
    
    println("Debug shader configuration:")
    println("- Super-sampling: DISABLED")
    println("- fwidth approximation: SIMPLIFIED")
    println("- Anti-aliasing: Basic uniform scaling only")
    
    # Load font and prepare glyphs (this loads from the bundled font)
    try
        prepareGlyphsForText(testText)
        println("✓ Font loaded and glyphs prepared for text")
        
        println("\nDebug Analysis:")
        println("If horizontal lines are GONE or REDUCED:")
        println("  → Super-sampling was the main cause")
        println("  → Focus on fixing rotated ray calculation")
        println("")
        println("If horizontal lines are STILL PRESENT:")
        println("  → Problem is in basic coverage calculation or coordinate scaling")
        println("  → Need to debug inverseDiameter calculation")
        println("")
        
        # Note: Actual rendering would require a WGPU context
        println("Note: To see visual results, this needs to be run in a WGPU rendering context")
        println("The key is whether removing super-sampling eliminates the horizontal artifacts")
        
    catch e
        println("Error creating renderer: $e")
        return false
    end
    
    return true
end

# Create a version that tests different anti-aliasing window sizes
function testAntiAliasingScaling()
    println("\n" * "="^60)
    println("Testing different anti-aliasing window sizes...")
    println("This helps identify coordinate scaling issues")
    
    testSizes = [1.0, 2.0, 4.0, 8.0, 16.0]
    
    for size in testSizes
        println("Testing antiAliasingWindowSize: $size")
        println("  → inverseDiameter = $(1.0 / size)")
        println("  → Expected effect: $(size < 4.0 ? "Sharp edges" : "Soft edges")")
    end
    
    println("\nIf horizontal lines change significantly with window size:")
    println("  → Coordinate scaling problem")
    println("  → Need to fix font-units-to-pixels ratio")
    
    println("\nIf horizontal lines are consistent regardless of window size:")
    println("  → Problem is in curve intersection calculation")
    println("  → Need to debug quadratic root finding")
end

# Run the tests
if abspath(PROGRAM_FILE) == @__FILE__
    println("="^60)
    println("FONT RENDERING DEBUG: NO SUPER-SAMPLING TEST")
    println("="^60)
    
    success = testNoSuperSamplingShader()
    
    if success
        testAntiAliasingScaling()
        
        println("\n" * "="^60)
        println("DEBUG RECOMMENDATIONS:")
        println("="^60)
        println("1. Try rendering with this debug shader")
        println("2. Compare visual results to super-sampling version")
        println("3. Adjust antiAliasingWindowSize values (1.0, 2.0, 4.0, 8.0)")
        println("4. If lines persist, focus on coordinate space scaling")
        println("5. If lines disappear, focus on super-sampling stability")
        println("="^60)
    else
        println("❌ Debug test failed")
    end
end
