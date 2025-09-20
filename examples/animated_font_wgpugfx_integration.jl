# WGPUFontRenderer + WGPUgfx Integration Example
# Complete working example using proper Scene pattern

using WGPUCore
using WGPUgfx
using WGPUCanvas
using GLFW
using WGPUFontRenderer

# Complete demo application showing FontRenderableUI integration
mutable struct AnimatedTextDemo
    scene::WGPUgfx.Scene
    renderer::WGPUgfx.Renderer
    fontRenderable::WGPUFontRenderer.FontRenderableUI
    time::Float32
end

function AnimatedTextDemo()
    return new()
end

function init_demo(demo::AnimatedTextDemo)
    # Initialize WGPU context through scene (correct WGPUgfx pattern)
    demo.scene = WGPUgfx.Scene()
    demo.time = 0.0f0
    
    # Create WGPUgfx renderer
    demo.renderer = WGPUgfx.getRenderer(demo.scene)
    
    # Get device and queue from scene
    device = demo.scene.gpuDevice
    queue = device.queue
    
    # Create animated text using FontRenderableUI
    demo.fontRenderable = WGPUFontRenderer.defaultFontRenderableUI(
        device, 
        queue, 
        "WGPUFontRenderer + WGPUgfx", 
        position=[400.0f0, 300.0f0],  # Center of screen
        color=[0.2f0, 0.6f0, 1.0f0, 1.0f0]  # Blue text
    )
    
    # Prepare the font object for rendering (required by WGPUgfx)
    WGPUgfx.prepareObject(device, demo.fontRenderable)
    
    # NOTE: We don't add to scene.objects because we want to render it directly
    # This avoids the WGPUgfx shader compilation that causes issues
    
    return demo
end

function update_demo(demo::AnimatedTextDemo, deltaTime::Float32)
    # Update animation time
    demo.time += deltaTime
    
    # Animate text in a circular path
    radius = 150.0f0
    centerX = 400.0f0
    centerY = 300.0f0
    x = centerX + radius * cos(demo.time)
    y = centerY + radius * sin(demo.time)
    WGPUFontRenderer.setPosition!(demo.fontRenderable, x, y)
    
    # Change text color over time
    r = 0.5f0 + 0.5f0 * sin(demo.time)
    g = 0.5f0 + 0.5f0 * cos(demo.time * 0.7f0)
    b = 0.5f0 + 0.5f0 * sin(demo.time * 1.3f0)
    demo.fontRenderable.color = [r, g, b, 1.0f0]
end

function render_demo(demo::AnimatedTextDemo)
    # Initialize renderer for frame (WGPUgfx pattern)
    WGPUgfx.init(demo.renderer)
    
    # Get current render pass
    renderPass = demo.renderer.currentRenderPass
    
    # Render our font directly (bypassing WGPUgfx pipeline)
    if renderPass !== nothing
        WGPUFontRenderer.renderText(demo.fontRenderable.fontRenderer, renderPass)
    end
    
    # Clean up renderer (WGPUgfx pattern)
    WGPUgfx.deinit(demo.renderer)
end

function run_demo()
    println("🚀 Starting WGPUFontRenderer + WGPUgfx Animated Text Demo")
    println("   - Text animates in a circular path")
    println("   - Text color changes over time")
    println("   - Press ESC or close window to exit")
    println()
    
    # Initialize the demo
    demo = AnimatedTextDemo()
    init_demo(demo)
    
    # Main render loop
    lastTime = time()
    frameCount = 0
    
    while !GLFW.WindowShouldClose(demo.scene.canvas.window)
        currentTime = time()
        deltaTime = Float32(currentTime - lastTime)
        lastTime = currentTime
        
        # Update demo state
        update_demo(demo, deltaTime)
        
        # Render frame
        render_demo(demo)
        
        # Poll events
        GLFW.PollEvents()
        
        # Handle ESC key
        if GLFW.GetKey(demo.scene.canvas.window, GLFW.KEY_ESCAPE) == GLFW.PRESS
            break
        end
        
        # Frame counter
        frameCount += 1
        if frameCount % 300 == 0
            println("Rendered $frameCount frames...")
        end
    end
    
    println("Demo finished after $frameCount frames.")
end

# Run the demo if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_demo()
end