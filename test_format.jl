using WGPUCore
using WGPUCanvas
using GLFW
using WGPUCore: WGPUTextureFormat

# Test if WGPUCore format conversion is working
println("Testing WGPUCore format conversion...")

# Create a GLFW canvas  
canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
println("Canvas created successfully")

# Get the preferred format
surfaceFormat = WGPUCore.getPreferredFormat(canvas)
println("Surface format: ", surfaceFormat)
println("Surface format type: ", typeof(surfaceFormat))

# Test enum conversion
testFormat = WGPUCore.getEnum(WGPUTextureFormat, "BGRA8Unorm")
println("Test format: ", testFormat)
println("Test format type: ", typeof(testFormat))
println("Formats equal: ", surfaceFormat == testFormat)

# Try alternative format
alternativeFormat = WGPUCore.getEnum(WGPUTextureFormat, "RGBA8Unorm")
println("Alternative format: ", alternativeFormat)
println("Alternative format type: ", typeof(alternativeFormat))

# Create a device
device = WGPUCore.getDefaultDevice(canvas)
println("Device created successfully")

# Try to configure context
presentContext = WGPUCore.getContext(canvas)
println("Context created successfully")

# Try to configure the context with the format
WGPUCore.config(presentContext; device=device, format=surfaceFormat)
println("Context configured successfully")

# Test current texture retrieval
try
    currentTexture = WGPUCore.getCurrentTexture(presentContext)
    println("Current texture retrieved successfully")
    println("Current texture type: ", typeof(currentTexture))
catch e
    println("Error getting current texture: ", e)
end

# Cleanup
WGPUCore.destroyWindow(canvas)
println("Test completed")
