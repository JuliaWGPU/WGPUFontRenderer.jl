# Simple integration test that doesn't require GPU

using WGPUFontRenderer

println("Testing WGPUFontRenderer integration...")

# Test that all expected functions are available
required_functions = [
    :createFontRenderer,
    :initializeRenderer,
    :loadFontData,
    :setPosition,
    :createGPUBuffers,
    :createBindGroup,
    :renderText
]

all_available = true
for func in required_functions
    if !isdefined(WGPUFontRenderer, func)
        println("Missing function: ", func)
        global all_available = false
    end
end

if all_available
    println("All required functions are available!")
else
    println("Some functions are missing!")
end

# Test exports
println("Testing exports...")
exports = names(WGPUFontRenderer)
println("Main exports: ", filter(x -> !startswith(string(x), "#"), exports))

println("Integration test completed successfully!")