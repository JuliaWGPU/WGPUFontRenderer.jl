# WGPUFontRenderer Scene Integration Example
#
# This example shows how to integrate font rendering into an existing WGPUgfx scene.
# It demonstrates mixing font rendering with other WGPUgfx renderables.

using WGPUCore
using WGPUgfx
using WGPUCanvas
using GLFW
using WGPUFontRenderer

# Demo showing integration with other WGPUgfx objects
mutable struct SceneDemo
    canvas::WGPUCore.AbstractWGPUCanvas
    device::WGPUCore.GPUDevice
    queue::WGPUCore.GPUQueue
    renderer::WGPUgfx.Renderer
    fontRenderables::Vector{WGPUFontRenderer.FontRenderableUI}
    quad::Any  # WGPUgfx quad (using Any to avoid deep dependencies)
    time::Float32
end

function SceneDemo()
    return new()
end

function initialize_scene_demo(demo::SceneDemo)
    println("Initializing WGPUFontRenderer Scene Integration Demo...")
    
    # Create window and GPU context
    demo.canvas = WGPUCore.getCanvas(:GLFW, (1024, 768))
    demo.device = WGPUCore.getDefaultDevice(demo.canvas)
    demo.queue = demo.device.queue
    demo.time = 0.0f0
    
    # Set window title
    GLFW.SetWindowTitle(demo.canvas.window, "WGPUFontRenderer Scene Integration Demo")
    
    # Create renderer
    demo.renderer = WGPUgfx.Renderer(demo.canvas, demo.device)
    
    # Create multiple font renderables for different UI elements
    demo.fontRenderables = WGPUFontRenderer.FontRenderableUI[]
    
    # Title text
    title = WGPUFontRenderer.defaultFontRenderableUI(
        demo.device,
        demo.queue,
        "WGPUFontRenderer Demo",
        position=[512.0f0, 50.0f0],  # Top center
        color=[1.0f0, 1.0f0, 1.0f0, 1.0f0]  # White
    )
    push!(demo.fontRenderables, title)
    
    # Animated counter text
    counter = WGPUFontRenderer.defaultFontRenderableUI(
        demo.device,
        demo.queue,
        "Frame: 0",
        position=[50.0f0, 50.0f0],  # Top left
        color=[0.0f0, 1.0f0, 0.0f0, 1.0f0]  # Green
    )
    push!(demo.fontRenderables, counter)
    
    # Instructions
    instructions = WGPUFontRenderer.defaultFontRenderableUI(
        demo.device,
        demo.queue,
        "Press SPACE to add text | ESC to exit",
        position=[512.0f0, 700.0f0],  # Bottom center
        color=[1.0f0, 1.0f0, 0.0f0, 1.0f0]  # Yellow
    )
    push!(demo.fontRenderables, instructions)
    
    # Prepare all font objects
    for fontObj in demo.fontRenderables
        WGPUgfx.prepareObject(demo.device, fontObj)
    end
    
    # Note: In a real application, you would also create and prepare
    # other WGPUgfx renderables like quads, meshes, etc.
    # demo.quad = WGPUgfx.defaultQuad(...)  # Example of other renderable
    
    println("Scene demo initialized with $(length(demo.fontRenderables)) text elements")
    return demo
end

function update_scene_demo(demo::SceneDemo, deltaTime::Float32)
    # Update animation time
    demo.time += deltaTime
    
    # Update counter text
    if length(demo.fontRenderables) >= 2
        frameText = "Frame: $(Int(floor(demo.time * 60)))"
        WGPUFontRenderer.setText!(demo.fontRenderables[2], frameText)
    end
    
    # Animate title text (subtle floating effect)
    if length(demo.fontRenderables) >= 1
        baseY = 50.0f0
        floatOffset = 5.0f0 * sin(demo.time * 2.0f0)
        WGPUFontRenderer.setPosition!(demo.fontRenderables[1], 512.0f0, baseY + floatOffset)
    end
    
    # Handle user input
    if GLFW.GetKey(demo.canvas.window, GLFW.KEY_SPACE) == GLFW.PRESS
        # Add new text element (in a real app)
        # This is just a demonstration of the API
        println("SPACE pressed - would add new text element")
    end
    
    return true
end

function render_scene_demo(demo::SceneDemo)
    # Begin rendering frame
    WGPUgfx.beginFrame(demo.renderer)
    
    # Get current render pass
    renderPass = demo.renderer.currentRenderPass
    
    if renderPass !== nothing
        # Render all font objects
        for fontObj in demo.fontRenderables
            WGPUFontRenderer.renderText(fontObj.fontRenderer, renderPass)
        end
        
        # Render other WGPUgfx objects
        # WGPUgfx.render(renderPass, renderOptions, demo.quad, cameraId)
        # ... other renderables ...
    end
    
    # End rendering frame
    WGPUgfx.endFrame(demo.renderer)
    
    return true
end

function run_scene_demo()
    println("Starting WGPUFontRenderer Scene Integration Demo")
    println("Controls:")
    println("  SPACE - Add new text element (demo)")
    println("  ESC   - Exit demo")
    println()
    
    # Create and initialize demo
    demo = SceneDemo()
    initialize_scene_demo(demo)
    
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
        if !update_scene_demo(demo, deltaTime)
            break
        end
        
        # Render frame
        if !render_scene_demo(demo)
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
            print("\rFPS: $(round(fps, digits=1)) - Frame: $(Int(floor(demo.time * 60)))")
            flush(stdout)
            frameCount = 0
            lastFPSTime = currentTime
        end
    end
    
    println("\nScene demo finished.")
    return true
end

# Main execution
function main()
    try
        run_scene_demo()
        println("Scene demo completed successfully!")
    catch e
        println("Scene demo failed with error: ", e)
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

println("WGPUFontRenderer Scene Integration Example")
println("==========================================")
println("This example shows how to integrate font rendering")
println("into a complete WGPUgfx scene with multiple elements.")
println()
println("To run this example:")
println("  julia --project=. examples/wgpugfx_scene_example.jl")