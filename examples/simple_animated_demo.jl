# Simple Animated Text Demo for WGPU Font Renderer
# Demonstrates moving text around the screen

using WGPUCore
using WGPUNative
using WGPUCanvas
using WGPUFontRenderer
using WGPUFontRenderer: setPosition, generateVertexData
using GLFW

"""
Simple Animated Text Demo - Moving a single text element in a circle
"""

mutable struct SimpleAnimatedDemo
    canvas::WGPUCore.AbstractWGPUCanvas
    device::WGPUCore.GPUDevice
    queue::WGPUCore.GPUQueue
    fontRenderer::FontRenderer
    depthTexture::Union{WGPUCore.GPUTexture, Nothing}
    depthTextureView::Union{WGPUCore.GPUTextureView, Nothing}

    # Animation state
    angle::Float32
    centerX::Float32
    centerY::Float32
    radius::Float32

    function SimpleAnimatedDemo()
        new()
    end
end

function init_demo(demo::SimpleAnimatedDemo)
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
    demo.angle = 0.0f0
    demo.centerX = 400.0f0
    demo.centerY = 300.0f0
    demo.radius = 200.0f0

    return demo
end

function update_animation(demo::SimpleAnimatedDemo, deltaTime::Float32)
    # Update angle (1 rotation per 4 seconds)
    demo.angle += 2.0f0 * π * deltaTime / 4.0f0

    # Keep angle in reasonable range
    if demo.angle > 2.0f0 * π
        demo.angle -= 2.0f0 * π
    end
end

function render_frame(demo::SimpleAnimatedDemo)
    try
        # Calculate text position
        x = demo.centerX + demo.radius * cos(demo.angle)
        y = demo.centerY + demo.radius * sin(demo.angle)

        # Position text using our layout engine
        setPosition(demo.fontRenderer, "Moving Text!", x, y)

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

        # Create render pass with dark background
        renderPassOptions = [
            WGPUCore.GPUColorAttachments => [
                :attachments => [
                    WGPUCore.GPUColorAttachment => [
                        :view => currentTextureView,
                        :resolveTarget => C_NULL,
                        :clearValue => (0.0, 0.0, 0.2, 1.0),  # Dark blue background
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

        # Render the text
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

function cleanup_demo(demo::SimpleAnimatedDemo)
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

function run_simple_animated_demo()
    println("🎭 Simple Animated Text Demo - Moving Text in a Circle")
    println("Text moves in a circular path using setPosition()")

    # Initialize demo
    demo = SimpleAnimatedDemo()
    init_demo(demo)

    println("Font renderer initialized successfully")
    println("Text: 'Moving Text!'")
    println("Path: Circular motion around center")
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

            # Frame rate limiting (~60 FPS)
            sleep(0.016)
        end
    catch e
        println("Animation loop interrupted: ", e)
    finally
        # Cleanup
        cleanup_demo(demo)
        WGPUCore.destroyWindow(demo.canvas)
        println("Simple animated demo completed")
    end
end

# Run the demo if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_simple_animated_demo()
end
