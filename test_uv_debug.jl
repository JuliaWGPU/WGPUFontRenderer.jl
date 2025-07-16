#!/usr/bin/env julia

using WGPUFontRenderer
using WGPUCore

# Create a simple test to debug UV coordinates
println("=== UV Coordinate Debug Test ===\n")

# Test font preparation
println("Testing font preparation...")
prepareGlyphsForText("Hi")

# Check if we have glyphs
if !isempty(WGPUFontRenderer.glyphs)
    println("Available glyphs:")
    for (char, glyph) in WGPUFontRenderer.glyphs
        println("  '$char': bufferIndex=$(glyph.bufferIndex), width=$(glyph.width), height=$(glyph.height)")
        println("       bearingX=$(glyph.bearingX), bearingY=$(glyph.bearingY), advance=$(glyph.advance)")
        
        # Calculate UV coordinates like the renderer does
        emSize = 64.0f0
        u0 = Float32(glyph.bearingX) / emSize
        v0 = Float32(glyph.bearingY - glyph.height) / emSize
        u1 = Float32(glyph.bearingX + glyph.width) / emSize
        v1 = Float32(glyph.bearingY) / emSize
        
        println("       UV coordinates: u0=$u0, v0=$v0, u1=$u1, v1=$v1")
    end
else
    println("No glyphs found!")
end

# Check curve data
println("\nFirst 5 curves:")
for i in 1:min(5, length(WGPUFontRenderer.bufferCurves))
    curve = WGPUFontRenderer.bufferCurves[i]
    println("  Curve $i: p0=($(curve.x0), $(curve.y0)) p1=($(curve.x1), $(curve.y1)) p2=($(curve.x2), $(curve.y2))")
end

println("\n=== Debug Complete ===")
