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
include("text_editor_renderer.jl")

# Include WGPUgfx integration directly in this module
include("WGPUgfxFont.jl")

# Export main structures
export FontRenderer, BufferGlyph, BufferCurve, BufferVertex, Glyph, FontUniforms
export GlyphQuad, TextEditorRenderer

# Export main functions
export prepareGlyphsForText, createFontRenderer, renderText, loadFontData
export getVertexShader, getFragmentShader, getNoSuperSamplingShader, getCoordinateScalingFixShader
export initializeRenderer, generateVertexData
export createGPUBuffers, createBindGroup
export setPosition, addText, clearText

# Export text editor functions
export createTextEditorRenderer, renderTextEditorText, updateText
export setCursorPosition, getCursorPosition, insertCharacter, deleteCharacter
export moveCursorLeft, moveCursorRight

# Export WGPUgfx integration
export FontRenderableUI, defaultFontRenderableUI, setText!, setPosition!, animatePosition!

# Export global variables
export bufferCurves, bufferGlyphs, glyphs

end # module WGPUFontRenderer
