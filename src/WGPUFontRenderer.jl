module WGPUFontRenderer

__precompile__(false)

include("cUtils.jl")
using .CUtils
export cStruct, ptr

include("font.jl")
include("shaders.jl")
include("renderer.jl")

# Export main structures
export FontRenderer, BufferGlyph, BufferCurve, BufferVertex, Glyph, FontUniforms

# Export main functions
export prepareGlyphsForText, createFontRenderer, renderText, loadFontData
export getVertexShader, getFragmentShader
export initializeRenderer, generateVertexData
export createGPUBuffers, createBindGroup

# Export global variables
export bufferCurves, bufferGlyphs, glyphs

end # module WGPUFontRenderer
