# WGPUFontRenderer

A minimal Julia library for rendering vector fonts using WebGPU, focused on the working example.

## Features

- Vector font rendering using quadratic Bezier curves
- GPU-accelerated text rendering with WGPU
- Integration with WGPUCore and WGPUgfx
- FreeType font loading

## Quick Start

Run the working example:

```bash
julia examples/gpu_font_example.jl
```

## Structure

This repository contains only the essential files needed for the working example:

- `src/` - Core font rendering implementation
- `examples/gpu_font_example.jl` - Working example
- `assets/JuliaMono-Regular.ttf` - Font file

## Dependencies

- WGPUCore
- WGPUNative
- WGPUCanvas
- WGPUgfx
- FreeType
- GLFW

## License

MIT