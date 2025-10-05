# GPU Font Renderer Example - Following gpu-font-renderer pattern
# This example demonstrates vector font rendering using WGPUCore and WGPUgfx

using WGPUCore
using WGPUNative
using WGPUCanvas
using WGPUFontRenderer
using GLFW

# Simple demo application following gpu-font-renderer structure  
mutable struct FontDemoApp
    canvas::WGPUCore.AbstractWGPUCanvas
    device::WGPUCore.GPUDevice
    queue::WGPUCore.GPUQueue
    fontRenderer::FontRenderer
    textToRender::String
    depthTexture::Union{WGPUCore.GPUTexture, Nothing}
    depthTextureView::Union{WGPUCore.GPUTextureView, Nothing}
    depthTextureWidth::Int
    depthTextureHeight::Int
    
    function FontDemoApp()
        new()
    end
end

function init_app(app::FontDemoApp)
    # Initialize WGPU - following gpu-font-renderer pattern
    app.canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    app.device = WGPUCore.getDefaultDevice(app.canvas)
    app.queue = app.device.queue
    
    # Get surface format  
    surfaceFormat = WGPUCore.getPreferredFormat(app.canvas)
    println("Surface format: ", surfaceFormat)
    println("Surface format type: ", typeof(surfaceFormat))
    
    # Configure context
    presentContext = WGPUCore.getContext(app.canvas)
    WGPUCore.determineSize(presentContext)  # Determine actual framebuffer size
    WGPUCore.config(presentContext; device=app.device, format=surfaceFormat)
    
    # Create font renderer - following gpu-font-renderer initialization
    app.fontRenderer = createFontRenderer(app.device, app.queue)
    
    # Initialize renderer with surface format
    initializeRenderer(app.fontRenderer, surfaceFormat)
    
    # Set demo text - just "Hello" for cleaner debug visualization
    app.textToRender = "Hello"
    
    # Load font data for text - following gpu-font-renderer pattern
    loadFontData(app.fontRenderer, app.textToRender)
    
    # Initialize depth texture fields
    app.depthTexture = nothing
    app.depthTextureView = nothing
    app.depthTextureWidth = 0
    app.depthTextureHeight = 0
    
    return app
end

function cleanup_app(app::FontDemoApp)
    # Clean up depth texture resources
    if app.depthTextureView !== nothing
        try
            WGPUCore.destroy(app.depthTextureView)
        catch e
            # Ignore errors during cleanup
        end
        app.depthTextureView = nothing
    end
    
    if app.depthTexture !== nothing
        try
            WGPUCore.destroy(app.depthTexture)
        catch e
            # Ignore errors during cleanup
        end
        app.depthTexture = nothing
    end
end

function render_frame(app::FontDemoApp)
    try
        # Get current surface texture
        presentContext = WGPUCore.getContext(app.canvas)
        currentTextureView = WGPUCore.getCurrentTexture(presentContext)
        
        # Create command encoder
        cmdEncoder = WGPUCore.createCommandEncoder(app.device, "Font Demo Encoder")
        
        # Get current canvas size dynamically
        canvasSize = app.canvas.size
        
        # Update renderer window dimensions
        app.fontRenderer.windowWidth = Float32(canvasSize[1])
        app.fontRenderer.windowHeight = Float32(canvasSize[2])
        
        # Create or recreate depth texture if needed (handle window resizing)
        needsDepthTexture = app.depthTexture === nothing || app.depthTextureView === nothing
        if !needsDepthTexture
            # Check if canvas size has changed using stored dimensions
            if app.depthTextureWidth != canvasSize[1] || app.depthTextureHeight != canvasSize[2]
                # Canvas size changed, cleanup old depth texture
                try
                    WGPUCore.destroy(app.depthTextureView)
                    WGPUCore.destroy(app.depthTexture)
                catch e
                    # Ignore cleanup errors
                end
                needsDepthTexture = true
            end
        end
        
        if needsDepthTexture
            # Create depth texture with current canvas size
            app.depthTexture = WGPUCore.createTexture(
                app.device,
                "Depth Texture",
                (canvasSize[1], canvasSize[2], 1),
                1, 1,
                WGPUCore.WGPUTextureDimension_2D, 
                WGPUNative.LibWGPU.WGPUTextureFormat_Depth24Plus,
                WGPUCore.getEnum(WGPUCore.WGPUTextureUsage, ["RenderAttachment"])
            )
            
            # Create depth texture view
            app.depthTextureView = WGPUCore.createView(app.depthTexture)
            
            # Store the dimensions for future comparisons
            app.depthTextureWidth = canvasSize[1]
            app.depthTextureHeight = canvasSize[2]
        end
        
        # Create render pass with depth stencil attachment
        renderPassOptions = [
            WGPUCore.GPUColorAttachments => [
                :attachments => [
                    WGPUCore.GPUColorAttachment => [
                        :view => currentTextureView,
                        :resolveTarget => C_NULL,
                        :clearValue => (0.9, 0.9, 0.9, 1.0),  # Light gray background for better contrast
                                :loadOp => WGPUCore.WGPULoadOp_Clear,
                                :storeOp => WGPUCore.WGPUStoreOp_Store,
                    ],
                ],
            ],
            WGPUCore.GPUDepthStencilAttachments => [
                :attachments => [
                    WGPUCore.GPUDepthStencilAttachment => [
                        :view => app.depthTextureView,
                        :depthClearValue => 1.0,  # Clear to far plane
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
            label = "Font Demo Render Pass",
        )
        
        # Render the text using our font renderer
        renderText(app.fontRenderer, renderPass)
        
        # End render pass and submit
        WGPUCore.endEncoder(renderPass)
        WGPUCore.submit(app.queue, [WGPUCore.finish(cmdEncoder)])
        
        # Present the frame
        WGPUCore.present(presentContext)
        
    catch e
        @warn "Rendering error: $e"
    end
end

function run_demo()
    println("Starting GPU Font Renderer Demo...")
    println("Following gpu-font-renderer pattern with WGPUCore and WGPUgfx")
    
    # Initialize application
    app = FontDemoApp()
    init_app(app)
    
    println("Font renderer initialized successfully")
    println("Text to render: \"$(app.textToRender)\"")
    println("Press ESC or close window to exit")
    
    # Main render loop - following gpu-font-renderer pattern
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
        # Cleanup depth texture resources
        cleanup_app(app)
        WGPUCore.destroyWindow(app.canvas)
        println("Demo completed")
    end
end

# Run the demo if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_demo()
end

# Example of custom positioning (uncomment to use):
# setPosition(app.fontRenderer, "Custom Position", 200.0f0, 300.0f0)