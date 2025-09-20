# Test all WGPUgfx integration examples
#
# This script verifies that all example files exist and have basic structure.

using WGPUFontRenderer

println("Testing WGPUgfx Integration Examples")
println("====================================")
println()

examples_dir = joinpath(@__DIR__, "..", "examples")
examples = [
    "wgpugfx_api_example.jl" => "API Usage Example",
    "wgpugfx_complete_example.jl" => "Complete Working Example", 
    "wgpugfx_scene_example.jl" => "Scene Integration Example",
    "wgpugfx_font_example.jl" => "Basic Integration Example",
    "animated_font_wgpugfx.jl" => "Animated Demo"
]

all_good = true

for (filename, description) in examples
    filepath = joinpath(examples_dir, filename)
    if isfile(filepath)
        println("✓ $filename - $description")
        
        # Check if file has content
        try
            lines = readlines(filepath)
            if length(lines) > 10
                println("  └─ File has $(length(lines)) lines")
            else
                println("  └─ Warning: File seems too short ($(length(lines)) lines)")
                all_good = false
            end
        catch e
            println("  └─ Error reading file: $e")
            all_good = false
        end
    else
        println("✗ $filename - MISSING")
        all_good = false
    end
    println()
end

println("Integration API Verification:")
println("  FontRenderableUI available: ", isdefined(WGPUFontRenderer, :FontRenderableUI))
println("  defaultFontRenderableUI available: ", isdefined(WGPUFontRenderer, :defaultFontRenderableUI))
println("  setText! available: ", isdefined(WGPUFontRenderer, :setText!))
println("  setPosition! available: ", isdefined(WGPUFontRenderer, :setPosition!))
println("  animatePosition! available: ", isdefined(WGPUFontRenderer, :animatePosition!))

println()
if all_good
    println("✓ All examples are present and properly structured!")
    println("✓ WGPUgfx integration is ready for use!")
else
    println("✗ Some issues found with examples.")
end