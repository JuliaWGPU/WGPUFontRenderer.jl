# Animated Font Demo for WGPUgfx Integration
# Demonstrates various animation effects using FontRenderableUI

using WGPUCore
using WGPUgfx
using WGPUCanvas
using GLFW
using WGPUFontRenderer

mutable struct AnimatedFontDemo
    canvas::WGPUCore.AbstractWGPUCanvas
    device::WGPUCore.GPUDevice
    queue::WGPUCore.GPUQueue
    renderer::WGPUgfx.Renderer
    fontRenderables::Vector{WGPUFontRenderer.FontRenderableUI}
    time::Float32
end

function AnimatedFontDemo()
    return new()
end

function init_demo(demo::AnimatedFontDemo)
    # Initialize WGPU
    demo.canvas = WGPUCore.getCanvas(:GLFW, (1200, 800))
    demo.device = WGPUCore.getDefaultDevice(demo.canvas)
    demo.queue = demo.device.queue
    demo.time = 0.0f0
    
    # Create renderer
    demo.renderer = WGPUgfx.Renderer(demo.canvas, demo.device)
    
    # Create multiple animated font renderables
    demo.fontRenderables = WGPUFontRenderer.FontRenderableUI[]
    
    # 1. Bouncing text
    bouncingText = WGPUFontRenderer.defaultFontRenderableUI(
        demo.device, 
        demo.queue, 
        "Bouncing Text!", 
        position=[100.0f0, 100.0f0],
        color=[1.0f0, 0.0f0, 0.0f0, 1.0f0]  # Red
    )
    push!(demo.fontRenderables, bouncingText)
    
    # 2. Rotating text
    rotatingText = WGPUFontRenderer.defaultFontRenderableUI(
        demo.device, 
        demo.queue, 
        "Rotating Text!", 
        position=[100.0f0, 200.0f0],
        color=[0.0f0, 1.0f0, 0.0f0, 1.0f0]  # Green
    )
    push!(demo.fontRenderables, rotatingText)
    
    # 3. Pulsing text
    pulsingText = WGPUFontRenderer.defaultFontRenderableUI(
        demo.device, 
        demo.queue, 
        "Pulsing Text!", 
        position=[100.0f0, 300.0f0],
        color=[0.0f0, 0.0f0, 1.0f0, 1.0f0]  # Blue
    )
    push!(demo.fontRenderables, pulsingText)
    
    # 4. Color cycling text
    colorText = WGPUFontRenderer.defaultFontRenderableUI(
        demo.device, 
        demo.queue, 
        "Color Cycle!", 
        position=[100.0f0, 400.0f0],
        color=[1.0f0, 1.0f0, 0.0f0, 1.0f0]  # Yellow
    )
    push!(demo.fontRenderables, colorText)
    
    # Prepare all font objects
    for fontObj in demo.fontRenderables
        WGPUgfx.prepareObject(demo.device, fontObj)
    end
    
    return demo
end

function update_demo(demo::AnimatedFontDemo, deltaTime::Float32)
    demo.time += deltaTime
    
    # Update each font renderable with different animations
    if length(demo.fontRenderables) >= 4
        # 1. Bouncing text (vertical bounce)
        bounceHeight = 50.0f0 * sin(demo.time * 2.0f0)
        WGPUFontRenderer.setPosition!(demo.fontRenderables[1], 100.0f0, 100.0f0 + abs(bounceHeight))
        
        # 2. Rotating text (we'll simulate rotation with position)
        radius = 100.0f0
        rotX = 400.0f0 + radius * cos(demo.time * 1.5f0)
        rotY = 200.0f0 + radius * sin(demo.time * 1.5f0)
        WGPUFontRenderer.setPosition!(demo.fontRenderables[2], rotX, rotY)
        
        # 3. Pulsing text (scale animation would go here)
        
        # 4. Color cycling text (color animation would go here)
    end
end

function render_demo(demo::AnimatedFontDemo)
    # Begin frame
    WGPUgfx.beginFrame(demo.renderer)
    
    # Get current render pass
    renderPass = demo.renderer.currentRenderPass
    
    if renderPass !== nothing
        # Render all font objects
        for fontObj in demo.fontRenderables
            WGPUFontRenderer.renderText(fontObj.fontRenderer, renderPass)
        end
    end
    
    # End frame
    WGPUgfx.endFrame(demo.renderer)
end

function run_animated_demo()
    println("Starting Animated Font Demo with WGPUgfx Integration...")
    println("Press ESC to exit")
    
    # Initialize demo
    demo = AnimatedFontDemo()
    init_demo(demo)
    
    # Main loop
    lastTime = time()
    while !GLFW.WindowShouldClose(demo.canvas.window)
        currentTime = time()
        deltaTime = Float32(currentTime - lastTime)
        lastTime = currentTime
        
        # Update
        update_demo(demo, deltaTime)
        
        # Render
        render_demo(demo)
        
        # Poll events
        GLFW.PollEvents()
        
        # Exit on ESC key
        if GLFW.GetKey(demo.canvas.window, GLFW.KEY_ESCAPE) == GLFW.PRESS
            break
        end
    end
    
    println("Animated demo finished.")
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_animated_demo()
end