using WGPUCore
using WGPUCore: WGPUTextureFormat, getEnum
using CEnum

# Test enum conversion
println("Testing enum conversion...")

# Test direct access
println("Direct enum access:")
direct_enum = WGPUCore.WGPUTextureFormat_BGRA8Unorm
println("WGPUTextureFormat_BGRA8Unorm = ", direct_enum)
println("WGPUTextureFormat_BGRA8Unorm value = ", Int(direct_enum))

# Test WGPUCore.getEnum
println("\nWGPUCore.getEnum test:")
try
    result = WGPUCore.getEnum(WGPUTextureFormat, "BGRA8Unorm")
    println("getEnum result: ", result)
    println("getEnum result value: ", Int(result))
    println("Equal to direct enum: ", result == direct_enum)
catch e
    println("Error in getEnum: ", e)
end

# Test all enum pairs
println("\nAll texture format enum pairs:")
pairs = CEnum.name_value_pairs(WGPUTextureFormat)
for (key, value) in pairs
    pattern = split(string(key), "_")[end]
    if pattern == "BGRA8Unorm"
        println("Found match: $key => $value")
    end
end

# Test what happens with RGBA8Unorm
println("\nTesting RGBA8Unorm:")
try
    result = WGPUCore.getEnum(WGPUTextureFormat, "RGBA8Unorm")
    println("RGBA8Unorm result: ", result)
    println("RGBA8Unorm value: ", Int(result))
catch e
    println("Error with RGBA8Unorm: ", e)
end
