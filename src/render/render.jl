include("rectangles.jl")
include("polygons.jl")
include("paths.jl")
include("corners.jl")
include("trace.jl")
include("cpw.jl")
include("decorated.jl")
include("compound.jl")
include("tapers.jl")
include("strands.jl")

# Generic fallback method
# If there's no specific method for this segment type, use the fallback method for the style.
render!(c::Cell, seg::Paths.Segment, s::Paths.Style, meta::Meta; kwargs...) =
    render!(c, seg, pathlength(seg), s, meta; kwargs...)

# NoRender and friends
function render!(c::Cell, seg::Paths.Segment, s::Paths.NoRenderContinuous, meta::Meta;
    kwargs...) end
function render!(c::Cell, seg::Paths.Segment, s::Paths.NoRenderDiscrete, meta::Meta;
    kwargs...) end
function render!(c::Cell, seg::Paths.Segment, s::Paths.SimpleNoRender,
    meta::Meta; kwargs...) end

function uniquepoints(pts)
    return pts[.![i == 1 ? false : (pts[i] ≈ pts[max(1,i-1)]) for i in 1:size(pts,1)]]
end
