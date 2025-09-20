module WGPUFontRenderer

__precompile__(false)

using WGPUgfx

include("cUtils.jl")
using .CUtils
export cStruct, ptr

include("font.jl")
include("reference_faithful_shader.jl")
include("shaders.jl")
include("renderer.jl")

# Include WGPUgfx integration directly in this module
include("WGPUgfxFont.jl")

# Export main structures
export FontRenderer, BufferGlyph, BufferCurve, BufferVertex, Glyph, FontUniforms

# Export main functions
export prepareGlyphsForText, createFontRenderer, renderText, loadFontData
export getVertexShader, getFragmentShader
export initializeRenderer, generateVertexData
export createGPUBuffers, createBindGroup
export setPosition, addText, clearText
export updateUniforms

# Export WGPUgfx integration
export FontRenderableUI, defaultFontRenderableUI, setText!, setPosition!, animatePosition!

# Export global variables
export bufferCurves, bufferGlyphs, glyphs

end # module WGPUFontRenderer
