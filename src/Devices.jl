__precompile__()
module Devices

using PyCall
using ForwardDiff
import FixedSizeArrays: Point
import Base: cell, length, show, .+, .-

const _gdspy = PyCall.PyNULL()
const _pyclipper = PyCall.PyNULL()
const _qr = PyCall.PyNULL()

function __init__()
    copy!(_gdspy, pyimport("gdspy"))
    copy!(_qr, pyimport("pyqrcode"))
    copy!(_pyclipper, pyimport("pyclipper"))
    @osx_only push!(Libdl.DL_LOAD_PATH, joinpath(Pkg.dir("Devices"), "deps"))
end

gdspy() = Devices._gdspy
qr() = Devices._qr
pyclipper() = Devices._pyclipper

const FEATURE_BOUNDING_LAYER = 1
const CHIP_BOUNDING_LAYER    = 2
const CLIP_PLACEMENT_LAYER   = 3
const FEATURES_LAYER         = 5

const UNIT      = 1.0e-6
const PRECISION = 1.0e-9

export FEATURE_BOUNDING_LAYER
export CHIP_BOUNDING_LAYER
export CLIP_PLACEMENT_LAYER
export FEATURES_LAYER
export UNIT
export PRECISION

export andnot
export boolean
export bounds
export heal
export intersect
export render
export union
export view
export xor

export interdigit

function render end

include("Points.jl")
import .Points: Point, getx, gety, setx!, sety!
export Points
export Point, getx, gety, setx!, sety!

and(x,y) = x & y
or(x,y) = x | y
xor(x,y) = x $ y
andnot(x,y) = x &~ y

union(iterable::AbstractArray, name, layer::Integer, datatype::Integer) =
    boolean(iterable, name, layer, datatype, (x...)->reduce(or, [x...]))
intersect(iterable::AbstractArray, name, layer::Integer, datatype::Integer) =
    boolean(iterable, name, layer, datatype, (x...)->reduce(and, [x...]))
xor(iterable::AbstractArray, name, layer::Integer, datatype::Integer) =
    boolean(iterable, name, layer, datatype, (x...)->reduce(xor, [x...]))
andnot(iterable::AbstractArray, name, layer::Integer, datatype::Integer) =
    boolean(iterable, name, layer, datatype, (x...)->reduce(andnot, [x...]))

"""
Performs a boolean operation.
"""
function boolean(iterable::AbstractArray, name,
        layer::Integer, datatype::Integer, λ::Function)
    newp = gdspy()[:boolean](iterable, λ, layer=layer, datatype=datatype)
    c = cell(name)
    c[:add](newp)
end

"Return a PyObject representing a cell."
function cell(name)
    if haskey(gdspy()[:Cell][:cell_dict], name)
        c = gdspy()[:Cell][:cell_dict][name]
    else
        c = gdspy()[:Cell](name)
    end
    return c
end

"Get polygons from `cell`, `layer`, and `datatype`."
function get_polygons(name::AbstractString, layer::Integer, datatype::Integer)
    c = cell(name)
    gdspy()[:PolygonSet](c[:get_polygons](by_spec=true)[(layer,datatype)])
end

"Get all polygons from cell `name`."
function get_polygons(name::AbstractString)
    c = cell(name)
    gdspy()[:PolygonSet](c[:get_polygons]())
end

"""
Will remove overlaps and may reduce polygon count, depending on geometry.
Seems a little bit slow. Healing may also be done in Beamer. YMMV.
"""
function heal(name, layer0, datatype0, newname, layer, datatype)
    plgs = get_polygons(name, layer0, datatype0)
    λ = pyeval("lambda p1: p1")
    newp = gdspy()[:boolean]([plgs], λ, layer=layer, datatype=datatype)
    c = cell(newname)
    c[:add](newp)
end

"Launch a LayoutViewer window."
view() = gdspy()[:LayoutViewer]()

function interdigit(cellname; width=2, length=400, xgap=3, ygap=2, npairs=40, layer=FEATURES_LAYER)
    c = gdspy()[:Cell](cellname)

    for i = 1:npairs
        c[:add](gdspy()[:Rectangle]((0,(i-1)*2*(width+ygap)), (length,(i-1)*2*(width+ygap)+width), layer=layer))
        c[:add](gdspy()[:Rectangle]((xgap,(2i-1)*(width+ygap)), (xgap+length,width+(2i-1)*(width+ygap)), layer=layer))
    end

    c
end

function bounds end

abstract AbstractPolygon{T}

include("Rectangles.jl")
import .Rectangles: Rectangle, center, height, width
export Rectangles
export Rectangle
export center
export height
export width

"""
`bounds(name::AbstractString, layer::Integer, datatype::Integer)`

Returns coordinates for a bounding box around all polygons of `layer`
and `datatype` in cell `name`. The return format is ((x1,y1),(x2,y2)).
"""
function bounds(name, layer::Integer, datatype::Integer)
    p = get_polygons(name,layer,datatype)
    tup = p[:get_bounding_box]()
    tup == nothing &&
        return Rectangle(Point{2,Float64}(0.0,0.0), Point{2,Float64}(0.0,0.0))
    (x1,x2,y1,y2) = tup
    Rectangle(Point{2,Float64}(x1,y1),Point{2,Float64}(x2,y2))
end

"""
`bounds(name::AbstractString)`

Returns coordinates for a bounding box around all polygons in cell `name`.
The return format is ((x1,y1),(x2,y2)).
"""
function bounds(name)
    tup = cell(name)[:get_bounding_box]()
    tup == nothing &&
        return Rectangle(Point{2,Float64}(0.0,0.0), Point{2,Float64}(0.0,0.0))
    (x1,x2,y1,y2) = tup
    Rectangle(Point{2,Float64}(x1,y1),Point{2,Float64}(x2,y2))
end


include("paths/Paths.jl")
import .Paths: Path, adjust!, launch!, meander! #,attach!
import .Paths: param, pathlength, simplify!, straight!, turn! #, preview
export Paths
export Path
export adjust!
# export attach!
export launch!
export meander!
export param
export pathlength
# export preview
export simplify!
export straight!
export turn!

function render(r::Rectangle, s::Rectangles.Style=Rectangles.Plain();
        name="main", layer::Real=0, datatype::Real=0)
    render(r, s, name, layer, datatype)
end

"""
Render a rect `r` to the cell with name `name`.
Keyword arguments give a `layer` and `datatype` (default to 0).
"""
function render(r::Rectangle, ::Rectangles.Plain, name, layer, datatype)
    c = cell(name)
    gr = gdspy()[:Rectangle](r.ll,r.ur,layer=layer,datatype=datatype)
    c[:add](gr)
end

"""
Render a rounded rectangle `r` to the cell `name`.
This is accomplished by rendering a path around the outside of a
(smaller than requested) solid rectangle.
"""
function render(r::Rectangle, s::Rectangles.Rounded, name, layer, datatype)
    c = cell(name)
    rad = s.r
    ll, ur = minimum(r), maximum(r)
    gr = gdspy()[:Rectangle](ll+Point(rad,rad),ur-Point(rad,rad),
        layer=layer, datatype=datatype)
    c[:add](gr)
    p = Path(ll+Point(rad,rad/2), 0.0, Paths.Trace(s.r))
    straight!(p, width(r)-2*rad)
    turn!(p, π/2, rad/2)
    straight!(p, height(r)-2*rad)
    turn!(p, π/2, rad/2)
    straight!(p, width(r)-2*rad)
    turn!(p, π/2, rad/2)
    straight!(p, height(r)-2*rad)
    turn!(p, π/2, rad/2)
    render(p, name=name, layer=layer, datatype=datatype)
end

include("polygons/Polygons.jl")
import .Polygons: Polygon, gpc_clip, clip, offset,
    CT_INTERSECTION, CT_UNION, CT_DIFFERENCE, CT_XOR,
    JT_SQUARE, JT_ROUND, JT_MITER,
    ET_CLOSEDPOLYGON, ET_CLOSEDLINE, ET_OPENSQUARE, ET_OPENROUND, ET_OPENBUTT,
    PFT_EVENODD, PFT_NONZERO, PFT_POSITIVE, PFT_NEGATIVE
export Polygons
export Polygon
export gpc_clip, clip, offset
export CT_INTERSECTION, CT_UNION, CT_DIFFERENCE, CT_XOR,
    JT_SQUARE, JT_ROUND, JT_MITER,
    ET_CLOSEDPOLYGON, ET_CLOSEDLINE, ET_OPENSQUARE, ET_OPENROUND, ET_OPENBUTT,
    PFT_EVENODD, PFT_NONZERO, PFT_POSITIVE, PFT_NEGATIVE

include("Tags.jl")
import .Tags: qrcode, radialstub
export Tags
export qrcode
export radialstub

# Operations on arrays of AbstractPolygons
for (op, dotop) in [(:+, :.+), (:-, :.-)]
    @eval function ($dotop){S<:Real, T<:Real}(a::AbstractArray{AbstractPolygon{S},1}, p::Point{2,T})
        b = similar(a)
        for (ia, ib) in zip(eachindex(a), eachindex(b))
            @inbounds b[ib] = ($op)(a[ia], p)
        end
        b
    end
end

include("GDS.jl")
end