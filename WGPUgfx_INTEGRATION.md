# WGPUFontRenderer - WGPUgfx Integration

This directory contains the integration of WGPUFontRenderer with WGPUgfx through the FontRenderableUI interface.

## Overview

The FontRenderableUI module provides a bridge between the high-performance vector font renderer and the WGPUgfx scene graph system. This allows font rendering to be seamlessly integrated into WGPUgfx applications with full support for:

- Animation through the RenderableUI interface
- Positioning and scaling
- Color customization
- Integration with WGPUgfx's rendering pipeline

## Key Components

### FontRenderableUI
A concrete implementation of WGPUgfx's RenderableUI abstract type that encapsulates:
- A complete WGPUFontRenderer instance
- Position, scale, and color properties
- Animation support through time-based updates

### Integration Features
- **Animation Support**: Built-in animation functions for moving text
- **Dynamic Text Updates**: Change text content at runtime
- **Position Control**: Precise positioning within the WGPUgfx coordinate system
- **WGPUgfx Compatibility**: Full compliance with RenderableUI interface requirements

## Usage Example

```julia
using WGPUCore
using WGPUgfx
using WGPUFontRenderer

# Create font renderable UI for WGPUgfx integration
fontRenderable = defaultFontRenderableUI(
    device, 
    queue, 
    "Hello WGPUgfx!",
    position=[100.0f0, 100.0f0],
    color=[1.0f0, 0.0f0, 0.0f0, 1.0f0]  # Red text
)

# Prepare the object for rendering (required by WGPUgfx)
WGPUgfx.prepareObject(device, fontRenderable)

# In render loop:
function render_frame(renderPass)
    # Render the font using WGPUgfx's render system
    WGPUgfx.render(renderPass, nothing, fontRenderable, cameraId)
end

# Animate the text
animatePosition!(fontRenderable, time)

# Update text dynamically
setText!(fontRenderable, "New Text!")

# Set position directly
setPosition!(fontRenderable, 200.0f0, 150.0f0)
```

## Files

- `src/WGPUgfxFont.jl` - Main FontRenderableUI implementation
- `examples/wgpugfx_font_example.jl` - Basic WGPUgfx integration example
- `examples/font_renderableui_wgpugfx.jl` - Complete FontRenderableUI + WGPUgfx integration demo
- `examples/simple_font_wgpugfx.jl` - Minimal FontRenderableUI integration example
- `test/test_wgpugfx_integration.jl` - Comprehensive integration tests

## Benefits

1. **Seamless Integration**: Works with existing WGPUgfx applications
2. **High Performance**: Leverages optimized vector font rendering
3. **Animation Ready**: Built-in support for animated text effects
4. **Flexible**: Supports dynamic text updates and positioning
5. **Standard Interface**: Follows WGPUgfx RenderableUI conventions

This integration makes it easy to add high-quality, animated font rendering to any WGPUgfx application.