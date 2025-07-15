#!/usr/bin/env julia

# Debug script to examine font rendering data
using WGPUFontRenderer

# Create a mock renderer to test vertex generation
mutable struct MockRenderer
    vertices::Vector{BufferVertex}
    MockRenderer() = new(BufferVertex[])
end

# First, let's check the vertex data generation
function debug_vertex_data()
    println("=== Debugging Vertex Data Generation ===")
    
    # Prepare some basic text
    text = "Hello"
    prepareGlyphsForText(text)
    
    # Check what glyphs were generated
    println("Generated glyphs:")
    for (char, glyph) in glyphs
        println("  '$char': width=$(glyph.width), height=$(glyph.height), bearingX=$(glyph.bearingX), bearingY=$(glyph.bearingY), advance=$(glyph.advance)")
    end
    
    renderer = MockRenderer()
    
    # Test current vertex generation
    println("\n=== Testing Current Vertex Generation ===")
    
    # Better scaling and positioning for NDC coordinates (-1 to 1)
    scale = 0.1f0  # Increased scale for visibility
    
    # Calculate total text width first for centering
    totalWidth = 0.0f0
    for char in text
        if haskey(glyphs, char)
            glyph = glyphs[char]
            totalWidth += glyph.advance * scale
        end
    end
    
    # Center the text horizontally and vertically
    xOffset = -totalWidth / 2.0f0
    yOffset = 0.0f0  # Center vertically
    
    for (i, char) in enumerate(text)
        if haskey(glyphs, char)
            glyph = glyphs[char]
            
            # Calculate glyph quad dimensions
            width = glyph.width * scale  
            height = glyph.height * scale
            bearingX = glyph.bearingX * scale
            bearingY = glyph.bearingY * scale
            
            # Define quad vertices (two triangles)
            x1 = xOffset + bearingX
            y1 = yOffset + bearingY - height
            x2 = x1 + width
            y2 = yOffset + bearingY
            
            println("Character '$char':")
            println("  Scaled dimensions: width=$width, height=$height")
            println("  Quad bounds: x1=$x1, y1=$y1, x2=$x2, y2=$y2")
            println("  Vertex positions: ($x1, $y2), ($x1, $y1), ($x2, $y2)")
            
            # First triangle: top-left, bottom-left, top-right
            push!(renderer.vertices, BufferVertex(x1, y2, 0.0f0, 0.0f0, glyph.bufferIndex))
            push!(renderer.vertices, BufferVertex(x1, y1, 0.0f0, 1.0f0, glyph.bufferIndex))
            push!(renderer.vertices, BufferVertex(x2, y2, 1.0f0, 0.0f0, glyph.bufferIndex))
            
            # Second triangle: bottom-left, bottom-right, top-right
            push!(renderer.vertices, BufferVertex(x1, y1, 0.0f0, 1.0f0, glyph.bufferIndex))
            push!(renderer.vertices, BufferVertex(x2, y1, 1.0f0, 1.0f0, glyph.bufferIndex))
            push!(renderer.vertices, BufferVertex(x2, y2, 1.0f0, 0.0f0, glyph.bufferIndex))
            
            # Advance position for next character
            xOffset += glyph.advance * scale
        end
    end
    
    println("\nGenerated $(length(renderer.vertices)) vertices")
    println("Total text width: $xOffset")
    
    # Test with a larger scale
    println("\n=== Testing with Larger Scale ===")
    renderer2 = MockRenderer()
    xOffset = 0.0f0
    yOffset = 0.0f0
    scale = 1.0f0  # Much larger scale
    
    for (i, char) in enumerate(text)
        if haskey(glyphs, char)
            glyph = glyphs[char]
            
            # Calculate glyph quad dimensions
            width = glyph.width * scale  
            height = glyph.height * scale
            bearingX = glyph.bearingX * scale
            bearingY = glyph.bearingY * scale
            
            # Define quad vertices (two triangles)
            x1 = xOffset + bearingX
            y1 = yOffset + bearingY - height
            x2 = x1 + width
            y2 = yOffset + bearingY
            
            println("Character '$char' (scale=$scale):")
            println("  Scaled dimensions: width=$width, height=$height")
            println("  Quad bounds: x1=$x1, y1=$y1, x2=$x2, y2=$y2")
            
            # Advance position for next character
            xOffset += glyph.advance * scale
        end
    end
    
    println("\nWith scale=$scale, total text width: $xOffset")
    
    # Test centered positioning
    println("\n=== Testing Centered Positioning ===")
    # For a typical screen coordinate system (-1, -1) to (1, 1)
    # Let's center the text
    text_width = xOffset
    text_height = 64.0f0  # Typical font height
    
    # Center horizontally and vertically
    start_x = -text_width / 2.0f0
    start_y = -text_height / 2.0f0
    
    println("Centered positioning:")
println("  Text dimensions: ", text_width, "x", text_height)
    println("  Starting position: ($start_x, $start_y)")
    
end

# Test the debug function
debug_vertex_data()
