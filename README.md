# WGPUFontRenderer.jl

A Julia font renderer implementation based on the [gpu-font-renderer](https://github.com/GreenLightning/gpu-font-rendering) reference implementation, using WGPUCore and WGPUgfx libraries.

## Overview

This package provides GPU-based vector font rendering capabilities for Julia applications. It follows the architecture and approach of the gpu-font-renderer reference implementation, adapted for Julia's ecosystem and the WGPU graphics API.

## Features

- **Vector Font Rendering**: Renders fonts using Bézier curves for crisp, scalable text
- **GPU Acceleration**: Uses GPU shaders for efficient text rendering
- **WGPUCore Integration**: Built on top of WGPUCore for cross-platform graphics
- **FreeType Integration**: Uses FreeType for font loading and processing
- **Anti-aliasing**: Includes anti-aliasing support for smooth text rendering

## Installation

```julia
using Pkg
Pkg.add("WGPUFontRenderer")
```

## Dependencies

- `WGPUCore`: Core WebGPU bindings for Julia
- `WGPUgfx`: High-level graphics utilities for WGPU
- `FreeType`: Font loading and processing
- `GLFW`: Window management for examples

## Usage

### Basic Usage

```julia
using WGPUCore
using WGPUgfx
using WGPUFontRenderer

# Create WGPU device and queue
canvas = WGPUCore.getCanvas(:GLFW, (800, 600))
device = WGPUCore.getDefaultDevice(canvas)
queue = device.queue

# Get surface format
surfaceFormat = WGPUCore.getPreferredFormat(canvas)

# Create font renderer
fontRenderer = createFontRenderer(device, queue)

# Initialize renderer with surface format
initializeRenderer(fontRenderer, surfaceFormat)

# Load font data for text
text = "Hello, World!"
loadFontData(fontRenderer, text)

# Use in render loop
renderText(fontRenderer, renderPass)
```

### Complete Example

See `examples/gpu_font_example.jl` for a complete working example that demonstrates:
- WGPU initialization
- Font renderer setup
- Main render loop
- Window management

## API Reference

### Main Functions

- `createFontRenderer(device, queue)`: Create a new font renderer instance
- `initializeRenderer(renderer, surfaceFormat)`: Initialize the renderer with shaders and pipeline
- `loadFontData(renderer, text)`: Load font data for the specified text
- `renderText(renderer, renderPass)`: Render text using the font renderer

### Data Structures

- `FontRenderer`: Main renderer state containing GPU resources
- `FontUniforms`: Uniform buffer data for shaders
- `Glyph`: Individual character data
- `BufferCurve`: Bézier curve data for rendering
- `BufferVertex`: Vertex data for rendering

## Architecture

The font renderer follows the gpu-font-renderer architecture:

1. **Font Loading**: Uses FreeType to load font data and extract curve information
2. **Curve Processing**: Converts font outlines to Bézier curves
3. **GPU Buffers**: Stores glyph and curve data in GPU buffers
4. **Vertex Generation**: Creates vertex data for rendering quads
5. **Shader Rendering**: Uses vertex and fragment shaders for curve-based rendering

## Shaders

The renderer includes WGSL shaders for:
- **Vertex Shader**: Transforms vertices and passes data to fragment shader
- **Fragment Shader**: Calculates coverage using Bézier curve mathematics

## Examples

- `examples/gpu_font_example.jl`: Complete demonstration following gpu-font-renderer pattern
- `examples/font_demo.jl`: Alternative demonstration using WGPUCanvas
- `examples/minimal_test.jl`: Basic test for font loading functionality

## Reference Implementation

This implementation is based on the excellent [gpu-font-renderer](https://github.com/GreenLightning/gpu-font-rendering) by GreenLightning, which provides a clear reference for GPU-based font rendering techniques.

## License

This project follows the same principles as the original gpu-font-renderer reference implementation.
