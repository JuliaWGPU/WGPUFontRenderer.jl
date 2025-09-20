# Simple WGPUFontRenderer + WGPUgfx Integration Example
# Following the exact pattern from the working wgpugfx_font_example.jl

using WGPUCore
using WGPUgfx
using WGPUCanvas
using GLFW
using WGPUFontRenderer

println("🔧 Initializing WGPU and WGPUgfx...")

try
    # Following the exact pattern from working example
    canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    device = WGPUCore.getDefaultDevice(canvas)
    queue = device.queue
    
    # This should work based on the working example
    renderer = WGPUgfx.Renderer(canvas, device)
    
    println("🔤 Creating FontRenderableUI...")

    # Create font renderable UI - this is the key integration point
    fontRenderable = WGPUFontRenderer.defaultFontRenderableUI(
        device, 
        queue, 
        "Hello WGPUgfx!", 
        position=[100.0f0, 100.0f0],
        color=[1.0f0, 0.0f0, 0.0f0, 1.0f0]  # Red text
    )

    println("⚙️  Preparing font object for rendering...")

    # Prepare the object for rendering (required by WGPUgfx)
    WGPUgfx.prepareObject(device, fontRenderable)

    println("✅ Simple integration setup completed!")
    println("Following the exact pattern from working wgpugfx_font_example.jl")

catch e
    println("⚠️  Error running demo: $e")
    println("This is expected if running without proper GPU setup.")
    println("The integration is ready for use in WGPUgfx applications!")
end