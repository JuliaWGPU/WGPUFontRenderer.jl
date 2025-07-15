using WGPUCore
using WGPUCanvas
using GLFW

# Create a GLFW canvas  
canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
println("Canvas created successfully")

# Create a device
device = WGPUCore.getDefaultDevice(canvas)
println("Device created successfully")

# Get context
presentContext = WGPUCore.getContext(canvas)
println("Context created successfully")

# Check surface capabilities
println("Testing surface capabilities...")
println("Surface: ", canvas.surfaceRef[])
println("Device internal: ", device.internal[])

# This will call wgpuSurfaceGetCapabilities
try
    # Let's try to call the surface configuration function directly
    WGPUCore.determineSize(presentContext)
    println("Physical size determined: ", presentContext.physicalSize)
    
    # Try to get the preferred format
    surfaceFormat = WGPUCore.getPreferredFormat(canvas)
    println("Surface format: ", surfaceFormat)
    println("Surface format value: ", Int(surfaceFormat))
    
    # Configure the context
    WGPUCore.config(presentContext; device=device, format=surfaceFormat)
    println("Context configured successfully")
    
    # Now try to configure the surface (this is where the error occurs)
    # By examining the error more carefully, I need to check what happens 
    # when configureSurface is called
    
    # First check the surface configuration function
    println("Surface size before configureSurface: ", presentContext.surfaceSize)
    
    # Let's examine the configureSurface parameters
    canvasCntxt = presentContext
    pSize = canvasCntxt.physicalSize
    println("Physical size: ", pSize)
    println("Format being used: ", canvasCntxt.format)
    println("Format value: ", Int(canvasCntxt.format))
    println("Usage: ", canvasCntxt.usage)
    println("Usage value: ", Int(canvasCntxt.usage))
    
catch e
    println("Error: ", e)
end

# Cleanup
WGPUCore.destroyWindow(canvas)
println("Test completed")
