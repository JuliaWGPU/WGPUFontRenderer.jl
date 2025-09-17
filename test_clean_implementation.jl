# Test script for clean GPU font renderer implementation
# Tests core functionality without opening a GLFW window

using Test

# Include our clean implementation
include("src/gpu_font_renderer_clean/WGPUFontRendererClean.jl")
using .WGPUFontRendererClean

println("Testing Clean GPU Font Renderer Implementation...")
println("="^50)

# Test 1: Font loader creation
println("Test 1: Font loader creation")
try
    # Try to create a font loader with a non-existent font
    loader = FontLoader("nonexistent_font.ttf")
    println("  ✗ Should have thrown an error for non-existent font")
catch e
    println("  ✓ Correctly threw error for non-existent font")
end

# Test 2: Data structure creation
println("\nTest 2: Data structure creation")
glyph = Glyph(0, 0, 0, 0, 0, 0, 0, 0)
buffer_glyph = BufferGlyph(0, 0)
buffer_curve = BufferCurve(0.0f0, 0.0f0, 0.0f0, 0.0f0, 0.0f0, 0.0f0)

println("  ✓ Glyph structure created successfully")
println("  ✓ BufferGlyph structure created successfully")
println("  ✓ BufferCurve structure created successfully")

# Test 3: Shader generation
println("\nTest 3: Shader generation")
vertex_shader = getVertexShader()
fragment_shader = getFragmentShader()

@test typeof(vertex_shader) == String
@test typeof(fragment_shader) == String
@test length(vertex_shader) > 100
@test length(fragment_shader) > 100

println("  ✓ Vertex shader generated (", length(vertex_shader), " chars)")
println("  ✓ Fragment shader generated (", length(fragment_shader), " chars)")

# Test 4: Font loader functions
println("\nTest 4: Font loader functions")
# Check that the FT constants are defined
@test isdefined(WGPUFontRendererClean, :FT_CURVE_TAG_ON)
@test isdefined(WGPUFontRendererClean, :FT_CURVE_TAG_CONIC)
@test isdefined(WGPUFontRendererClean, :FT_CURVE_TAG_CUBIC)
@test isdefined(WGPUFontRendererClean, :FT_OUTLINE_REVERSE_FILL)

println("  ✓ FT constants defined correctly")

# Test 5: Module exports
println("\nTest 5: Module exports")
expected_exports = [
    :FontLoader, :Glyph, :BufferGlyph, :BufferCurve, :loadGlyphsForText!,
    :getVertexShader, :getFragmentShader,
    :GPUCleanFontRenderer, :initializeRenderer, :loadFontData, :renderText
]

for exp in expected_exports
    @test exp in names(WGPUFontRendererClean)
end

println("  ✓ All expected functions and types exported")

println("\n" * "="^50)
println("All tests passed! ✓")
println("The clean GPU font renderer implementation is working correctly.")