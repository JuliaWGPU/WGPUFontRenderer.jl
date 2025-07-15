# GPU Font Renderer Example - Following gpu-font-renderer pattern
# This example demonstrates vector font rendering using WGPUCore and WGPUgfx

using WGPUCore
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
    WGPUCore.config(presentContext; device=app.device, format=surfaceFormat)
    
    # Create font renderer - following gpu-font-renderer initialization
    app.fontRenderer = createFontRenderer(app.device, app.queue)
    
    # Initialize renderer with surface format
    initializeRenderer(app.fontRenderer, surfaceFormat)
    
    # Set demo text
    app.textToRender = "Hello GPU Font Rendering!"
    
    # Load font data for text - following gpu-font-renderer pattern
    loadFontData(app.fontRenderer, app.textToRender)
    
    return app
end

function render_frame(app::FontDemoApp)
    try
        # Get current surface texture
        presentContext = WGPUCore.getContext(app.canvas)
        currentTextureView = WGPUCore.getCurrentTexture(presentContext)
        
        # Create command encoder
        cmdEncoder = WGPUCore.createCommandEncoder(app.device, "Font Demo Encoder")
        
        # Create render pass - try simpler approach
        renderPassOptions = [
            WGPUCore.GPUColorAttachments => [
                :attachments => [
                    WGPUCore.GPUColorAttachment => [
                        :view => currentTextureView,
                        :resolveTarget => C_NULL,
                        :clearValue => (0.1, 0.1, 0.1, 1.0),  # Dark gray background
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
        # Cleanup
        WGPUCore.destroyWindow(app.canvas)
        println("Demo completed")
    end
end

# Run the demo if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_demo()
end
