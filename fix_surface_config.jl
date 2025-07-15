# Proposed fix for WGPUCanvas surface configuration
# This addresses the "Unknown texture format" error by adding proper surface capability checking

function configureSurface_fixed(canvasCntxt::GPUCanvasContext)
    canvas = canvasCntxt.canvasRef[]
    pSize = canvasCntxt.physicalSize
    
    # Skip if size hasn't changed
    if pSize == canvasCntxt.surfaceSize
        return
    end
    
    canvasCntxt.surfaceSize = pSize
    canvasCntxt.usage = WGPUCore.getEnum(WGPUTextureUsage, ["RenderAttachment", "CopySrc"])
    presentMode = WGPUPresentMode_Fifo
    
    # CRITICAL FIX: Check surface capabilities before configuring
    println("Checking surface capabilities...")
    surfaceCapabilities = cStruct(WGPUSurfaceCapabilities;)
    
    # Get surface capabilities
    wgpuSurfaceGetCapabilities(
        canvas.surfaceRef[],
        canvas.device.internal[],
        surfaceCapabilities |> ptr
    )
    
    # Check if our desired format is supported
    formatCount = surfaceCapabilities.formatCount
    supportedFormats = unsafe_wrap(Array, surfaceCapabilities.formats, formatCount)
    
    println("Surface supports ", formatCount, " formats")
    println("Supported formats: ", supportedFormats)
    println("Desired format: ", canvasCntxt.format)
    println("Format value: ", Int(canvasCntxt.format))
    
    # Check if our format is supported
    if canvasCntxt.format ∉ supportedFormats
        @error "Format $(canvasCntxt.format) is not supported by surface"
        @error "Supported formats: $(supportedFormats)"
        
        # Try to find a fallback format
        if WGPUTextureFormat_BGRA8Unorm in supportedFormats
            canvasCntxt.format = WGPUTextureFormat_BGRA8Unorm
            println("Using fallback format: BGRA8Unorm")
        elseif WGPUTextureFormat_RGBA8Unorm in supportedFormats
            canvasCntxt.format = WGPUTextureFormat_RGBA8Unorm
            println("Using fallback format: RGBA8Unorm")
        else
            canvasCntxt.format = supportedFormats[1]  # Use first supported format
            println("Using first supported format: ", canvasCntxt.format)
        end
    end
    
    # Now configure with validated format
    surfaceConfiguration = cStruct(
        WGPUSurfaceConfiguration;
        device = canvasCntxt.device.internal[],
        usage = canvasCntxt.usage,
        format = canvasCntxt.format,
        viewFormatCount = 1,
        viewFormats = [canvasCntxt.format] |> pointer,
        alphaMode = WGPUCompositeAlphaMode_Opaque,
        width = max(1, pSize[1]),
        height = max(1, pSize[2]),
        presentMode = presentMode,
        nextInChain = C_NULL,
    )
    
    # Configure the surface
    wgpuSurfaceConfigure(
        canvas.surfaceRef[],
        surfaceConfiguration |> ptr,
    )
    
    println("Surface configured successfully with format: ", canvasCntxt.format)
end

println("This is a proposed fix for the surface configuration issue.")
println("The key improvements are:")
println("1. Check surface capabilities before configuring")
println("2. Validate that the desired format is supported")
println("3. Provide fallback formats if the preferred format is not supported")
println("4. Add proper error handling and logging")
println("")
println("To apply this fix, replace the configureSurface function in glfwWindows.jl with this version.")
