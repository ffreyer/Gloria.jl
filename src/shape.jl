abstract type AbstractShape end

struct Point{T} <: AbstractShape
    x::T
    y::T
end
Point(x, y) = Point(promote(x, y)...)
Base.convert(::Type{Point{T}}, p::Point{S}) where {T,S} = Point(convert(T, p.x), convert(T, p.y))
Base.promote_rule(::Type{Point{T}}, ::Type{Point{S}}) where {T,S} = Point{promote_type(T, S)}

struct Line{T} <: AbstractShape
    x1::T
    y1::T
    x2::T
    y2::T
    t_min::T
    t_max::T
end
Line(p1::Point, p2::Point) where T = Line(promote(p1.x, p1.y, p2.x, p2.y, 0, 1)...)
Line(x1, y1, x2, y2) where T = Line(promote(x1, y1, x2, y2, 0, 1)...)
Line(x1, y1, x2, y2, t_min, t_max) where T = Line(promote(x1, y1, x2, y2, t_min, t_max)...)
Line(x, y, θ; t_min = -Inf, t_max = Inf) = Line(promote(x, y, x + cosd(θ), y + sind(θ), t_min, t_max)...)
Base.convert(::Type{Line{T}}, l::Line{S}) where {T,S} = Line(convert.(T, [l.x1, l.y1, l.x2, l.y2, l.t_min, l.t_max])...)

struct Circle{T} <: AbstractShape
    x::T
    y::T
    r::T
end
Circle(x, y, r) = Circle(promote(x, y, r)...)

"""
    Polygon{N, T}

A .  Like a polygon, except the start and end
vertices are not joined by a line segment.

"""
struct Polygon{N,T} <: AbstractShape
    points::Vector{Point{T}}
    lines::Vector{Line{T}}
end
Polygon(points::Vector{Point{T}}, lines::Vector{Line{T}}) where {N,T} = Polygon{length(lines),T}(points, lines)

function Polygon(point::Point{T}, points::Point{T}...) where T
    N = 1 + length(points)
    lines = Line{T}[]
    p0 = point
    for p1 in points[1:end]
        push!(lines, Line(p0, p1))
        p0 = p1
    end
    if length(points) > 1
        push!(lines, Line(p0, point))
    end
    return Polygon{N,T}([point, points...], lines)
end
Polygon(points...) = Polygon(promote(points...)...)

"""
    Lines{N, T}

A collection of `N` lines.  Like a polygon, except the start and end
vertices are not joined by a line segment.

"""
struct Lines{N,T} <: AbstractShape
    points::Vector{Point{T}}
    lines::Vector{Line{T}}
end
Lines(points::Vector{Point{T}}, lines::Vector{Line{T}}) where {N,T} = Lines{length(lines),T}(points, lines)

function Lines(point::Point{T}, points::Point{T}...) where T
    N = length(points)
    N < 1 && error("At least two points must be given to construct a line")
    lines = Line{T}[]
    p0 = point
    for p1 in points[1:end]
        push!(lines, Line(p0, p1))
        p0 = p1
    end
    return Lines{N,T}([point, points...], lines)
end
Lines(points...) = Lines(promote(points...)...)
function Lines(points::Vector{Point{T}}, lines::Vector{Line{S}}) where {T,S}
    Q = promote_type(T, S)
    return Lines{length(lines)}(convert.(Q, points), convert.(Q, lines))
end

const PolygonOrLines{N,T} = Union{Polygon{N,T}, Lines{N,T}}


struct CompositeShape{T<:AbstractShape} <: AbstractShape
    shapes::Vector{T}
end


"""
    points(shape)
"""
points(p::Point) = [p]
points(l::Line) = [Point(l.x1, l.y1), Point(l.x2, l.y2)]
points(c::Circle; subsamples::Int = 20) = [Point(c.x + c.r*cos(2π*i/subsamples), c.y + c.r*sin(2π*i/subsamples)) for i in 0:(subsamples-1)]
points(m::PolygonOrLines) = m.points
points(s::CompositeShape) = vcat([points(shape) for shape in s.shapes]...)

"""
    simplest(shape1, shape2)
"""
simplest(p::Point, ::Point) = p
simplest(p::Point, ::Line) = p
simplest(p::Point, ::PolygonOrLines) = p
simplest(p::Point, ::Circle) = p
simplest(p::Point, ::CompositeShape) = p

simplest(::Line, p::Point) = p
simplest(l::Line, ::Line) = l
simplest(l::Line, m::PolygonOrLines{N}) where {N} = N < 2 ? m : l
simplest(l::Line, ::Circle) = l
simplest(l::Line, ::CompositeShape) = l

simplest(::PolygonOrLines, p::Point) = p
simplest(m::PolygonOrLines{N}, l::Line) where {N} = N < 2 ? m : l
simplest(m1::PolygonOrLines{N}, m2::PolygonOrLines{M}) where {N,M} = N < M ? m1 : m2
simplest(m::PolygonOrLines, ::Circle) = m
simplest(m::PolygonOrLines, ::CompositeShape) = m

simplest(::Circle, p::Point) = p
simplest(::Circle, l::Line) = l
simplest(::Circle, m::PolygonOrLines) = m
simplest(c::Circle, ::Circle) = c
simplest(::Circle, cs::CompositeShape) = cs

simplest(::CompositeShape, p::Point) = p
simplest(::CompositeShape, l::Line) = l
simplest(::CompositeShape, m::PolygonOrLines) = m
simplest(cs::CompositeShape, ::CompositeShape) = cs
simplest(cs::CompositeShape, ::Circle) = cs

"""
    transform(shape)
"""
transform(p::Point, x, y, θ) = Point(x + cosd(θ)*p.x - sind(θ)*p.y, y + sind(θ)*p.x + cosd(θ)*p.y)
transform(c::Circle, x, y, θ) = Circle(x + cosd(θ)*c.x - sind(θ)*c.y, y + sind(θ)*c.x + cosd(θ)*c.y, c.r)
transform(l::Line, x, y, θ) = Line(x + cosd(θ)*l.x1 - sind(θ)*l.y1, y + sind(θ)*l.x1 + cosd(θ)*l.y1, x + cosd(θ)*l.x2 - sind(θ)*l.y2, y + sind(θ)*l.x2 + cosd(θ)*l.y2, l.t_min, l.t_max)
transform(m::Polygon, x, y, θ) = Polygon(transform.(m.points, x, y, θ), transform.(m.lines, x, y, θ))
transform(m::Lines, x, y, θ) = Lines(transform.(m.points, x, y, θ), transform.(m.lines, x, y, θ))
transform(cs::CompositeShape, x, y, θ) = CompositeShape(transform.(cs.shapes, x, y, θ))

"""
    extrude(shape, x, y, θ)
"""
extrude(p::Point, x, y, θ) = Line(p, transform(p, x, y, θ))

function extrude(l1::Line{T}, x, y, θ) where T
    l2 = transform(l1, x, y, θ)
    p1, p2 = points(l1)
    p3, p4 = points(l2)
    l3 = Line(p1, p3)
    l4 = Line(p2, p4)
    return Polygon{4,T}([p1, p2, p3, p4], [l1, l2, l3, l4])
end

extrude(m::PolygonOrLines, x, y, θ) = CompositeShape(extrude.(m.lines, x, y, θ))
extrude(cs::CompositeShape, x, y, θ) = CompositeShape(extrude.(cs.shapes, x, y, θ))

# Poor man's extrusion
function extrude(c::Circle, x, y, θ; subsamples::Int = 4)
    dx = x / subsamples
    dy = y / subsamples
    dθ = θ / subsamples
    return CompositeShape([transform(c, dx*i, dy*i, dθ*i) for i in 0:subsamples])
end

"""
    intersects(shape1, shape2)
"""
intersects(p1::Point, p2::Point) = p1.x == p2.x && p1.y == p2.y
intersects(c1::Circle, c2::Circle) = sqrt((c2.x - c1.x)^2 + (c2.y - c1.y)^2) <= c1.r + c2.r
intersects(p::Point, c::Circle) = sqrt((c.x - p.x)^2 + (c.y - p.y)^2) <= c.r

intersects(l::Line, p::Point) = intersects(p, l)

# We need this custom operator to handle parallel lines and point-line
# intersection with infinite lines.
⋖(x, y) = (x == y == Inf || x == y == -Inf) ? x < y : x <= y

function intersects(p::Point, l::Line)
    a1 = (l.x2 - l.x1)
    a2 = (l.y2 - l.y1)
    b1 = (p.x - l.x1)
    b2 = (p.y - l.y1)

    d1 = b1 / a1
    d2 = b2 / a2

    # See above for the definition of the operator `⋖`
    a1 == b1 == 0 && return l.t_min ⋖ d2 ⋖ l.t_max
    a2 == b2 == 0 && return l.t_min ⋖ d1 ⋖ l.t_max

    return d1 === d2 && (l.t_min ⋖ d1 ⋖ l.t_max || l.t_min ⋖ d2 ⋖ l.t_max)
end

function intersects(l1::Line, l2::Line)
    # From https://en.wikipedia.org/wiki/Line%E2%80%93line_intersection
    t1 = (l1.x1 - l2.x1)*(l2.y1 - l2.y2) - (l1.y1 - l2.y1)*(l2.x1 - l2.x2)
    t2 = (l1.x1 - l2.x1)*(l1.y1 - l1.y2) - (l1.y1 - l2.y1)*(l1.x1 - l1.x2)
    d = (l1.x1 - l1.x2)*(l2.y1 - l2.y2) - (l1.y1 - l1.y2)*(l2.x1 - l2.x2)

    # Parallel lines
    if iszero(d)
        return intersects(l1, Point(l2.x1, l2.y1)) || intersects(l1, Point(l2.x2, l2.y2)) ||
            intersects(l2, Point(l1.x1, l1.y1)) || intersects(l2, Point(l1.x2, l1.y2))
    end

    # See above for the definition of the operator `⋖`
    return l1.t_min ⋖ t1/d ⋖ l1.t_max && l2.t_min ⋖ t2/d ⋖ l2.t_max
end

intersects(c::Circle, l::Line) = intersects(l, c)
function intersects(l::Line, c::Circle)
    # From https://en.wikipedia.org/wiki/Line%E2%80%93sphere_intersection
    l² = (l.x2 - l.x1)^2 + (l.y2 - l.y1)^2
    a = ((l.x2 - l.x1)*(l.x1 - c.x) + (l.y2 - l.y1)*(l.y1 - c.y))
    b = (l.x1 - c.x)^2 + (l.y1 - c.y)^2 - c.r^2

    a^2 - l²*b < 0 && return false

    d1 = (-a + sqrt(a^2 - l²*b)) / l²
    d2 = (-a - sqrt(a^2 - l²*b)) / l²

    return l.t_min <= d1 <= l.t_max || l.t_min <= d2 <= l.t_max
end

intersects(m::PolygonOrLines, a::Union{<:Point,<:Line,<:Circle}) = intersects(a, m)
intersects(cs::CompositeShape, a::Union{<:Point,<:Line,<:Circle}) = intersects(a, cs)
intersects(a::Union{<:Point,<:Line,<:Circle}, m::PolygonOrLines) = any(l->intersects(a, l), m.lines)
intersects(a::Union{<:Point,<:Line,<:Circle}, cs::CompositeShape) = any(s->intersects(a, s), cs.shapes)

intersects(m1::PolygonOrLines, m2::PolygonOrLines) = any(l->intersects(l, m2), m1.lines)
intersects(m::PolygonOrLines, cs::CompositeShape) = any(l->intersects(l, cs), m.lines)
intersects(cs::CompositeShape, m::PolygonOrLines) = intersects(m, cs)
intersects(cs1::CompositeShape, cs2::CompositeShape) = any(s->intersects(s, cs2), cs1.shapes)

"""
    inside(shape1, shape2, θ)

Determine if `shape2` is inside `shape1`, using a rays from each point
at an angle `θ`.  A shape is determined to be inside if either:

 * the two shapes intersect, or;

 * a ray starting at one of the vertices of `shape2` intersects
   `shape1` an odd number of times.

"""
inside(p1::Point, p2::Point, θ) = intersects(p1, Line(p2.x, p2.y, θ; t_min=-Inf, t_max=0.))
inside(l::Line, p::Point, θ) = intersects(l, Line(p.x, p.y, θ; t_min=-Inf, t_max=0.))

function inside(m::PolygonOrLines, p::Point, θ)
    ray = Line(p.x, p.y, θ, t_min=-Inf, t_max=0.)
    count = 0
    for line in m.lines
        count += intersects(line, ray) ? 1 : 0
    end
    return isodd(count)
end

function inside(c::Circle, p::Point, θ)
    l = Line(p.x, p.y, θ; t_min=-Inf, t_max=0.)

    a = ((l.x2 - l.x1)*(l.x1 - c.x) + (l.y2 - l.y1)*(l.y1 - c.y))
    b = (l.x1 - c.x)^2 + (l.y1 - c.y)^2 - c.r^2

    a^2 < b && return false

    d1 = (-a + sqrt(a^2 - b))
    d2 = (-a - sqrt(a^2 - b))

    return (l.t_min <= d1 <= l.t_max) ⊻ (l.t_min <= d2 <= l.t_max)
end

inside(cs::CompositeShape, p::Point, θ) = any(x->inside(x, p, θ), cs.shapes)

inside(p::Point, l::Line, θ) = inside(l, p, θ)
inside(l1::Line, l2::Line, θ) = any(x->inside(l1, x, θ), points(l2)) || any(x->inside(l2, x, θ), points(l1)) || intersects(l1, l2)
inside(c::Circle, l::Line, θ) = any(x->inside(c, x, θ), points(l)) || intersects(c, l)
inside(m::PolygonOrLines, l::Line, θ) = any(x->inside(m, x, θ), points(l)) || intersects(m, l)
inside(cs::CompositeShape, l::Line, θ) = any(x->inside(cs, x, θ), points(l)) || intersects(cs, l)

inside(p::Point, c::Circle, θ) = inside(c, p, θ)
inside(l::Line, c::Circle, θ) = inside(c, l, θ)
inside(c1::Circle, c2::Circle, θ) = any(x->inside(c1, x, θ), points(c2)) || intersects(c1, c2)
inside(m::PolygonOrLines, c::Circle, θ) = any(x->inside(m, x, θ), points(c)) || any(x->inside(c, x, θ), points(m)) || intersects(m, c)
inside(cs::CompositeShape, c::Circle, θ) = any(x->inside(cs, x, θ), points(c)) || intersects(cs, c)

inside(p::Point, m::PolygonOrLines, θ) = inside(m, p, θ)
inside(l::Line, m::PolygonOrLines, θ) = inside(m, l, θ)
inside(c::Circle, m::PolygonOrLines, θ) = inside(m, c, θ)
inside(m1::PolygonOrLines, m2::PolygonOrLines, θ) = any(x->inside(m1, x, θ), points(m2)) || any(x->inside(m2, x, θ), points(m1)) || intersects(m1, m2)
inside(cs::CompositeShape, m::PolygonOrLines, θ) = any(x->inside(cs, x, θ), points(m)) || intersects(cs, m)

inside(p::Point, cs::CompositeShape, θ) = inside(cs, p, θ)
inside(l::Line, cs::CompositeShape, θ) = inside(cs, l, θ)
inside(c::Circle, cs::CompositeShape, θ) = inside(cs, c, θ)
inside(m::PolygonOrLines, cs::CompositeShape, θ) = inside(cs, m, θ)
inside(cs1::CompositeShape, cs2::CompositeShape, θ) = any(x->inside(cs1, x, θ), points(cs2)) || intersects(cs1, cs2)