# Test just the font renderer creation without complex pipeline
using WGPUCanvas
using WGPUCore
using WGPUFontRenderer
using GLFW

function test_font_renderer_only()
    println("Creating canvas...")
    canvas = WGPUCore.getCanvas(:GLFW, (400, 300))
    
    println("Getting device...")
    device = WGPUCore.getDefaultDevice(canvas)
    
    println("Getting format...")
    renderTextureFormat = WGPUCore.getPreferredFormat(canvas)
    
    println("Creating font renderer...")
    try
        fontRenderer = createFontRenderer(device, device.queue)
        println("Font renderer created successfully")
        
        println("Preparing text...")
        prepareGlyphsForText("Hello")
        println("Text prepared successfully")
        
        println("Initializing renderer...")
        initializeRenderer(fontRenderer, renderTextureFormat)
        println("Renderer initialized successfully")
        
        println("Loading font data...")
        loadFontData(fontRenderer, "Hello")
        println("Font data loaded successfully")
        
    catch e
        println("Error: ", e)
        println("Stack trace:")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
            println()
        end
    finally
        println("Cleaning up...")
        WGPUCore.destroyWindow(canvas)
    end
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    test_font_renderer_only()
end
