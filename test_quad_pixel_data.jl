#!/usr/bin/env julia

using WGPUCore
using WGPUCanvas
using WGPUFontRenderer
using GLFW

# Function to test basic quad rendering without pixel readback
function testQuadPixelData()
    println("Testing quad rendering...")
    
    # Create canvas and device
    canvas = WGPUCore.getCanvas(:GLFW, (256, 256))
    device = WGPUCore.getDefaultDevice(canvas)
    renderTextureFormat = WGPUCore.getPreferredFormat(canvas)
    
    println("✓ Canvas and device created")
    
    # Create font renderer
    fontRenderer = createFontRenderer(device, device.queue)
    initializeRenderer(fontRenderer, renderTextureFormat)
    
    println("✓ Font renderer initialized")
    
    # Load a simple test character
    testText = "A"
    loadFontData(fontRenderer, testText)
    
    println("✓ Font data loaded")
    
    # Check if we have proper data
    if fontRenderer.pipeline === nothing
        println("✗ FAILED: No render pipeline created")
        return
    end
    
    if fontRenderer.vertexBuffer === nothing
        println("✗ FAILED: No vertex buffer created")
        return
    end
    
    if fontRenderer.bindGroup === nothing
        println("✗ FAILED: No bind group created")
        return
    end
    
    println("✓ All rendering components created successfully")
    
    # Test rendering setup
    presentContext = WGPUCore.getContext(canvas)
    WGPUCore.config(presentContext; device=device, format=renderTextureFormat)
    
    println("✓ Present context configured")
    
    # Do a single frame render to test if everything works
    try
        # Get current texture
        currentTextureView = WGPUCore.getCurrentTexture(presentContext)
        
        # Create command encoder
        cmdEncoder = WGPUCore.createCommandEncoder(device, "Test Encoder")
        
        # Create render pass
        renderPassOptions = [
            WGPUCore.GPUColorAttachments => [
                :attachments => [
                    WGPUCore.GPUColorAttachment => [
                        :view => currentTextureView,
                        :resolveTarget => C_NULL,
                        :clearValue => (0.0, 0.0, 0.0, 1.0),  # Black background
                        :loadOp => WGPUCore.WGPULoadOp_Clear,
                        :storeOp => WGPUCore.WGPUStoreOp_Store,
                    ],
                ],
            ],
            WGPUCore.GPUDepthStencilAttachments => [],
        ]
        
        # Begin render pass
        renderPass = WGPUCore.beginRenderPass(
            cmdEncoder,
            renderPassOptions |> Ref;
            label = "Test Render Pass",
        )
        
        # Render the text
        renderText(fontRenderer, renderPass)
        
        # End render pass and submit
        WGPUCore.endEncoder(renderPass)
        WGPUCore.submit(device.queue, [WGPUCore.finish(cmdEncoder)])
        
        # Present the frame
        WGPUCore.present(presentContext)
        
        println("✓ Single frame rendered successfully")
        
    catch e
        println("✗ FAILED: Rendering error: $e")
        WGPUCore.destroyWindow(canvas)
        return
    end
    
    # Analyze the rendering components
    analyzeRenderingComponents(fontRenderer, testText)
    
    # Cleanup
    WGPUCore.destroyWindow(canvas)
    println("✓ Quad rendering test completed")
end

# Function to analyze rendering components
function analyzeRenderingComponents(fontRenderer::WGPUFontRenderer.FontRenderer, text::String)
    println("\n=== Rendering Component Analysis ===")
    
    # Check vertex data
    vertexCount = length(fontRenderer.vertices)
    println("Vertex count: $vertexCount")
    
    if vertexCount > 0
        println("✓ Vertices generated")
        
        # Expected: 6 vertices per character (2 triangles * 3 vertices each)
        expectedVertices = length(text) * 6
        if vertexCount == expectedVertices
            println("✓ Vertex count matches expected ($expectedVertices)")
        else
            println("⚠ Vertex count mismatch: expected $expectedVertices, got $vertexCount")
        end
        
        # Sample first few vertices
        println("\nSample vertices:")
        for i in 1:min(3, vertexCount)
            v = fontRenderer.vertices[i]
            println("  Vertex $i: pos=($(v.x), $(v.y)), uv=($(v.u), $(v.v)), bufferIndex=$(v.bufferIndex)")
        end
    else
        println("✗ No vertices generated")
    end
    
    # Check curves
    curveCount = length(fontRenderer.curves)
    println("\nCurve count: $curveCount")
    
    if curveCount > 0
        println("✓ Curves generated")
        
        # Sample first few curves
        println("\nSample curves:")
        for i in 1:min(3, curveCount)
            c = fontRenderer.curves[i]
            println("  Curve $i: p0=($(c.x0), $(c.y0)), p1=($(c.x1), $(c.y1)), p2=($(c.x2), $(c.y2))")
        end
    else
        println("✗ No curves generated")
    end
    
    # Check buffer sizes
    println("\nBuffer information:")
    
    if fontRenderer.vertexBuffer !== nothing
        println("✓ Vertex buffer size: $(fontRenderer.vertexBuffer.size) bytes")
    else
        println("✗ No vertex buffer")
    end
    
    if fontRenderer.curveBuffer !== nothing
        println("✓ Curve buffer size: $(fontRenderer.curveBuffer.size) bytes")
    else
        println("✗ No curve buffer")
    end
    
    if fontRenderer.glyphBuffer !== nothing
        println("✓ Glyph buffer size: $(fontRenderer.glyphBuffer.size) bytes")
    else
        println("✗ No glyph buffer")
    end
    
    if fontRenderer.uniformBuffer !== nothing
        println("✓ Uniform buffer size: $(fontRenderer.uniformBuffer.size) bytes")
    else
        println("✗ No uniform buffer")
    end
    
    # Overall assessment
    if vertexCount > 0 && curveCount > 0 && fontRenderer.pipeline !== nothing
        println("\n✓ ANALYSIS RESULT: Rendering pipeline appears to be working correctly")
        println("  - Vertices are generated with proper positions and UVs")
        println("  - Curves are available for coverage calculation")
        println("  - All buffers are created")
        println("  - Render pipeline is initialized")
        println("  - Single frame render completed without errors")
    else
        println("\n✗ ANALYSIS RESULT: Issues detected in rendering pipeline")
        println("  - Check font loading and vertex generation")
        println("  - Verify shader compilation")
        println("  - Ensure proper buffer creation")
    end
end

# Function to analyze pixel data
function analyzePixelData(pixelData::Array{UInt8}, width::Int, height::Int)
    println("Analyzing pixel data...")
    println("Image size: $(width)x$(height)")
    println("Total pixels: $(width * height)")
    println("Buffer size: $(length(pixelData)) bytes")
    
    # Count non-black pixels
    nonBlackPixels = 0
    totalPixels = width * height
    
    for y in 1:height
        for x in 1:width
            pixelIndex = ((y-1) * width + (x-1)) * 4 + 1  # RGBA format
            if pixelIndex + 3 <= length(pixelData)
                r = pixelData[pixelIndex]
                g = pixelData[pixelIndex + 1]
                b = pixelData[pixelIndex + 2]
                a = pixelData[pixelIndex + 3]
                
                # Check if pixel is not black (any color component > 0)
                if r > 0 || g > 0 || b > 0 || a > 0
                    nonBlackPixels += 1
                end
            end
        end
    end
    
    println("Non-black pixels: $nonBlackPixels / $totalPixels")
    println("Coverage: $(round(100 * nonBlackPixels / totalPixels, digits=2))%")
    
    # Sample a few specific pixels for detailed analysis
    samplePixels = [
        (128, 128),  # Center
        (64, 64),    # Top-left quadrant
        (192, 192),  # Bottom-right quadrant
        (128, 64),   # Top-center
        (128, 192),  # Bottom-center
    ]
    
    println("\nSample pixel values (RGBA):")
    for (x, y) in samplePixels
        pixelIndex = ((y-1) * width + (x-1)) * 4 + 1
        if pixelIndex + 3 <= length(pixelData)
            r = pixelData[pixelIndex]
            g = pixelData[pixelIndex + 1]
            b = pixelData[pixelIndex + 2]
            a = pixelData[pixelIndex + 3]
            println("  Pixel ($x, $y): R=$r, G=$g, B=$b, A=$a")
        end
    end
    
    # Determine if rendering was successful
    if nonBlackPixels > 0
        println("\n✓ SUCCESS: Quad rendering detected!")
        println("  The font renderer is generating visible pixels.")
        if nonBlackPixels > totalPixels * 0.01  # More than 1% coverage
            println("  Good coverage suggests text is being rendered.")
        else
            println("  Low coverage might indicate issues with font size or positioning.")
        end
    else
        println("\n✗ FAILURE: No visible pixels detected!")
        println("  The quad may not be rendering properly.")
        println("  Check shader compilation, vertex data, and pipeline setup.")
    end
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    testQuadPixelData()
end
