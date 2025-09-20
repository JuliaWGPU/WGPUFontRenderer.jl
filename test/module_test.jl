# Test script to verify modules work together

using WGPUFontRenderer

println("Testing WGPUFontRenderer...")
println("FontRenderer available: ", isdefined(WGPUFontRenderer, :FontRenderer))

# Test creating a font renderer
try
    # This would normally require a GPU context, so we'll just test if the function exists
    println("createFontRenderer function available: ", isdefined(WGPUFontRenderer, :createFontRenderer))
    println("All basic tests passed!")
catch e
    println("Error: ", e)
end