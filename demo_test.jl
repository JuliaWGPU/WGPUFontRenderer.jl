#!/usr/bin/env julia

# Demo test runner for text wrapping functionality
# This version demonstrates the core functionality without requiring graphics

include("src/advanced_shaders.jl")

# Test the text layout system
function testTextLayoutSystem()
    println("=== Advanced GPU Font Renderer Demo ===")
    println("Testing text block word wrap functionality...\n")
    
    # Load the demo functionality
    include("src/text_wrap_demo.jl")
    
    # Test metrics (use invokelatest to handle world age)
    metrics = Base.invokelatest(TextMetrics, 12.0f0, 20.0f0, 24.0f0, 6.0f0)
    
    # Test with different viewport widths
    viewport_widths = [400.0f0, 800.0f0, 1200.0f0]
    
    for width in viewport_widths
        text_area_width = width * 0.8f0  # 80% of viewport for text
        
        println("📐 Viewport: $(Int(width))px, Text Area: $(Int(text_area_width))px")
        
        # Wrap the demo text
        wrapped_lines = wrapText(DEMO_TEXT, text_area_width, metrics)
        
        println("📝 Wrapped into $(length(wrapped_lines)) lines")
        println("📏 Total height: $(length(wrapped_lines) * metrics.line_height)px")
        
        # Show first few lines as sample
        println("📖 First 3 lines:")
        for (i, line) in enumerate(wrapped_lines[1:min(3, length(wrapped_lines))])
            line_width = length(line) * metrics.char_width
            println("   Line $i: \"$(line[1:min(50, length(line))])$(length(line) > 50 ? "..." : "")\" ($(Int(line_width))px)")
        end
        
        # Create glyph instances (without rendering)
        start_pos = SVector{2, Float32}(width * 0.1f0, width * 0.9f0)
        text_color = SVector{4, Float32}(0.9f0, 0.95f0, 1.0f0, 1.0f0)
        glyph_instances = createWrappedTextInstances(wrapped_lines, start_pos, metrics, text_color)
        
        println("🎨 Created $(length(glyph_instances)) glyph instances")
        println("=" ^ 60)
        println()
    end
end

# Test shader functionality
function testShaderGeneration()
    println("=== Shader System Test ===")
    
    # Test vertex shader generation
    vertex_shader = getAdvancedVertexShader()
    println("✅ Vertex shader generated ($(length(vertex_shader)) characters)")
    
    # Test fragment shader variants
    shaders = [
        ("Basic Fragment", getAdvancedFragmentShader()),
        ("Solid Color", getAdvancedSolidShader()),
        ("Font Atlas", getAdvancedAtlasShader()),
        ("Effects", getAdvancedEffectsShader())
    ]
    
    for (name, shader) in shaders
        println("✅ $name shader generated ($(length(shader)) characters)")
    end
    
    println()
end

# Demonstrate word wrapping with various scenarios
function demonstrateWordWrapping()
    println("=== Word Wrapping Scenarios ===")
    
    include("src/text_wrap_demo.jl")
    
    scenarios = [
        ("Short Lines", "This is a short sentence for testing.", 150.0f0),
        ("Medium Lines", "This is a medium-length sentence that should wrap nicely across multiple lines when constrained.", 300.0f0),
        ("Long Lines", "This is a very long sentence designed to test the word wrapping algorithm with various edge cases including very long words and punctuation.", 400.0f0),
        ("Mixed Content", "Short. Medium length sentence here. Very long sentence with lots of technical terminology and complex punctuation marks!", 250.0f0)
    ]
    
    metrics = Base.invokelatest(TextMetrics, 10.0f0, 16.0f0, 20.0f0, 5.0f0)
    
    for (name, text, width) in scenarios
        println("📋 Scenario: $name (Width: $(Int(width))px)")
        analyzeTextLayout(text, width, metrics)
    end
end

# Main demo runner
function runDemo()
    println("🚀 Starting Advanced GPU Font Renderer Demo")
    println("This demo showcases text block rendering with word wrap functionality")
    println("=" ^ 80)
    println()
    
    testShaderGeneration()
    testTextLayoutSystem()
    demonstrateWordWrapping()
    
    println("🎉 Demo completed successfully!")
    println()
    println("💡 To run the full interactive demo with graphics, use:")
    println("   julia --project=. -e \"include(\\\"src/text_wrap_demo.jl\\\"); runTextWrapDemo()\"")
end

# Run the demo
if abspath(PROGRAM_FILE) == @__FILE__
    runDemo()
end
