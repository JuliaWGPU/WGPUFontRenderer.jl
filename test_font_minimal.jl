# Minimal test to check if font rendering works
using WGPUCore
using WGPUNative
using WGPUCanvas
using WGPUFontRenderer
using GLFW

println("Testing font rendering...")

# Create a minimal test
try
    canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
    device = WGPUCore.getDefaultDevice(canvas)
    queue = device.queue
    
    fontRenderer = createFontRenderer(device, queue)
    surfaceFormat = WGPUCore.getPreferredFormat(canvas)
    initializeRenderer(fontRenderer, surfaceFormat)
    
    # Test loading font data
    text = "Hello"
    loadFontData(fontRenderer, text)
    println("Font data loaded successfully")
    println("Number of glyphs: ", length(fontRenderer.glyphs))
    println("Number of curves: ", length(fontRenderer.curves))
    
    # Test generating vertex data
    generateVertexData(fontRenderer, text, 10.0f0, 50.0f0)
    println("Vertex data generated successfully")
    println("Number of vertices: ", length(fontRenderer.vertices))
    
catch e
    println("Error: ", e)
    Base.showerror(stdout, e, catch_backtrace())
end