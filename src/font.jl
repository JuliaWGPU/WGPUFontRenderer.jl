# following https://github.com/GreenLightning/gpu-font-rendering.git
# This is to get comfortable with freetype library ...
# We will then work on WGSL shaders with modified renderer.
# Hopefully efficient one for WGPUMakie library ...

using FreeType

using WGPUCore

# __precompile__(false)

rootType(::Type{Ref{T}}) where T = T

Base.fieldnames(::Type{FT_Face}) = Base.fieldnames(FT_FaceRec)
Base.fieldnames(::Type{FT_GlyphSlot}) = Base.fieldnames(FT_GlyphSlotRec)

Base.getproperty(fo::FT_Face, sym::Symbol) =
    Base.getproperty(fo |> unsafe_load, sym)
Base.getproperty(fo::FT_GlyphSlot, sym::Symbol) =
    Base.getproperty(fo |> unsafe_load, sym)

struct Glyph
    index::UInt32
    bufferIndex::Int32
    curveCount::Int32
    width::Int32  # Changed from FT_Pos to Int32
    height::Int32
    bearingX::Int32
    bearingY::Int32
    advance::Int32
end

struct BufferGlyph
    start::UInt32
    count::UInt32
end

struct BufferCurve
    x0::Float32
    y0::Float32
    x1::Float32
    y1::Float32
    x2::Float32
    y2::Float32
end

struct BufferVertex
    x::Float32
    y::Float32
    z::Float32  # Depth coordinate for z-ordering
    u::Float32
    v::Float32
    bufferIndex::Int32
end

bufferCurves = BufferCurve[]
bufferGlyphs = BufferGlyph[]
glyphs = Dict()

function buildGlyph(face, curves, bufferGlyphs, charCode, glyphIdx)
    # bufferCurves = BufferCurve[]
    faceRec = face |> unsafe_load
    
    # CRITICAL FIX: Store indices correctly for both Julia and GPU access
    # For GPU: 0-based indexing is used
    # For Julia: 1-based indexing is needed
    glyphStartGPU = UInt32(curves |> length)  # 0-based for GPU
    glyphStartJulia = glyphStartGPU + 1       # 1-based for Julia arrays

    # Start with 0-based indexing to match C++ reference implementation
    start = 0

    glyph = faceRec.glyph |> unsafe_load

    nContours = glyph.outline.n_contours
    contours = unsafe_wrap(Array, glyph.outline.contours, nContours)

    for contourIdx in 1:nContours
        # Convert from 0-based to 1-based for Julia array indexing
        # contours[contourIdx] is 0-based from C, so we add 1 for Julia
        convertContour(curves, glyph.outline, start + 1, contours[contourIdx] + 1)
        start = contours[contourIdx] + 1
        # Debug info commented out to prevent log overflow
    end

    glyphCount = UInt32((curves |> length) - glyphStartGPU)
    
    # Store GPU-compatible (0-based) indices in BufferGlyph for GPU buffer
    bufferGlyph = BufferGlyph(glyphStartGPU, glyphCount)
    # CRITICAL FIX: Julia bufferGlyphs length before push is the correct 0-based index for shader
    # When we push this glyph, it will be at index length(bufferGlyphs), which is 0-based for WGSL
    bufferIdx = length(bufferGlyphs)  # This gives 0-based index: 0, 1, 2, 3...
    push!(bufferGlyphs, bufferGlyph)

    # DEBUG: Basic validation without verbose output
    # if charCode in ['H', 'e', 'l']
    #     println("DEBUG: Glyph '$charCode': bufferIdx=$bufferIdx, start=$glyphStart, count=$glyphCount")
    # end

    glyph = Glyph(
        UInt32(glyphIdx),
        Int32(bufferIdx),  # Now correctly 0-based for shader (0, 1, 2, 3...)
        Int32(glyphCount),
        Int32(glyph.metrics.width),
        Int32(glyph.metrics.height),
        Int32(glyph.metrics.horiBearingX),
        Int32(glyph.metrics.horiBearingY),
        Int32(glyph.metrics.horiAdvance),
    )
    glyphs[charCode] = glyph
end


function convertContour(bufferCurves, outline, firstIdx, lastIdx)
    if firstIdx == lastIdx
        return
    end
    dIdx = 1
    if (outline.flags & FT_OUTLINE_REVERSE_FILL)  == 1
        (lastIdx, firstIdx) = (firstIdx, lastIdx)
        dIdx = -1
    end

    tags = unsafe_wrap(Array, outline.tags, outline.n_points)
    points = unsafe_wrap(Array, outline.points, outline.n_points)
    
    # Helper function to convert FT_Vector to normalized coordinates
    function convert(v)
        return [Float32(v.x), Float32(v.y)]
    end
    
    # Helper function to create midpoint
    function makeMidpoint(a, b)
        return 0.5f0 * (a .+ b)
    end
    
    # Helper function to create curve
    function makeCurve(p0, p1, p2)
        return BufferCurve(p0[1], p0[2], p1[1], p1[2], p2[1], p2[2])
    end
    
    # Find a point that is on the curve and remove it from the list
    local first
    firstOnCurve = (tags[firstIdx] & FT_CURVE_TAG_ON) == 1
    if firstOnCurve
        first = convert(points[firstIdx])
        firstIdx += dIdx
    else
        lastOnCurve = (tags[lastIdx] & FT_CURVE_TAG_ON) == 1
        if lastOnCurve
            first = convert(points[lastIdx])
            lastIdx -= dIdx
        else
            first = makeMidpoint(convert(points[firstIdx]), convert(points[lastIdx]))
            # This is a virtual point, so we don't have to remove it
        end
    end
    
    start = first
    control = first
    previous = first
    previousTag = FT_CURVE_TAG_ON
    
    for idx in firstIdx:dIdx:lastIdx
        current = convert(points[idx])
        currentTag = tags[idx] & 0x3  # Extract the tag bits (0x3 = 11 binary)
        
        if currentTag == FT_CURVE_TAG_CUBIC
            # No-op, wait for more points
            control = previous
        elseif currentTag == FT_CURVE_TAG_ON
            if previousTag == FT_CURVE_TAG_CUBIC
                # Cubic bezier approximation with two quadratic curves
                b0 = start
                b1 = control
                b2 = previous
                b3 = current

                c0 = b0 .+ 0.75f0*(b1 .- b0)
                c1 = b3 .+ 0.75f0*(b2 .- b3)
                d = makeMidpoint(c0, c1)

                push!(bufferCurves, makeCurve(b0, c0, d))
                push!(bufferCurves, makeCurve(d, c1, b3))
            elseif previousTag == FT_CURVE_TAG_ON
                # Linear segment
                push!(bufferCurves, makeCurve(previous, makeMidpoint(previous, current), current))
            else
                # Regular bezier curve
                push!(bufferCurves, makeCurve(start, previous, current))
            end
            start = current
            control = current
        else # currentTag == FT_CURVE_TAG_CONIC
            if previousTag == FT_CURVE_TAG_ON
                # No-op, wait for third point
            else
                # Create virtual on point
                mid = makeMidpoint(previous, current)
                push!(bufferCurves, makeCurve(start, previous, mid))
                start = mid
                control = mid
            end
        end
        previous = current
        previousTag = currentTag
    end

    # Close the contour
    if previousTag == FT_CURVE_TAG_CUBIC
        b0 = start
        b1 = control
        b2 = previous
        b3 = first

        c0 = b0 .+ 0.75f0*(b1 .- b0)
        c1 = b3 .+ 0.75f0*(b2 .- b3)
        d = makeMidpoint(c0, c1)

        push!(bufferCurves, makeCurve(b0, c0, d))
        push!(bufferCurves, makeCurve(d, c1, b3))
    elseif previousTag == FT_CURVE_TAG_ON
        # Linear segment
        push!(bufferCurves, makeCurve(previous, makeMidpoint(previous, first), first))
    else
        # Regular bezier curve
        push!(bufferCurves, makeCurve(start, previous, first))
    end
end

str = """
    In the center of Fedora, that gray stone metropolis, stands a metal building
    with a crystal globe in every room. Looking into each globe, you see a blue
    city, the model of a different Fedora. These are the forms the city could have
    taken if, for one reason or another, it had not become what we see today. In
    every age someone, looking at Fedora as it was, imagined a way of making it the
    ideal city, but while he constructed his miniature model, Fedora was already no
    longer the same as before, and what had been until yesterday a possible future
    became only a toy in a glass globe.

    The building with the globes is now Fedora's museum: every inhabitant visits it,
    chooses the city that corresponds to his desires, contemplates it, imagining his
    reflection in the medusa pond that would have collected the waters of the canal
    (if it had not been dried up), the view from the high canopied box along the
    avenue reserved for elephants (now banished from the city), the fun of sliding
    down the spiral, twisting minaret (which never found a pedestal from which to
    rise).

    On the map of your empire, O Great Khan, there must be room both for the big,
    stone Fedora and the little Fedoras in glass globes. Not because they are all
    equally real, but because they are only assumptions. The one contains what is
    accepted as necessary when it is not yet so; the others, what is imagined as
    possible and, a moment later, is possible no longer.

    [from Invisible Cities by Italo Calvino]
"""

# Global variable to store emSize from font
fontEmSize = 64

function prepareGlyphsForText(str::String)
    # Clear global buffers to prevent accumulation
    empty!(bufferCurves)
    empty!(bufferGlyphs)
    empty!(glyphs)
    
    ftLib = Ref{FT_Library}(C_NULL)

    FT_Init_FreeType(ftLib)

    @assert ftLib[] != C_NULL

    function loadFace(filename::String, ftlib=ftLib[])
        face = Ref{FT_Face}()
        err = FT_New_Face(ftlib, filename, 0, face)
        @assert err == 0 "Could not load face at $filename with index 0 : Errored $err"
        return face[]
    end

    face = loadFace(joinpath(pkgdir(WGPUFontRenderer), "assets", "JuliaMono-Light.ttf"))

    # Store the font's emSize globally
    global fontEmSize = face.units_per_EM
    # Debug output disabled

    # Use FT_LOAD_NO_SCALE to get font units directly (like the reference implementation)
    loadFlags = FT_LOAD_NO_SCALE | FT_LOAD_NO_HINTING | FT_LOAD_NO_BITMAP

    for chr in str
        glyphIdx = FT_Get_Char_Index(face, chr)
        FT_Load_Glyph(face, glyphIdx, loadFlags)
        glyph = face.glyph |> unsafe_load
        outline = glyph.outline
        buildGlyph(face, bufferCurves, bufferGlyphs, chr, glyphIdx)
    end

    FT_Done_FreeType(ftLib[])
end


function getShaderCode()
    src = quote
        struct BufferGlyph
            start::UInt32
            stop::UInt32
        end

        struct BufferCurve
            p0::Vec2{Float32}
            p1::Vec2{Float32}
            p2::Vec2{Float32}
        end

        @var StorageRead 0 0 glyph::@user BufferGlyph
        @var StorageRead 0 1 curve::@user BufferCurve

    end
end


function getVertexBufferLayout(glyph::Glyph; offset = 0)
    WGPUCore.GPUVertexBufferLayout => []
end


function getBindingLayouts(glyph::Glyph; binding=0)
    bindingLayouts = [
        WGPUCore.WGPUBufferEntry => [
            :binding => binding,
            :visibility => ["Vertex", "Fragment", "Compute"],
            :type => "StorageRead"
        ],
    ]
    return bindingLayouts
end


function getBindings(glyph::Glyph, uniformBuffer; binding=0)
    bindings = [
        WGPUCore.GPUBuffer => [
            :binding => binding,
            :buffer  => uniformBuffer,
            :offset  => 0,
            :size    => uniformBuffer.size
        ],
    ]
end



# font = FTFont(joinpath(@__DIR__, "..", "assets", "JuliaMono-Light.ttf"))

#
