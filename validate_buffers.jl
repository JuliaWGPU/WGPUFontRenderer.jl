# Comprehensive buffer validation script for debugging font rendering issues
# This script validates buffer data, alignment, and structure consistency

using WGPUFontRenderer
using FreeTypeAbstraction
using LinearAlgebra

function validate_glyph_buffers(font, text::String; font_size=48)
    println("=== BUFFER VALIDATION ANALYSIS ===")
    
    # Load font
    println("Loading font: $(font)")
    face = FreeTypeAbstraction.FTFont(font)  # Remove font_size parameter
    println("Font loaded successfully")
    
    # Build glyphs
    println("\nBuilding glyphs for text: \"$text\"")
    WGPUFontRenderer.prepareGlyphsForText(text)
    
    # Get the global buffer data
    glyph_data = WGPUFontRenderer.bufferGlyphs
    curves_data = WGPUFontRenderer.bufferCurves
    
    println("Total glyphs: $(length(glyph_data))")
    println("Total curves: $(length(curves_data))")
    
    # Validate glyph structure
    println("\n=== GLYPH STRUCTURE VALIDATION ===")
    for (i, glyph) in enumerate(glyph_data)
        char = text[i:i]  # Get character
        println("Glyph $i '$char':")
        println("  Buffer index: $i (0-based: $(i-1))")
        println("  Start: $(glyph.start) (0-based GPU)")
        println("  Count: $(glyph.count)")
        
        # Convert GPU 0-based index to Julia 1-based for validation
        julia_start = Int(glyph.start) + 1
        println("  Julia start (1-based): $julia_start")
        
        # Validate bounds using Julia 1-based indexing
        if julia_start < 1 || julia_start > length(curves_data)
            println("  ❌ ERROR: Julia start index $julia_start out of bounds [1, $(length(curves_data))]")
        else
            println("  ✅ Start index valid")
        end
        
        if julia_start + glyph.count - 1 > length(curves_data)
            println("  ❌ ERROR: End range $(julia_start + glyph.count - 1) exceeds curves array length $(length(curves_data))")
        else
            println("  ✅ Range valid")
        end
        
        # Show first few curves for this glyph
        if glyph.count > 0
            println("  First curve data:")
            if julia_start <= length(curves_data)
                curve = curves_data[julia_start]
                println("    Curve $julia_start (Julia): ($(curve.x0), $(curve.y0)) -> ($(curve.x1), $(curve.y1)) -> ($(curve.x2), $(curve.y2))")
            end
        end
        println()
    end
    
    # Validate curve data
    println("=== CURVE DATA VALIDATION ===")
    finite_curves = 0
    infinite_curves = 0
    zero_curves = 0
    
    for (i, curve) in enumerate(curves_data)
        all_finite = isfinite(curve.x0) && isfinite(curve.y0) && 
                    isfinite(curve.x1) && isfinite(curve.y1) && 
                    isfinite(curve.x2) && isfinite(curve.y2)
        
        if all_finite
            finite_curves += 1
        else
            infinite_curves += 1
            if i <= 5  # Show first few problematic curves
                println("❌ Curve $i has non-finite values: ($(curve.x0), $(curve.y0)) -> ($(curve.x1), $(curve.y1)) -> ($(curve.x2), $(curve.y2))")
            end
        end
        
        # Check for zero curves (might indicate issues)
        if curve.x0 == 0 && curve.y0 == 0 && curve.x1 == 0 && curve.y1 == 0 && curve.x2 == 0 && curve.y2 == 0
            zero_curves += 1
        end
    end
    
    println("Finite curves: $finite_curves / $(length(curves_data))")
    println("Infinite/NaN curves: $infinite_curves")
    println("Zero curves: $zero_curves")
    
    if infinite_curves > 0
        println("❌ ERROR: Found non-finite curve data!")
    else
        println("✅ All curve data is finite")
    end
    
    # Validate memory layout/struct sizes
    println("\n=== MEMORY LAYOUT VALIDATION ===")
    
    # Check Julia struct sizes
    glyph_size = sizeof(WGPUFontRenderer.BufferGlyph)
    curve_size = sizeof(WGPUFontRenderer.BufferCurve)
    
    println("Julia Glyph struct size: $glyph_size bytes")
    println("Julia Curve struct size: $curve_size bytes")
    
    # Expected WGSL sizes (must match exactly)
    # WGSL Glyph: 2 u32 = 8 bytes
    # WGSL Curve: 6 f32 = 24 bytes
    expected_glyph_size = 8
    expected_curve_size = 24
    
    if glyph_size == expected_glyph_size
        println("✅ Glyph struct size matches WGSL expectation")
    else
        println("❌ ERROR: Glyph struct size mismatch! Expected $expected_glyph_size, got $glyph_size")
    end
    
    if curve_size == expected_curve_size
        println("✅ Curve struct size matches WGSL expectation")
    else
        println("❌ ERROR: Curve struct size mismatch! Expected $expected_curve_size, got $curve_size")
    end
    
    # Check struct field alignment
    println("\n=== STRUCT FIELD ANALYSIS ===")
    println("BufferGlyph fields:")
    for field in fieldnames(WGPUFontRenderer.BufferGlyph)
        offset = fieldoffset(WGPUFontRenderer.BufferGlyph, findfirst(==(field), fieldnames(WGPUFontRenderer.BufferGlyph)))
        println("  $field: offset $offset bytes")
    end
    
    println("BufferCurve fields:")
    for field in fieldnames(WGPUFontRenderer.BufferCurve)
        offset = fieldoffset(WGPUFontRenderer.BufferCurve, findfirst(==(field), fieldnames(WGPUFontRenderer.BufferCurve)))
        println("  $field: offset $offset bytes")
    end
    
    # Validate coordinate ranges
    println("\n=== COORDINATE RANGE ANALYSIS ===")
    if !isempty(curves_data)
        all_x = [curve.x0 for curve in curves_data] ∪ [curve.x1 for curve in curves_data] ∪ [curve.x2 for curve in curves_data]
        all_y = [curve.y0 for curve in curves_data] ∪ [curve.y1 for curve in curves_data] ∪ [curve.y2 for curve in curves_data]
        
        x_range = (minimum(all_x), maximum(all_x))
        y_range = (minimum(all_y), maximum(all_y))
        
        println("X coordinate range: $(x_range[1]) to $(x_range[2])")
        println("Y coordinate range: $(y_range[1]) to $(y_range[2])")
        
        # Check if coordinates are in expected font unit range
        # Font units are typically in range [0, 2000] or similar
        if x_range[2] - x_range[1] > 10000 || y_range[2] - y_range[1] > 10000
            println("⚠️  WARNING: Coordinate range seems very large - check scaling")
        end
        
        if any(abs.(all_x) .> 100000) || any(abs.(all_y) .> 100000)
            println("❌ ERROR: Found extremely large coordinates - likely scaling issue")
        else
            println("✅ Coordinate ranges look reasonable")
        end
    end
    
    return glyph_data, curves_data
end

function validate_buffer_indexing(glyph_data, curves_data)
    println("\n=== BUFFER INDEXING VALIDATION ===")
    
    # Check that all glyph references are valid
    all_valid = true
    
    for (i, glyph) in enumerate(glyph_data)
        # Remember: Julia is 1-based, but we need 0-based for GPU
        gpu_buffer_index = i - 1
        
        println("Glyph $i (GPU buffer index: $gpu_buffer_index):")
        println("  Start: $(glyph.start) (GPU 0-based)")
        println("  Count: $(glyph.count)")
        
        # glyph.start is already 0-based for GPU - don't convert!
        gpu_start = Int(glyph.start)  # Already 0-based
        println("  GPU start (0-based): $gpu_start")
        
        # Check GPU bounds (0-based indexing)
        if gpu_start < 0 || gpu_start >= length(curves_data)
            println("  ❌ ERROR: GPU start index $gpu_start out of bounds [0, $(length(curves_data)-1)]")
            all_valid = false
        else
            println("  ✅ GPU start index valid")
        end
        
        if gpu_start + glyph.count > length(curves_data)
            println("  ❌ ERROR: GPU end range $(gpu_start + glyph.count) exceeds curves array length $(length(curves_data))")
            all_valid = false
        else
            println("  ✅ GPU range valid")
        end
        
        # Also check Julia bounds (1-based indexing) for completeness
        julia_start = gpu_start + 1
        if julia_start >= 1 && julia_start <= length(curves_data) && julia_start + glyph.count - 1 <= length(curves_data)
            println("  ✅ Julia indexing also valid (start: $julia_start)")
        else
            println("  ⚠️  WARNING: Julia indexing issues (start: $julia_start)")
        end
        
        println()
    end
    
    return all_valid
end

function test_simple_render()
    println("\n=== SIMPLE RENDER TEST ===")
    println("Testing with debug shader (should show colored glyphs)...")
    
    try
        # Use a simple test string
        test_text = "Hello"
        
        println("Attempting to render: \"$test_text\"")
        
        # This will use the debug shader we just created
        WGPUFontRenderer.run_demo(test_text)
        
        println("✅ Demo completed - check if glyphs appear as colored rectangles")
        println("Expected: Each glyph should be a different color (white, yellow, cyan, orange)")
        println("If you see random cuts/glitches, the issue is likely in vertex generation or UV mapping")
        
    catch e
        println("❌ ERROR during render test: $e")
        return false
    end
    
    return true
end

# Run validation
function main()
    # Find a font file
    font_path = if Sys.iswindows()
        "C:\\Windows\\Fonts\\arial.ttf"
    else
        "/System/Library/Fonts/Arial.ttf"  # macOS
    end
    
    if !isfile(font_path)
        println("❌ ERROR: Could not find font file at $font_path")
        println("Please specify a valid font path")
        return
    end
    
    test_text = "Hello"
    
    # Step 1: Validate buffer data
    glyph_data, curves_data = validate_glyph_buffers(font_path, test_text)
    
    # Step 2: Validate indexing
    indexing_valid = validate_buffer_indexing(glyph_data, curves_data)
    
    # Step 3: Test simple render
    if indexing_valid
        println("\n✅ Buffer validation passed - proceeding with render test")
        test_simple_render()
    else
        println("\n❌ Buffer validation failed - fix indexing issues before rendering")
    end
    
    println("\n=== VALIDATION COMPLETE ===")
    println("If the debug shader shows solid colored rectangles for each glyph,")
    println("then the buffer data and indexing are correct.")
    println("If you still see cuts/glitches, the issue is likely in:")
    println("  1. Vertex generation (quad positioning)")
    println("  2. UV coordinate mapping")
    println("  3. Coordinate space scaling")
end

# Run if called directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
