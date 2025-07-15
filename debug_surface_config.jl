using WGPUCore
using WGPUCanvas
using GLFW
using WGPUCore: WGPUTextureFormat

# Create a GLFW canvas  
canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
println("Canvas created successfully")

# Get the preferred format
surfaceFormat = WGPUCore.getPreferredFormat(canvas)
println("Surface format from canvas: ", surfaceFormat)
println("Surface format value: ", Int(surfaceFormat))

# Create a device
device = WGPUCore.getDefaultDevice(canvas)
println("Device created successfully")

# Get context
presentContext = WGPUCore.getContext(canvas)
println("Context created successfully")
println("Context format before config: ", presentContext.format)
println("Context format value before config: ", Int(presentContext.format))

# Configure the context
WGPUCore.config(presentContext; device=device, format=surfaceFormat)
println("Context configured successfully")
println("Context format after config: ", presentContext.format)
println("Context format value after config: ", Int(presentContext.format))

# Check physical size
WGPUCore.determineSize(presentContext)
println("Physical size: ", presentContext.physicalSize)

# Check surface size
println("Surface size: ", presentContext.surfaceSize)

# Print some debug info about the configuration
println("Device internal: ", device.internal)
println("Usage: ", presentContext.usage)
println("Usage value: ", Int(presentContext.usage))

# Cleanup
WGPUCore.destroyWindow(canvas)
println("Test completed")
