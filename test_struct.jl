using WGPUFontRenderer

# Test the structure
vertex = BufferVertex(1.0f0, 2.0f0, 0.5f0, 0.5f0, 0)
println("BufferVertex fields:")
println("x: ", vertex.x)
println("y: ", vertex.y)
println("u: ", vertex.u)
println("v: ", vertex.v)
println("bufferIndex: ", vertex.bufferIndex)

# Now try to access as position/uv
# This is what the test was expecting
# But the actual structure has x, y, u, v fields not position/uv
