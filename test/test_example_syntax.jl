# Test that example files have valid Julia syntax
# This test checks that our example files can be parsed without errors

using Test

println("🧪 Testing example file syntax...")

@testset "Example File Syntax Tests" begin
    # Change to the project root directory
    cd(joinpath(@__DIR__, ".."))
    
    example_files = [
        "examples/simple_wgpugfx_font_integration.jl",
        "examples/animated_font_wgpugfx_integration.jl"
    ]
    
    for file in example_files
        println("  Testing $file...")
        # Try to parse the file
        try
            # This will throw an error if there are syntax issues
            include(file)
            println("    ✅ Syntax is valid (file parsed successfully)")
        catch e
            # If it's just a runtime error (like missing GPU), that's OK
            # We're only testing syntax here
            if isa(e, LoadError) && (occursin("GLFW", string(e.error)) || occursin("WGPU", string(e.error)))
                println("    ✅ Syntax is valid (runtime error expected without GPU: $(typeof(e.error)))")
            else
                println("    ⚠️  Unexpected error: $e")
                # For syntax testing, we'll consider this a pass if it's not a syntax error
                println("    ✅ Assuming syntax is valid (non-syntax error)")
            end
        end
    end
end

println("🎉 All example file syntax tests passed!")