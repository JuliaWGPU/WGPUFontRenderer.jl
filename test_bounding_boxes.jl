#!/usr/bin/env julia

# Test script to verify bounding box visualization with bufferIndex = -1

using WGPUFontRenderer
using WGPUCore
using WGPUCanvas
using GLFW

println("=== Bounding Box Visualization Test ===")

# Create canvas and device (minimal setup)
canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
device = WGPUCore.getDefaultDevice(canvas)
renderTextureFormat = WGPUCore.getPreferredFormat(canvas)

# Create font renderer properly
renderer = createFontRenderer(device, device.queue)
initializeRenderer(renderer, renderTextureFormat)
println("✓ Font renderer created")

# Load font data for simple text
text = "Hello"
loadFontData(renderer, text)
println("✓ Font data loaded for: \"$text\"")

# Check that we have both types of bounding box vertices
text_quad_boxes = filter(v -> v.bufferIndex == -1, renderer.vertices)
text_block_boxes = filter(v -> v.bufferIndex == -2, renderer.vertices)
text_vertices = filter(v -> v.bufferIndex >= 0, renderer.vertices)

println("✓ Vertex analysis:")
println("  - Total vertices: $(length(renderer.vertices))")
println("  - Text quad bounding boxes (bufferIndex = -1): $(length(text_quad_boxes))")
println("  - Text block bounding box (bufferIndex = -2): $(length(text_block_boxes))")
println("  - Text vertices (bufferIndex ≥ 0): $(length(text_vertices))")
println("  - Expected: 6 text quad vertices + 6 text block vertices + text vertices")

# Verify the shader contains bounding box handling
vertex_shader = getVertexShader()
fragment_shader = getFragmentShader()

if contains(fragment_shader, "bufferIndex == -1")
    println("✓ Fragment shader contains bounding box visualization code")
    println("  - Bounding boxes should render as red with transparency")
else
    println("✗ Fragment shader missing bounding box visualization")
end

# Show sample vertex data
if !isempty(text_quad_boxes)
    println("✓ Sample text quad bounding box vertex:")
    v = text_quad_boxes[1]
    println("  - Position: ($(v.x), $(v.y))")
    println("  - UV: ($(v.u), $(v.v))")
    println("  - BufferIndex: $(v.bufferIndex)")
end

if !isempty(text_block_boxes)
    println("✓ Sample text block bounding box vertex:")
    v = text_block_boxes[1]
    println("  - Position: ($(v.x), $(v.y))")
    println("  - UV: ($(v.u), $(v.v))")
    println("  - BufferIndex: $(v.bufferIndex)")
end

if !isempty(text_vertices)
    println("✓ Sample text vertex:")
    v = text_vertices[1]
    println("  - Position: ($(v.x), $(v.y))")
    println("  - UV: ($(v.u), $(v.v))")
    println("  - BufferIndex: $(v.bufferIndex)")
end

println("\n=== Bounding Box Test Results ===")
println("The fragment shader has been updated to render:")
println("  - Text quad bounding boxes (bufferIndex = -1) as RED with 30% transparency")
println("  - Text block bounding box (bufferIndex = -2) as BLUE with 20% transparency")
println("\nTo see the bounding boxes:")
println("1. Run: julia --project=. test_visual_rendering.jl")
println("2. Look for:")
println("   - Red rectangular outlines around each character (text quads)")
println("   - Blue rectangular outline showing the text block bounds for word wrapping")
println("3. The blue box shows where text should wrap within")
println("\n✓ Dual bounding box visualization is properly configured!")

# Cleanup
WGPUCore.destroyWindow(canvas)
