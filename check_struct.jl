# Minimal struct definition to check size and alignment
struct FontUniforms
    color::NTuple{4, Float32}
    projection::NTuple{16, Float32}  # 4x4 projection matrix
    antiAliasingWindowSize::Float32
    enableSuperSamplingAntiAliasing::UInt32
    padding::NTuple{2, UInt32}  # Padding for alignment
end

println("FontUniforms size: ", sizeof(FontUniforms))
println("Fields: ", fieldnames(FontUniforms))
println("antiAliasingWindowSize offset: ", fieldoffset(FontUniforms, 3))

# Check if size is a multiple of 16 (common GPU alignment requirement)
println("Size is multiple of 16: ", sizeof(FontUniforms) % 16 == 0)