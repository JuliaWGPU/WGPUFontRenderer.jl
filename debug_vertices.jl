# Debug script to print vertex positions and see what's happening

using WGPUFontRenderer

# Load the same text as the example
text = "Hello GPU Font Rendering!"

# Prepare glyph data
prepareGlyphsForText(text)

# Create a fake font renderer to generate vertices
mutable struct FakeRenderer
    glyphs::Vector{Glyph}
    curves::Vector{BufferCurve}
    vertices::Vector{BufferVertex}
    
    function FakeRenderer()
        new(Glyph[], BufferCurve[], BufferVertex[])
    end
end

# Create fake renderer and populate with data
renderer = FakeRenderer()
renderer.glyphs = collect(values(glyphs))
renderer.curves = bufferCurves

# Now generate vertex data using the same logic as the real renderer
function generateVertexData(renderer::FakeRenderer, text::String)
    empty!(renderer.vertices)
    
    # Better scaling and positioning for NDC coordinates (-1 to 1)
    scale = 0.01f0  # Proper scale to fit in NDC space (-1 to 1)
    
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
    
    println("Text: '$text'")
    println("Total width: $totalWidth")
    println("Starting xOffset: $xOffset")
    println("Scale: $scale")
    println("Number of glyphs: $(length(renderer.glyphs))")
    println("Number of curves: $(length(renderer.curves))")
    println()
    
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
            
            println("Character '$char' (index $i):")
            println("  Glyph dimensions: width=$width, height=$height")
            println("  Glyph bearings: bearingX=$bearingX, bearingY=$bearingY")
            println("  Glyph buffer index: $(glyph.bufferIndex)")
            println("  Quad corners: ($x1, $y1) to ($x2, $y2)")
            println("  Quad size: $(x2-x1) x $(y2-y1)")
            
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
            println("  Next xOffset: $xOffset")
            println()
        end
    end
    
    println("Total vertices generated: $(length(renderer.vertices))")
    println("Vertex bounds:")
    if !isempty(renderer.vertices)
        minX = minimum(v.x for v in renderer.vertices)
        maxX = maximum(v.x for v in renderer.vertices)
        minY = minimum(v.y for v in renderer.vertices)
        maxY = maximum(v.y for v in renderer.vertices)
        println("  X range: $minX to $maxX")
        println("  Y range: $minY to $maxY")
    end
end

# Generate and analyze vertex data
generateVertexData(renderer, text)
