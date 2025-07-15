#!/usr/bin/env julia

using WGPUFontRenderer
using WGPUCore

println("Testing WGPUFontRenderer...")

# Test 1: Basic font preparation
println("Test 1: Font preparation")
try
    prepareGlyphsForText("Hello")
    println("✓ Font preparation successful")
    println("  - Number of glyphs processed: ", length(WGPUFontRenderer.glyphs))
    println("  - Number of curves generated: ", length(WGPUFontRenderer.bufferCurves))
catch e
    println("✗ Font preparation failed: ", e)
end

# Test 2: Check if shaders can be generated
println("\nTest 2: Shader generation")
try
    vs = getVertexShader()
    fs = getFragmentShader()
    println("✓ Shader generation successful")
    println("  - Vertex shader length: ", length(vs))
    println("  - Fragment shader length: ", length(fs))
catch e
    println("✗ Shader generation failed: ", e)
end

println("\nBasic tests completed!")
