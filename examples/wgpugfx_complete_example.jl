# Complete WGPUgfx Font Integration Example
#
# This example demonstrates how to use WGPUFontRenderer with WGPUgfx.
# It shows a simple animated text display that moves in a circle.

using WGPUCore
using WGPUgfx
using WGPUCanvas
using GLFW
using WGPUFontRenderer

# Demo application structure
mutable struct FontDemo
    canvas::WGPUCore.AbstractWGPUCanvas
    device::WGPUCore.GPUDevice
    queue::WGPUCore.GPUQueue
    renderer::WGPUgfx.Renderer
    fontRenderable::WGPUFontRenderer.FontRenderableUI
    time::Float32
end

function FontDemo()
    return new()
end

function initialize_demo(demo::FontDemo)
    println("Initializing WGPUFontRenderer WGPUgfx demo...")
    
    # Create window and GPU context
    demo.canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    demo.device = WGPUCore.getDefaultDevice(demo.canvas)
    demo.queue = demo.device.queue
    demo.time = 0.0f0
    
    # Set window title
    GLFW.SetWindowTitle(demo.canvas.window, "WGPUFontRenderer WGPUgfx Integration Demo")
    
    # Create renderer
    demo.renderer = WGPUgfx.Renderer(demo.canvas, demo.device)
    
    # Create animated font renderable
    demo.fontRenderable = WGPUFontRenderer.defaultFontRenderableUI(
        demo.device,
        demo.queue,
        "Hello WGPUgfx!",  # Text to display
        position=[400.0f0, 300.0f0],  # Center of screen
        color=[1.0f0, 0.5f0, 0.0f0, 1.0f0]  # Orange text
    )
    
    # Prepare the font object for WGPUgfx rendering
    WGPUgfx.prepareObject(demo.device, demo.fontRenderable)
    
    println("Demo initialized successfully!")
    return demo
end

function update_demo(demo::FontDemo, deltaTime::Float32)
    # Update animation time
    demo.time += deltaTime
    
    # Animate the text in a circular motion
    # Circle centered at (400, 300) with radius 100
    center_x = 400.0f0
    center_y = 300.0f0
    radius = 100.0f0
    speed = 1.0f0  # radians per second
    
    x = center_x + radius * cos(demo.time * speed)
    y = center_y + radius * sin(demo.time * speed)
    
    # Update font position
    WGPUFontRenderer.setPosition!(demo.fontRenderable, x, y)
    
    # Optional: Change text color over time
    r = 0.5f0 + 0.5f0 * sin(demo.time * 0.5f0)
    g = 0.5f0 + 0.5f0 * sin(demo.time * 0.5f0 + 2.0f0)
    b = 0.5f0 + 0.5f0 * sin(demo.time * 0.5f0 + 4.0f0)
    # Note: Color animation would require modifying the font renderer's color handling
    
    return true  # Continue running
end

function render_demo(demo::FontDemo)
    # Begin rendering frame
    WGPUgfx.beginFrame(demo.renderer)
    
    # Get current render pass
    renderPass = demo.renderer.currentRenderPass
    
    if renderPass !== nothing
        # Render the font using the integrated renderer
        WGPUFontRenderer.renderText(demo.fontRenderable.fontRenderer, renderPass)
    end
    
    # End rendering frame
    WGPUgfx.endFrame(demo.renderer)
    
    return true  # Continue running
end

function run_demo()
    println("Starting WGPUFontRenderer WGPUgfx Integration Demo")
    println("Press ESC to exit")
    println()
    
    # Create and initialize demo
    demo = FontDemo()
    initialize_demo(demo)
    
    # Main loop
    lastTime = time()
    frameCount = 0
    lastFPSTime = lastTime
    
    while !GLFW.WindowShouldClose(demo.canvas.window)
        # Calculate delta time
        currentTime = time()
        deltaTime = Float32(currentTime - lastTime)
        lastTime = currentTime
        
        # Update demo state
        if !update_demo(demo, deltaTime)
            break
        end
        
        # Render frame
        if !render_demo(demo)
            break
        end
        
        # Poll events
        GLFW.PollEvents()
        
        # Exit on ESC key
        if GLFW.GetKey(demo.canvas.window, GLFW.KEY_ESCAPE) == GLFW.PRESS
            println("ESC pressed - exiting demo")
            break
        end
        
        # Print FPS every 2 seconds
        frameCount += 1
        if currentTime - lastFPSTime > 2.0
            fps = frameCount / (currentTime - lastFPSTime)
            print("\rFPS: $(round(fps, digits=1))")
            flush(stdout)
            frameCount = 0
            lastFPSTime = currentTime
        end
    end
    
    println("\nDemo finished.")
    return true
end

# Main execution
function main()
    try
        run_demo()
        println("Demo completed successfully!")
    catch e
        println("Demo failed with error: ", e)
        println("Stacktrace:")
        Base.showerror(stdout, e, catch_backtrace())
        println()
        return false
    end
    
    return true
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

println("WGPUFontRenderer WGPUgfx Integration Example")
println("=============================================")
println("To run this example, execute:")
println("  julia --project=. examples/wgpugfx_complete_example.jl")
println()
println("Features demonstrated:")
println("- FontRenderableUI integration with WGPUgfx")
println("- Animated text positioning")
println("- Real-time rendering loop")
println("- Proper resource management")
println("- FPS monitoring")