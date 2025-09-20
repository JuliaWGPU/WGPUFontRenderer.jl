# Simple test to check if the modules load correctly

using WGPUCore
using WGPUFontRenderer

println("Testing basic module loading...")

# Test if we can create a font renderer
try
    println("WGPUFontRenderer module loaded successfully")
    println("Available functions: ", names(WGPUFontRenderer))
catch e
    println("Error loading WGPUFontRenderer: ", e)
end

# Test if WGPUgfxFont is available
try
    include("../src/WGPUgfxFont.jl")
    using .WGPUgfxFont
    println("WGPUgfxFont module loaded successfully")
catch e
    println("Error loading WGPUgfxFont: ", e)
end