# WGPUgfx Font RenderableUI Example
# This example demonstrates how to use the FontRenderableUI with WGPUgfx

using WGPUCore
using WGPUgfx
using WGPUCanvas
using GLFW
using WGPUFontRenderer

# Simple demo application that integrates font rendering with WGPUgfx
mutable struct WGPUgfxFontDemoApp
    canvas::WGPUCore.AbstractWGPUCanvas
    device::WGPUCore.GPUDevice
    queue::WGPUCore.GPUQueue
    renderer::WGPUgfx.Renderer
    fontRenderable::WGPUFontRenderer.FontRenderableUI
    time::Float32
end

function WGPUgfxFontDemoApp()
    return new()
end

function init_app(app::WGPUgfxFontDemoApp)
    # Initialize WGPU - following WGPUgfx pattern
    app.canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    app.device = WGPUCore.getDefaultDevice(app.canvas)
    app.queue = app.device.queue
    app.time = 0.0f0
    
    # Create WGPUgfx renderer
    app.renderer = WGPUgfx.Renderer(app.canvas, app.device)
    
    # Create font renderable UI (now available directly in WGPUFontRenderer)
    app.fontRenderable = WGPUFontRenderer.defaultFontRenderableUI(
        app.device, 
        app.queue, 
        "Hello WGPUgfx!", 
        position=[100.0f0, 100.0f0],
        color=[1.0f0, 0.0f0, 0.0f0, 1.0f0]  # Red text
    )
    
    # Prepare the font object for rendering
    WGPUgfx.prepareObject(app.device, app.fontRenderable)
    
    return app
end

function update_app(app::WGPUgfxFontDemoApp, deltaTime::Float32)
    # Update animation time
    app.time += deltaTime
    
    # Animate the font position
    WGPUFontRenderer.animatePosition!(app.fontRenderable, app.time)
end

function render_app(app::WGPUgfxFontDemoApp)
    # Begin rendering frame
    WGPUgfx.beginFrame(app.renderer)
    
    # Render the font
    # Note: In a full implementation, this would be integrated with the scene graph
    # For now, we'll call our custom render function directly
    
    # Get current render pass
    renderPass = app.renderer.currentRenderPass
    
    if renderPass !== nothing
        # Render the font using our custom renderer
        WGPUFontRenderer.renderText(app.fontRenderable.fontRenderer, renderPass)
    end
    
    # End rendering frame
    WGPUgfx.endFrame(app.renderer)
end

function run_demo()
    println("Starting WGPUgfx Font RenderableUI Demo...")
    
    # Initialize the application
    app = WGPUgfxFontDemoApp()
    init_app(app)
    
    # Main render loop
    lastTime = time()
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
    end
    
    println("Demo finished.")
end

# Run the demo if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_demo()
end