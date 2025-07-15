# Font Rendering Demo using WGPUCanvas
# This example demonstrates vector font rendering using the GPU-based approach

using WGPUCanvas
using WGPUCore
using WGPUFontRenderer
using GLFW

# Demo application structure
mutable struct FontDemoApp
    canvas::WGPUCore.AbstractWGPUCanvas
    fontRenderer::FontRenderer
    textToRender::String
    
    function FontDemoApp()
        new()
    end
end

function init_app(app::FontDemoApp)
    # Create canvas
    app.canvas = WGPUCore.getCanvas(:GLFW, (800, 600)) # Use GLFW based canvas for windowed rendering
    
    # Get device from canvas
    device = WGPUCore.getDefaultDevice(app.canvas)
    
    # Get preferred format for canvas
    renderTextureFormat = WGPUCore.getPreferredFormat(app.canvas)
    
    # Configure context
    presentContext = WGPUCore.getContext(app.canvas)
    WGPUCore.determineSize(presentContext)
    WGPUCore.config(presentContext, device=device, format=renderTextureFormat)

    # Initialize font renderer
    app.fontRenderer = createFontRenderer(device, device.queue)
    
    # Set demo text
    app.textToRender = "Hello, World!\nThis is GPU font rendering!"
    
    # Prepare font data for the text
    createBuffers(app.fontRenderer, app.textToRender, renderTextureFormat)
    
    # Set up canvas callbacks
    setup_callbacks(app)
    
    return app
end

function setup_callbacks(app::FontDemoApp)
    # For now, we'll use a simple render loop without callbacks
    # The WGPUCanvas API may differ - we'll handle rendering in the main loop
end

function render_frame(app::FontDemoApp)
    try
        # Get canvas context
        presentContext = WGPUCore.getContext(app.canvas)
        device = WGPUCore.getDefaultDevice(app.canvas)
        
        # Get current surface texture directly
        currentTextureView = WGPUCore.getCurrentTexture(presentContext)
        
        # Create command encoder
        cmdEncoder = WGPUCore.createCommandEncoder(device, "Font Demo Encoder")
        
        # Create render pass options
        renderPassOptions = [
            WGPUCore.GPUColorAttachments => [
                :attachments => [
                    WGPUCore.GPUColorAttachment => [
                        :view => currentTextureView,
                        :resolveTarget => C_NULL,
                        :clearValue => (0.1, 0.1, 0.1, 1.0),
                        :loadOp => WGPUCore.WGPULoadOp_Clear,
                        :storeOp => WGPUCore.WGPUStoreOp_Store,
                    ],
                ],
            ],
            WGPUCore.GPUDepthStencilAttachments => [],
        ]
        
        # Begin render pass
        renderPass = WGPUCore.beginRenderPass(
            cmdEncoder,
            renderPassOptions |> Ref;
            label = "Font Demo Render Pass",
        )
        
        # Render the text
        renderText(app.fontRenderer, renderPass)
        
        # End render pass and submit
        WGPUCore.endEncoder(renderPass)
        WGPUCore.submit(device.queue, [WGPUCore.finish(cmdEncoder)])
        
        # Present the frame
        WGPUCore.present(presentContext)
        
    catch e
        @warn "Rendering error: $e"
    end
end

function run_demo()
    println("Starting Font Rendering Demo...")
    
    # Initialize application
    app = FontDemoApp()
    init_app(app)
    
    println("Font renderer initialized")
    println("Text to render: \"$(app.textToRender)\"")
    println("Press ESC or close window to exit")
    
    # Simple render loop
    try
        while true
            # Check if window should close
            if GLFW.WindowShouldClose(app.canvas.windowRef[])
                break
            end
            
            # Render frame
            render_frame(app)
            
            # Poll events
            GLFW.PollEvents()
            
            # Small delay to prevent excessive CPU usage
            sleep(0.016)  # ~60 FPS
        end
    catch e
        println("Rendering loop interrupted: ", e)
    finally
        # Cleanup
        WGPUCore.destroyWindow(app.canvas)
        println("Demo completed")
    end
end

# Run the demo if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_demo()
end
