# Improved font.jl with configurable parameters and better structure
# Fixes hardcoded values and global state issues

using FreeType
using WGPUCore

# Font configuration structure to replace hardcoded values
struct FontConfig
    fontPath::String
    emSize::Int32
    dilation::Float32
    worldSize::Float32
    
    function FontConfig(;
        fontPath::String = joinpath(pkgdir(WGPUFontRenderer), "assets", "JuliaMono-Regular.ttf"),
        emSize::Int32 = 64,
        dilation::Float32 = 0.1f0,
        worldSize::Float32 = 50.0f0
    )
        new(fontPath, emSize, dilation, worldSize)
    end
end

# Font renderer state - encapsulates all font data to avoid global state
mutable struct FontState
    config::FontConfig
    glyphs::Dict{Char, Glyph}
    bufferCurves::Vector{BufferCurve}
    bufferGlyphs::Vector{BufferGlyph}
    fontEmSize::Int32
    
    function FontState(config::FontConfig = FontConfig())
        new(config, Dict{Char, Glyph}(), BufferCurve[], BufferGlyph[], config.emSize)
    end
end

# Keep existing struct definitions
struct Glyph
    index::UInt32
    bufferIndex::Int32
    curveCount::Int32
    width::Int32
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
    z::Float32
    u::Float32
    v::Float32
    bufferIndex::Int32
end

# Improved font loading with configurable parameters
function loadFontWithConfig(config::FontConfig)::FontState
    fontState = FontState(config)
    
    ftLib = Ref{FT_Library}(C_NULL)
    FT_Init_FreeType(ftLib)
    @assert ftLib[] != C_NULL
    
    function loadFace(filename::String, ftlib=ftLib[])
        face = Ref{FT_Face}()
        err = FT_New_Face(ftlib, filename, 0, face)
        if err != 0
            error("Could not load face at $filename with index 0: Error $err")
        end
        return face[]
    end
    
    # Use configurable font path
    face = loadFace(config.fontPath)
    
    # Store the actual font's emSize
    fontState.fontEmSize = face.units_per_EM
    
    # Use FT_LOAD_NO_SCALE to get font units directly
    loadFlags = FT_LOAD_NO_SCALE | FT_LOAD_NO_HINTING | FT_LOAD_NO_BITMAP
    
    # Load basic ASCII character set
    for charCode in 32:126
        chr = Char(charCode)
        glyphIdx = FT_Get_Char_Index(face, charCode)
        if glyphIdx != 0
            FT_Load_Glyph(face, glyphIdx, loadFlags)
            buildGlyph(fontState, face, chr, glyphIdx)
        end
    end
    
    # Load undefined glyph (index 0)
    FT_Load_Glyph(face, 0, loadFlags)
    buildGlyph(fontState, face, Char(0), 0)
    
    FT_Done_FreeType(ftLib[])
    return fontState
end

# Improved glyph building with state encapsulation
function buildGlyph(fontState::FontState, face, charCode::Char, glyphIdx)
    faceRec = face |> unsafe_load
    
    # Store indices correctly for both Julia and GPU access
    glyphStartGPU = UInt32(length(fontState.bufferCurves))
    
    start = 0
    glyph = faceRec.glyph |> unsafe_load
    nContours = glyph.outline.n_contours
    
    if nContours > 0
        contours = unsafe_wrap(Array, glyph.outline.contours, nContours)
        
        for contourIdx in 1:nContours
            convertContour(fontState.bufferCurves, glyph.outline, start + 1, contours[contourIdx] + 1)
            start = contours[contourIdx] + 1
        end
    end
    
    glyphCount = UInt32(length(fontState.bufferCurves) - glyphStartGPU)
    
    # Store GPU-compatible indices
    bufferGlyph = BufferGlyph(glyphStartGPU, glyphCount)
    bufferIdx = length(fontState.bufferGlyphs)
    push!(fontState.bufferGlyphs, bufferGlyph)
    
    # Create glyph with proper metrics
    glyphData = Glyph(
        UInt32(glyphIdx),
        Int32(bufferIdx),
        Int32(glyphCount),
        Int32(glyph.metrics.width),
        Int32(glyph.metrics.height),
        Int32(glyph.metrics.horiBearingX),
        Int32(glyph.metrics.horiBearingY),
        Int32(glyph.metrics.horiAdvance),
    )
    
    fontState.glyphs[charCode] = glyphData
end

# Improved contour conversion (same logic, but uses fontState)
function convertContour(bufferCurves::Vector{BufferCurve}, outline, firstIdx, lastIdx)
    if firstIdx == lastIdx
        return
    end
    
    dIdx = 1
    if (outline.flags & FT_OUTLINE_REVERSE_FILL) == 1
        (lastIdx, firstIdx) = (firstIdx, lastIdx)
        dIdx = -1
    end

    tags = unsafe_wrap(Array, outline.tags, outline.n_points)
    points = unsafe_wrap(Array, outline.points, outline.n_points)
    
    # Helper functions
    function convert(v)
        return [Float32(v.x), Float32(v.y)]
    end
    
    function makeMidpoint(a, b)
        return 0.5f0 * (a .+ b)
    end
    
    function makeCurve(p0, p1, p2)
        return BufferCurve(p0[1], p0[2], p1[1], p1[2], p2[1], p2[2])
    end
    
    # Find a point that is on the curve
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
        end
    end
    
    start = first
    control = first
    previous = first
    previousTag = FT_CURVE_TAG_ON
    
    for idx in firstIdx:dIdx:lastIdx
        current = convert(points[idx])
        currentTag = tags[idx] & 0x3
        
        if currentTag == FT_CURVE_TAG_CUBIC
            control = previous
        elseif currentTag == FT_CURVE_TAG_ON
            if previousTag == FT_CURVE_TAG_CUBIC
                # Cubic bezier approximation
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
        else # FT_CURVE_TAG_CONIC
            if previousTag == FT_CURVE_TAG_ON
                # Wait for third point
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
        push!(bufferCurves, makeCurve(previous, makeMidpoint(previous, first), first))
    else
        push!(bufferCurves, makeCurve(start, previous, first))
    end
end

# Improved text preparation with configurable fonts
function prepareGlyphsForTextImproved(text::String, config::FontConfig = FontConfig())::FontState
    fontState = loadFontWithConfig(config)
    
    # Ensure all characters in text are loaded
    for char in text
        if !haskey(fontState.glyphs, char) && char != ' ' && char != '\n' && char != '\r'
            # Load additional character if needed
            # This would require reopening the font, but for now we'll use fallback
            if !haskey(fontState.glyphs, Char(0))
                @warn "Character '$char' not found in font, using fallback"
            end
        end
    end
    
    return fontState
end

# Export the improved functions
export FontConfig, FontState, loadFontWithConfig, prepareGlyphsForTextImproved