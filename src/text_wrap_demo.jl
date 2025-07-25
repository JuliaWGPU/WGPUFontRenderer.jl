# Text Block Word Wrap Demo
# Demonstrates advanced GPU font rendering with word wrapping

using WGPUCore
using GLFW
using StaticArrays
using LinearAlgebra

include("advanced_renderer.jl")
include("advanced_shaders.jl")

# Text wrapping and layout utilities
struct TextMetrics
    char_width::Float32
    char_height::Float32
    line_height::Float32
    space_width::Float32
end

# Word wrapping function
function wrapText(text::String, max_width::Float32, metrics::TextMetrics)::Vector{String}
    words = split(text, ' ')
    lines = String[]
    current_line = ""
    current_width = 0.0f0
    
    for word in words
        word_width = length(word) * metrics.char_width
        space_width = isempty(current_line) ? 0.0f0 : metrics.space_width
        
        # Check if adding this word would exceed the line width
        if current_width + space_width + word_width > max_width && !isempty(current_line)
            # Start a new line
            push!(lines, current_line)
            current_line = word
            current_width = word_width
        else
            # Add word to current line
            if !isempty(current_line)
                current_line *= " " * word
                current_width += space_width + word_width
            else
                current_line = word
                current_width = word_width
            end
        end
    end
    
    # Add the last line if it's not empty
    if !isempty(current_line)
        push!(lines, current_line)
    end
    
    return lines
end

# Create glyph instances from wrapped text
function createWrappedTextInstances(lines::Vector{String}, start_pos::SVector{2, Float32}, 
                                  metrics::TextMetrics, color::SVector{4, Float32})::Vector{GlyphInstance}
    instances = GlyphInstance[]
    
    for (line_idx, line) in enumerate(lines)
        y_pos = start_pos[2] - (line_idx - 1) * metrics.line_height
        
        for (char_idx, char) in enumerate(line)
            x_pos = start_pos[1] + (char_idx - 1) * metrics.char_width
            
            # Create glyph instance
            instance = GlyphInstance(
                position = SVector{2, Float32}(x_pos, y_pos),
                size = SVector{2, Float32}(metrics.char_width, metrics.char_height),
                uv_min = SVector{2, Float32}(0.0f0, 0.0f0),  # Placeholder UVs
                uv_max = SVector{2, Float32}(1.0f0, 1.0f0),  # Placeholder UVs
                color = color,
                glyph_index = UInt32(Int(char))  # Use ASCII value as glyph index
            )
            
            push!(instances, instance)
        end
    end
    
    return instances
end

# Demo text content
const DEMO_TEXT = """
Welcome to the Advanced GPU Font Renderer Demo! This demonstration showcases the power of instanced rendering for text display in modern graphics applications. 

The renderer uses WebGPU's instanced drawing capabilities to efficiently render thousands of characters with minimal draw calls. Each glyph is positioned as a separate instance, allowing for dynamic text layout, word wrapping, and real-time updates.

Key features include:
• High-performance instanced rendering
• Automatic word wrapping with configurable line width
• Dynamic text layout and positioning
• Support for multiple text blocks with different styling
• Smooth scrolling and viewport transformations
• Extensible shader system for text effects

This text block demonstrates automatic word wrapping functionality. The text flows naturally within the specified boundaries, breaking lines at appropriate word boundaries to maintain readability.

Try resizing the window to see how the text adapts to different viewport sizes while maintaining optimal layout and performance!
"""

# Main demo function
function runTextWrapDemo()
    println("Starting Text Block Word Wrap Demo...")
    
    # Initialize GLFW
    GLFW.Init()
    
    # Create window
    window_width, window_height = 1200, 800
    window = GLFW.CreateWindow(window_width, window_height, "GPU Font Renderer - Text Wrap Demo")
    GLFW.MakeContextCurrent(window)
    
    try
        # Initialize WGPU
        canvas = WGPUCore.getCanvas(window)
        device = WGPUCore.getDefaultDevice()
        
        # Create advanced font renderer
        renderer = createAdvancedFontRenderer(device, window_width, window_height)
        
        # Configure text metrics (placeholder values)
        text_metrics = TextMetrics(
            char_width = 12.0f0,
            char_height = 20.0f0,
            line_height = 24.0f0,
            space_width = 6.0f0
        )
        
        # Calculate text area dimensions (80% of window width for margins)
        text_area_width = window_width * 0.8f0
        start_position = SVector{2, Float32}(
            window_width * 0.1f0,  # 10% margin from left
            window_height * 0.9f0  # Start near top with 10% margin
        )
        
        # Wrap the demo text
        println("Wrapping text with max width: $text_area_width pixels")
        wrapped_lines = wrapText(DEMO_TEXT, text_area_width, text_metrics)
        println("Text wrapped into $(length(wrapped_lines)) lines")
        
        # Create glyph instances from wrapped text
        text_color = SVector{4, Float32}(0.9f0, 0.95f0, 1.0f0, 1.0f0)  # Light blue-white
        glyph_instances = createWrappedTextInstances(wrapped_lines, start_position, text_metrics, text_color)
        
        println("Created $(length(glyph_instances)) glyph instances")
        
        # Add instances to renderer
        for instance in glyph_instances
            addGlyphInstance!(renderer, instance)
        end
        
        # Create a simple text block for the title
        title_text = "Advanced GPU Font Renderer - Word Wrap Demo"
        title_position = SVector{2, Float32}(window_width * 0.1f0, window_height * 0.95f0)
        title_color = SVector{4, Float32}(1.0f0, 0.8f0, 0.2f0, 1.0f0)  # Golden yellow
        
        title_instances = createWrappedTextInstances([title_text], title_position, text_metrics, title_color)
        for instance in title_instances
            addGlyphInstance!(renderer, instance)
        end
        
        # Update renderer buffers
        updateInstanceBuffer!(renderer)
        
        # Render loop variables
        frame_count = 0
        last_time = time()
        scroll_y = 0.0f0
        
        println("Starting render loop...")
        
        # Main render loop
        while !GLFW.WindowShouldClose(window)
            GLFW.PollEvents()
            
            # Handle input for scrolling
            if GLFW.GetKey(window, GLFW.KEY_UP) == GLFW.PRESS
                scroll_y += 2.0f0
            elseif GLFW.GetKey(window, GLFW.KEY_DOWN) == GLFW.PRESS
                scroll_y -= 2.0f0
            end
            
            # Handle window resize
            new_width, new_height = GLFW.GetFramebufferSize(window)
            if new_width != window_width || new_height != window_height
                window_width, window_height = new_width, new_height
                updateViewport!(renderer, window_width, window_height)
                println("Window resized to: $(window_width)x$(window_height)")
            end
            
            # Update scroll position
            updateScrollPosition!(renderer, SVector{2, Float32}(0.0f0, scroll_y))
            
            # Begin render pass
            render_pass = WGPUCore.beginRenderPass(device, canvas)
            
            # Clear the screen with a dark background
            WGPUCore.clearColor(render_pass, 0.1, 0.12, 0.15, 1.0)
            
            # Render the text
            renderInstances!(renderer, render_pass)
            
            # End render pass and present
            WGPUCore.endRenderPass(render_pass)
            WGPUCore.present(canvas)
            
            # Performance monitoring
            frame_count += 1
            current_time = time()
            if current_time - last_time >= 1.0
                fps = frame_count / (current_time - last_time)
                println("FPS: $(round(fps, digits=1)) | Glyphs: $(length(glyph_instances)) | Scroll: $(round(scroll_y, digits=1))")
                frame_count = 0
                last_time = current_time
            end
            
            # Small delay to prevent excessive CPU usage
            sleep(0.016)  # ~60 FPS
        end
        
    catch e
        println("Error in demo: $e")
        rethrow(e)
    finally
        # Cleanup
        GLFW.DestroyWindow(window)
        GLFW.Terminate()
        println("Demo ended successfully!")
    end
end

# Utility function to display text metrics
function analyzeTextLayout(text::String, max_width::Float32, metrics::TextMetrics)
    lines = wrapText(text, max_width, metrics)
    
    println("\n=== Text Layout Analysis ===")
    println("Original text length: $(length(text)) characters")
    println("Max line width: $max_width pixels")
    println("Character dimensions: $(metrics.char_width)×$(metrics.char_height)")
    println("Line height: $(metrics.line_height)")
    println("Wrapped into $(length(lines)) lines:")
    println()
    
    for (i, line) in enumerate(lines)
        line_width = length(line) * metrics.char_width
        println("Line $i ($(length(line)) chars, $(round(line_width, digits=1))px): \"$line\"")
    end
    
    total_height = length(lines) * metrics.line_height
    println("\nTotal text block height: $(round(total_height, digits=1))px")
    println("=============================\n")
end

# Example usage and testing
function testWordWrapping()
    println("Testing word wrapping functionality...")
    
    metrics = TextMetrics(12.0f0, 20.0f0, 24.0f0, 6.0f0)
    test_text = "This is a test of the word wrapping system with various sentence lengths and word combinations."
    
    analyzeTextLayout(test_text, 200.0f0, metrics)
    analyzeTextLayout(test_text, 400.0f0, metrics)
    analyzeTextLayout(test_text, 600.0f0, metrics)
end

# Export main functions
export runTextWrapDemo, testWordWrapping, wrapText, createWrappedTextInstances

# Run demo if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    testWordWrapping()
    runTextWrapDemo()
end
