# Text Editor Font Renderer Example
#
# This example demonstrates the quad-based approach suitable for text editors.
# Each character is rendered as a textured quad, making editing operations efficient.

using WGPUCore
using WGPUFontRenderer

println("Text Editor Font Renderer Example")
println("=================================")
println()

# Example of how to use the text editor renderer
println("1. Creating Text Editor Renderer:")
println("   renderer = createTextEditorRenderer(device, queue, \"font.ttf\", 16.0f0)")
println()

println("2. Setting and Updating Text:")
println("   updateText(renderer, \"Hello, World!\")")
println("   # This creates one quad per character")
println()

println("3. Text Editing Operations:")
println("   insertCharacter(renderer, '!')     # Insert at cursor")
println("   deleteCharacter(renderer)          # Delete at cursor")
println("   moveCursorLeft(renderer)           # Move cursor left")
println("   moveCursorRight(renderer)          # Move cursor right")
println("   setCursorPosition(renderer, 5)     # Set cursor position")
println()

println("4. Rendering:")
println("   renderTextEditorText(renderer, renderPass)")
println("   # Renders all character quads efficiently")
println()

# Demonstrate the API
println("API Demonstration:")
println("   Available types:")
println("   - GlyphQuad: Represents a single character quad")
println("   - TextEditorRenderer: Main renderer for text editing")

println()
println("   Available functions:")
functions = [
    "createTextEditorRenderer",
    "updateText",
    "renderTextEditorText", 
    "setCursorPosition",
    "getCursorPosition",
    "insertCharacter",
    "deleteCharacter",
    "moveCursorLeft",
    "moveCursorRight"
]

for func in functions
    if isdefined(WGPUFontRenderer, Symbol(func))
        println("   ✓ $func")
    else
        println("   ✗ $func (NOT AVAILABLE)")
    end
end

println()
println("Key Differences from Vector Renderer:")
println("   ✓ One quad per character (efficient for editing)")
println("   ✓ Pre-rasterized glyphs (texture atlas)")
println("   ✓ Easy cursor positioning and selection")
println("   ✓ Efficient for large amounts of text")
println("   ✓ Better for real-time editing operations")
println()
println("Use this approach when building:")
println("   - Text editors")
println("   - Code editors") 
println("   - Rich text applications")
println("   - UI text elements requiring frequent updates")