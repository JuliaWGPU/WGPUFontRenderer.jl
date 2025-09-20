# Animated Text Demo for WGPU Font Renderer
# Demonstrates dynamic text positioning with smooth movement

using WGPUCore
using WGPUNative
using WGPUCanvas
using WGPUFontRenderer
using GLFW

"""
Animated Text Demo - Moving text around the screen
"""

mutable struct AnimatedTextDemo
    canvas::WGPUCore.AbstractWGPUCanvas
    device::WGPUCore.GPUDevice
    queue::WGPUCore.GPUQueue
    fontRenderer::FontRenderer
    depthTexture::Union{WGPUCore.GPUTexture, Nothing}
    depthTextureView::Union{WGPUCore.GPUTextureView, Nothing}
    
    # Animation state
    animationTime::Float32
    textElements::Vector{Dict{String, Any}}
    
    function AnimatedTextDemo()
        new()
    end
end

function init_demo(demo::AnimatedTextDemo)
    # Initialize WGPU
    demo.canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    demo.device = WGPUCore.getDefaultDevice(demo.canvas)
    demo.queue = demo.device.queue
    
    # Get surface format  
    surfaceFormat = WGPUCore.getPreferredFormat(demo.canvas)
    
    # Configure context
    presentContext = WGPUCore.getContext(demo.canvas)
    WGPUCore.config(presentContext; device=demo.device, format=surfaceFormat)
    
    # Create font renderer
    demo.fontRenderer = createFontRenderer(demo.device, demo.queue)
    initializeRenderer(demo.fontRenderer, surfaceFormat)
    
    # Initialize depth texture fields
    demo.depthTexture = nothing
    demo.depthTextureView = nothing
    
    # Initialize animation state
    demo.animationTime = 0.0f0
    
    # Create text elements with different animation behaviors
    demo.textElements = [
        # Bouncing text
        Dict(
            "text" => "Bouncing!",
            "x" => 100.0f0,
            "y" => 100.0f0,
            "vx" => 100.0f0,  # pixels per second
            "vy" => 80.0f0,
            "color" => (1.0, 0.0, 0.0, 1.0),  # Red
            "animation" => "bounce"
        ),
        
        # Circular motion text
        Dict(
            "text" => "Circular",
            "centerX" => 400.0f0,
            "centerY" => 300.0f0,
            "radius" => 150.0f0,
            "angle" => 0.0f0,
            "speed" => 1.0f0,  # radians per second
            "color" => (0.0, 1.0, 0.0, 1.0),  # Green
            "animation" => "circle"
        ),
        
        # Pulsing text
        Dict(
            "text" => "Pulse",
            "x" => 600.0f0,
            "y" => 100.0f0,
            "scale" => 1.0f0,
            "scaleDir" => 1.0f0,
            "color" => (0.0, 0.0, 1.0, 1.0),  # Blue
            "animation" => "pulse"
        ),
        
        # Wave motion text
        Dict(
            "text" => "Wave",
            "x" => 50.0f0,
            "baseY" => 500.0f0,
            "wavePhase" => 0.0f0,
            "waveSpeed" => 2.0f0,
            "waveAmplitude" => 30.0f0,
            "color" => (1.0, 1.0, 0.0, 1.0),  # Yellow
            "animation" => "wave"
        )
    ]
    
    return demo
end

function update_animation(demo::AnimatedTextDemo, deltaTime::Float32)
    demo.animationTime += deltaTime
    
    canvasSize = demo.canvas.size
    width = Float32(canvasSize[1])
    height = Float32(canvasSize[2])
    
    # Update each text element
    for element in demo.textElements
        if element["animation"] == "bounce"
            # Update position
            element["x"] += element["vx"] * deltaTime
            element["y"] += element["vy"] * deltaTime
            
            # Bounce off walls
            if element["x"] <= 0.0f0 || element["x"] >= width - 100.0f0
                element["vx"] = -element["vx"]
                element["x"] = clamp(element["x"], 0.0f0, width - 100.0f0)
            end
            
            if element["y"] <= 0.0f0 || element["y"] >= height - 50.0f0
                element["vy"] = -element["vy"]
                element["y"] = clamp(element["y"], 0.0f0, height - 50.0f0)
            end
            
        elseif element["animation"] == "circle"
            # Update angle
            element["angle"] += element["speed"] * deltaTime
            
            # Update position in circular motion
            element["x"] = element["centerX"] + element["radius"] * cos(element["angle"])
            element["y"] = element["centerY"] + element["radius"] * sin(element["angle"])
            
        elseif element["animation"] == "pulse"
            # Update scale
            element["scale"] += element["scaleDir"] * 0.5f0 * deltaTime
            
            # Reverse direction at limits
            if element["scale"] >= 2.0f0 || element["scale"] <= 0.5f0
                element["scaleDir"] = -element["scaleDir"]
                element["scale"] = clamp(element["scale"], 0.5f0, 2.0f0)
            end
            
        elseif element["animation"] == "wave"
            # Update wave phase
            element["wavePhase"] += element["waveSpeed"] * deltaTime
            
            # Update position with wave motion
            element["y"] = element["baseY"] + element["waveAmplitude"] * sin(element["wavePhase"])
            element["x"] += 50.0f0 * deltaTime  # Move right
            
            # Wrap around
            if element["x"] > width + 100.0f0
                element["x"] = -100.0f0
            end
        end
    end
end

function render_text_elements(demo::AnimatedTextDemo)
    # For this demo, we'll render each text element separately
    # In a real implementation, you'd batch them together
    
    canvasSize = demo.canvas.size
    width = Float32(canvasSize[1])
    height = Float32(canvasSize[2])
    
    # Render each animated text element
    for element in demo.textElements
        if element["animation"] == "bounce"
            setPosition(demo.fontRenderer, element["text"], element["x"], element["y"])
            
        elseif element["animation"] == "circle"
            setPosition(demo.fontRenderer, element["text"], element["x"], element["y"])
            
        elseif element["animation"] == "pulse"
            # For pulse animation, we'd normally scale the text
            # For simplicity, we'll just position it normally
            setPosition(demo.fontRenderer, element["text"], element["x"], element["y"])
            
        elseif element["animation"] == "wave"
            setPosition(demo.fontRenderer, element["text"], element["x"], element["y"])
        end
    end
end

function cleanup_demo(demo::AnimatedTextDemo)
    # Clean up depth texture resources
    if demo.depthTextureView !== nothing
        try
            WGPUCore.destroy(demo.depthTextureView)
        catch e
            @warn "Error destroying depth texture view: $e"
        end
        demo.depthTextureView = nothing
    end
    
    if demo.depthTexture !== nothing
        try
            WGPUCore.destroy(demo.depthTexture)
        catch e
            @warn "Error destroying depth texture: $e"
        end
        demo.depthTexture = nothing
    end
end

function render_frame(demo::AnimatedTextDemo)
    try
        # Get current surface texture
        presentContext = WGPUCore.getContext(demo.canvas)
        currentTextureView = WGPUCore.getCurrentTexture(presentContext)
        
        # Create command encoder
        cmdEncoder = WGPUCore.createCommandEncoder(demo.device, "Animated Text Encoder")
        
        # Get current canvas size
        canvasSize = demo.canvas.size
        
        # Create depth texture if needed
        if demo.depthTexture === nothing || demo.depthTextureView === nothing
            demo.depthTexture = WGPUCore.createTexture(
                demo.device,
                "Depth Texture",
                (canvasSize[1], canvasSize[2], 1),
                1, 1,
                WGPUCore.WGPUTextureDimension_2D, 
                WGPUNative.LibWGPU.WGPUTextureFormat_Depth24Plus,
                WGPUCore.getEnum(WGPUCore.WGPUTextureUsage, ["RenderAttachment"])
            )
            
            demo.depthTextureView = WGPUCore.createView(demo.depthTexture)
        end
        
        # Create render pass
        renderPassOptions = [
            WGPUCore.GPUColorAttachments => [
                :attachments => [
                    WGPUCore.GPUColorAttachment => [
                        :view => currentTextureView,
                        :resolveTarget => C_NULL,
                        :clearValue => (0.1, 0.1, 0.2, 1.0),  # Dark blue background
                        :loadOp => WGPUCore.WGPULoadOp_Clear,
                        :storeOp => WGPUCore.WGPUStoreOp_Store,
                    ],
                ],
            ],
            WGPUCore.GPUDepthStencilAttachments => [
                :attachments => [
                    WGPUCore.GPUDepthStencilAttachment => [
                        :view => demo.depthTextureView,
                        :depthClearValue => 1.0,
                        :depthLoadOp => WGPUCore.WGPULoadOp_Clear,
                        :depthStoreOp => WGPUCore.WGPUStoreOp_Store,
                        :stencilClearValue => 0,
                        :stencilLoadOp => WGPUCore.WGPULoadOp_Clear,
                        :stencilStoreOp => WGPUCore.WGPUStoreOp_Store
                    ],
                ],
            ],
        ]
        
        # Begin render pass
        renderPass = WGPUCore.beginRenderPass(
            cmdEncoder,
            renderPassOptions |> Ref;
            label = "Animated Text Render Pass",
        )
        
        # Render all text elements
        render_text_elements(demo)
        renderText(demo.fontRenderer, renderPass)
        
        # End render pass and submit
        WGPUCore.endEncoder(renderPass)
        WGPUCore.submit(demo.queue, [WGPUCore.finish(cmdEncoder)])
        
        # Present the frame
        WGPUCore.present(presentContext)
        
    catch e
        @warn "Rendering error: $e"
    end
end

function run_animated_demo()
    println("🎭 Animated Text Demo - Moving Text Around the Screen")
    println("Following gpu-font-renderer pattern with WGPUCore and WGPUgfx")
    
    # Initialize demo
    demo = AnimatedTextDemo()
    init_demo(demo)
    
    println("Font renderer initialized successfully")
    println("Animation types: Bouncing, Circular, Pulsing, Wave motion")
    println("Press ESC or close window to exit")
    
    # Main render loop
    lastTime = time()
    try
        while true
            # Check if window should close
            if GLFW.WindowShouldClose(demo.canvas.windowRef[])
                break
            end
            
            # Calculate delta time
            currentTime = time()
            deltaTime = Float32(currentTime - lastTime)
            lastTime = currentTime
            
            # Update animation
            update_animation(demo, deltaTime)
            
            # Render frame
            render_frame(demo)
            
            # Poll events
            GLFW.PollEvents()
            
            # Frame rate limiting
            sleep(0.016)  # ~60 FPS
        end
    catch e
        println("Animation loop interrupted: ", e)
    finally
        # Cleanup
        cleanup_demo(demo)
        WGPUCore.destroyWindow(demo.canvas)
        println("Animated demo completed")
    end
end

# Run the demo if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_animated_demo()
end
# Additional helper functions
function render_text_elements(demo::AnimatedTextDemo)
    # Clear previous text
    clearText(demo.fontRenderer)
