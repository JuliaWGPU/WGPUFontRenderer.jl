# WGPUFontRenderer WGPUgfx Integration Example
#
# This example shows how to use the FontRenderableUI with WGPUgfx.
# Note: This example requires a working WGPU context to run fully.

using WGPUCore
using WGPUgfx
using WGPUFontRenderer

# This is how you would use the integration in a real application:

#=
# In your application setup:
fontRenderable = defaultFontRenderableUI(
    device,  # WGPUCore.GPUDevice
    queue,   # WGPUCore.GPUQueue  
    "Hello WGPUgfx!",  # Text to render
    position=[100.0f0, 100.0f0],  # Screen position
    color=[1.0f0, 0.0f0, 0.0f0, 1.0f0]  # Red text
)

# Prepare the object for rendering (WGPUgfx requirement)
WGPUgfx.prepareObject(device, fontRenderable)

# In your render loop:
function render_frame(renderPass)
    # Render the font using WGPUgfx's render system
    WGPUgfx.render(renderPass, nothing, fontRenderable, cameraId)
end

# Animation example:
function update(deltaTime)
    # Animate the text position
    animatePosition!(fontRenderable, time)
    
    # Or set position directly
    setPosition!(fontRenderable, newX, newY)
    
    # Or change the text content
    setText!(fontRenderable, "New Text!")
end
=#

println("WGPUFontRenderer WGPUgfx Integration Example")
println("============================================")
println()
println("To use this integration in your WGPUgfx application:")
println()
println("1. Create a FontRenderableUI:")
println("   fontRenderable = defaultFontRenderableUI(device, queue, \"Your Text\")")
println()
println("2. Prepare it for rendering:")
println("   WGPUgfx.prepareObject(device, fontRenderable)")
println()
println("3. Render it in your frame loop:")
println("   WGPUgfx.render(renderPass, options, fontRenderable, cameraId)")
println()
println("4. Animate or update it:")
println("   animatePosition!(fontRenderable, time)")
println("   setPosition!(fontRenderable, x, y)")
println("   setText!(fontRenderable, \"New Text\")")
println()
println("This provides seamless integration of high-quality vector font")
println("rendering into the WGPUgfx scene graph system.")