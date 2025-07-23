# Test to verify the debug shader (no super-sampling) is working correctly

using Pkg
Pkg.develop(path="C:\\Users\\arhik\\.julia\\dev\\WGPUFontRenderer")
using WGPUFontRenderer

function testShaderOutput()
    println("="^60)
    println("DEBUG SHADER VERIFICATION")
    println("="^60)
    
    # Get the current default fragment shader
    fragmentShader = getFragmentShader()
    
    println("Current default fragment shader:")
    println("Length: $(length(fragmentShader)) characters")
    
    # Check if it contains the debug features we added
    if contains(fragmentShader, "super-sampling DISABLED")
        println("✓ Using NO SUPER-SAMPLING debug shader")
        println("✓ Super-sampling code is removed")
    else
        println("✗ Still using original shader with super-sampling")
    end
    
    if contains(fragmentShader, "inverseDiameter = 1.0 / uniforms.antiAliasingWindowSize")
        println("✓ Using simplified anti-aliasing calculation")
        println("✓ No complex fwidth approximation")
    else
        println("✗ Still using complex fwidth approximation")
    end
    
    if contains(fragmentShader, "NO averaging since we only have one sample")
        println("✓ No sample averaging (single ray only)")
    else
        println("✗ Still averaging samples")
    end
    
    println("\n" * "="^60)
    println("SHADER ANALYSIS:")
    println("="^60)
    
    # Get the no-super-sampling shader specifically
    noSuperSamplingShader = getNoSuperSamplingShader()
    
    if fragmentShader == noSuperSamplingShader
        println("✓ DEFAULT SHADER IS THE DEBUG SHADER")
        println("  The horizontal line issue can now be isolated:")
        println("  - If lines disappear → super-sampling was the cause")
        println("  - If lines persist → coordinate scaling issue")
    else
        println("✗ Default shader is NOT the debug shader")
        println("  Need to switch to debug shader manually")
    end
    
    println("\n" * "="^60)
    println("RENDERING TEST RECOMMENDATIONS:")
    println("="^60)
    println("1. Try rendering text now with your existing code")
    println("2. The debug shader should be used automatically")
    println("3. Compare to previous results:")
    println("   - Are horizontal lines reduced/gone?")
    println("   - Is text still readable?")
    println("   - Are edges sharper or softer?")
    println("4. If issues persist, the problem is in coordinate scaling")
    println("5. If issues are resolved, the problem was super-sampling")
    
    return fragmentShader == noSuperSamplingShader
end

if abspath(PROGRAM_FILE) == @__FILE__
    success = testShaderOutput()
    
    if success
        println("\n🎉 DEBUG SHADER IS ACTIVE!")
        println("You can now test your font rendering to see if horizontal lines are fixed.")
    else
        println("\n⚠️  DEBUG SHADER NOT ACTIVE")
        println("You may need to manually switch to getNoSuperSamplingShader() in your renderer.")
    end
end
