# WGPUFontRenderer + WGPUgfx Integration Example
# Complete working example showing FontRenderableUI integrated with WGPUgfx scene graph

using WGPUCore
using WGPUgfx
using WGPUCanvas
using GLFW
using WGPUFontRenderer

# Complete demo application that integrates font rendering with WGPUgfx
mutable struct FontRenderableUIDemoApp
    canvas::WGPUCore.AbstractWGPUCanvas
    device::WGPUCore.GPUDevice
    queue::WGPUCore.GPUQueue
    renderer::WGPUgfx.Renderer
    fontRenderable::WGPUFontRenderer.FontRenderableUI
    backgroundQuad::WGPUgfx.Quad
    time::Float32
end

function FontRenderableUIDemoApp()
    return new()
end

function init_app(app::FontRenderableUIDemoApp)
    # Initialize WGPU - following WGPUgfx pattern
    app.canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    app.device = WGPUCore.getDefaultDevice(app.canvas)
    app.queue = app.device.queue
    app.time = 0.0f0
    
    # Create WGPUgfx renderer
    app.renderer = WGPUgfx.Renderer(app.canvas, app.device)
    
    # Create a background quad for visual context
    app.backgroundQuad = WGPUgfx.defaultQuad(
        scale=[2.0f0, 1.5f0, 1.0f0, 1.0f0],  # Full screen
        color=[0.9f0, 0.9f0, 0.95f0, 1.0f0]  # Light blue background
    )
    WGPUgfx.prepareObject(app.device, app.backgroundQuad)
    
    # Create font renderable UI
    app.fontRenderable = WGPUFontRenderer.defaultFontRenderableUI(
        app.device, 
        app.queue, 
        "Hello WGPUgfx Integration!", 
        position=[100.0f0, 300.0f0],
        color=[0.2f0, 0.4f0, 0.8f0, 1.0f0]  # Blue text
    )
    
    # Prepare the font object for rendering
    WGPUgfx.prepareObject(app.device, app.fontRenderable)
    
    return app
end

function update_app(app::FontRenderableUIDemoApp, deltaTime::Float32)
    # Update animation time
    app.time += deltaTime
    
    # Animate the font position in a circular motion
    radius = 100.0f0
    centerX = 400.0f0
    centerY = 300.0f0
    x = centerX + radius * cos(app.time)
    y = centerY + radius * sin(app.time)
    WGPUFontRenderer.setPosition!(app.fontRenderable, x, y)
    
    # Change text every 5 seconds
    if app.time % 10.0f0 < 5.0f0 && app.fontRenderable.text != "WGPUFontRenderer + WGPUgfx"
        WGPUFontRenderer.setText!(app.fontRenderable, "WGPUFontRenderer + WGPUgfx")
    elseif app.time % 10.0f0 >= 5.0f0 && app.fontRenderable.text != "Hello WGPUgfx Integration!"
        WGPUFontRenderer.setText!(app.fontRenderable, "Hello WGPUgfx Integration!")
    end
end

function render_app(app::FontRenderableUIDemoApp)
    # Begin rendering frame
    WGPUgfx.beginFrame(app.renderer)
    
    # Get current render pass
    renderPass = app.renderer.currentRenderPass
    
    if renderPass !== nothing
        # Render background quad first
        WGPUgfx.render(renderPass, nothing, app.backgroundQuad, 1)
        
        # Render the font using WGPUgfx's render system
        WGPUgfx.render(renderPass, nothing, app.fontRenderable, 1)
    end
    
    # End rendering frame
    WGPUgfx.endFrame(app.renderer)
end

function run_demo()
    println("Starting FontRenderableUI + WGPUgfx Integration Demo...")
    println("Features demonstrated:")
    println("  - FontRenderableUI integrated with WGPUgfx scene graph")
    println("  - Animated text position")
    println("  - Dynamic text content changes")
    println("  - Proper cleanup and resource management")
    println()
    
    # Initialize the application
    app = FontRenderableUIDemoApp()
    init_app(app)
    
    # Main render loop
    lastTime = time()
    frameCount = 0
    
    while !GLFW.WindowShouldClose(app.canvas.window)
        currentTime = time()
        deltaTime = Float32(currentTime - lastTime)
        lastTime = currentTime
        
        # Update application state
        update_app(app, deltaTime)
        
        # Render frame
        render_app(app)
        
        # Poll events
        GLFW.PollEvents()
        
        # Frame counter for debugging
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