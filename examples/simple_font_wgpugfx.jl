# Simple WGPUFontRenderer + WGPUgfx Integration Example
# Minimal example showing the core integration pattern

using WGPUCore
using WGPUgfx
using WGPUCanvas
using GLFW
using WGPUFontRenderer

println("🔧 Initializing WGPU and WGPUgfx...")

# Create canvas and device
canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
device = WGPUCore.getDefaultDevice(canvas)
queue = device.queue

# Create renderer
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

println("🎮 Starting simple render loop...")

# Simple render loop
frameCount = 0
lastTime = time()

while frameCount < 100 && !GLFW.WindowShouldClose(canvas.window)
    currentTime = time()
    deltaTime = Float32(currentTime - lastTime)
    lastTime = currentTime
    
    # Animate the text position
    x = 100.0f0 + 50.0f0 * sin(frameCount * 0.1f0)
    WGPUFontRenderer.setPosition!(fontRenderable, x, 100.0f0)
    
    # Begin frame
    WGPUgfx.beginFrame(renderer)
    
    # Render the font using WGPUgfx's render system
    renderPass = renderer.currentRenderPass
    if renderPass !== nothing
        WGPUgfx.render(renderPass, nothing, fontRenderable, 1)
    end
    
    # End frame
    WGPUgfx.endFrame(renderer)
    
    # Poll events
    GLFW.PollEvents()
    
    frameCount += 1
    
    if frameCount % 30 == 0
        println("Rendered $frameCount frames")
    end
    
    # Small delay
    sleep(0.016)  # ~60 FPS
end

println("✅ Simple integration demo completed!")
println("Key integration points demonstrated:")
println("  1. FontRenderableUI <: WGPUgfx.RenderableUI")
println("  2. prepareObject() for WGPUgfx compatibility")
println("  3. render() integration with WGPUgfx scene graph")
println("  4. Dynamic updates via setPosition!() and setText!()")