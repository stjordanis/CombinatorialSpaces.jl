""" Simplicial sets in one, two, and three dimensions.

For the time being, this module provides data structures only for [delta
sets](https://en.wikipedia.org/wiki/Delta_set), also known as [semi-simplicial
sets](https://ncatlab.org/nlab/show/semi-simplicial+set). These include the face
maps but not the degeneracy maps of a simplicial set. In the future we may add
support for simplicial sets. The analogy to keep in mind is that graphs are to
semi-simpicial sets as reflexive graphs are to simplicial sets.

Also provided are the fundamental operators on simplicial sets used in nearly
all geometric applications, namely the boundary and coboundary (discrete
exterior derivative) operators. For additional operators, see the
`DiscreteExteriorCalculus` module.
"""
module SimplicialSets
export Simplex, V, E, Tri, SimplexChain, VChain, EChain, TriChain,
  SimplexForm, VForm, EForm, TriForm, HasDeltaSet,
  HasDeltaSet1D, AbstractDeltaSet1D, DeltaSet1D, SchDeltaSet1D,
  OrientedDeltaSet1D, SchOrientedDeltaSet1D,
  EmbeddedDeltaSet1D, SchEmbeddedDeltaSet1D,
  HasDeltaSet2D, AbstractDeltaSet2D, DeltaSet2D, SchDeltaSet2D,
  OrientedDeltaSet2D, SchOrientedDeltaSet2D,
  EmbeddedDeltaSet2D, SchEmbeddedDeltaSet2D,
  ∂, boundary, coface, d, coboundary, exterior_derivative,
  simplices, nsimplices, point, volume,
  orientation, set_orientation!, orient!, orient_component!,
  src, tgt, nv, ne, vertices, edges, has_vertex, has_edge, edge_vertices,
  add_vertex!, add_vertices!, add_edge!, add_edges!,
  add_sorted_edge!, add_sorted_edges!,
  triangle_edges, triangle_vertices, ntriangles, triangles,
  add_triangle!, glue_triangle!, glue_sorted_triangle!

using LinearAlgebra: det
using SparseArrays
using StaticArrays: @SVector, SVector, SMatrix

using Catlab, Catlab.CategoricalAlgebra, Catlab.Graphs
import Catlab.Graphs: src, tgt, nv, ne, vertices, edges, has_vertex, has_edge,
  add_vertex!, add_vertices!, add_edge!, add_edges!
using ..ArrayUtils

# 0-D simplicial sets
#####################

@present SchDeltaSet0D(FreeSchema) begin
  V::Ob
end

""" Abstract type for C-sets that contain a delta set of some dimension.

This dimension could be zero, in which case the delta set consists only of
vertices (0-simplices).
"""
@abstract_acset_type HasDeltaSet

vertices(s::HasDeltaSet) = parts(s, :V)
nv(s::HasDeltaSet) = nparts(s, :V)
nsimplices(::Type{Val{0}}, s::HasDeltaSet) = nv(s)

has_vertex(s::HasDeltaSet, v) = has_part(s, :V, v)
add_vertex!(s::HasDeltaSet; kw...) = add_part!(s, :V; kw...)
add_vertices!(s::HasDeltaSet, n::Int; kw...) = add_parts!(s, :V, n; kw...)

# 1D simplicial sets
####################

@present SchDeltaSet1D <: SchDeltaSet0D begin
  E::Ob
  (∂v0, ∂v1)::Hom(E, V) # (∂₁(0), ∂₁(1))
end

""" Abstract type for C-sets that contain a one-dimensional delta set.
"""
@abstract_acset_type HasDeltaSet1D <: HasDeltaSet

""" Abstract type for one-dimensional delta sets, aka semi-simplicial sets.
"""
@abstract_acset_type AbstractDeltaSet1D <: HasDeltaSet1D

""" A one-dimensional delta set, aka semi-simplicial set.

Delta sets in 1D are isomorphic to graphs (in the category theorist's sense).
The source and target of an edge can be accessed using the face maps [`∂`](@ref)
(simplicial terminology) or `src` and `tgt` maps (graph-theoretic terminology).
More generally, this type implements the graphs interface in `Catlab.Graphs`.
"""
@acset_type DeltaSet1D(SchDeltaSet1D, index=[:∂v0,:∂v1]) <: AbstractDeltaSet1D

edges(s::HasDeltaSet1D) = parts(s, :E)
edges(s::HasDeltaSet1D, src::Int, tgt::Int) =
  (e for e in coface(1,1,s,src) if ∂(1,0,s,e) == tgt)

ne(s::HasDeltaSet1D) = nparts(s, :E)
nsimplices(::Type{Val{1}}, s::HasDeltaSet1D) = ne(s)

has_edge(s::HasDeltaSet1D, e) = has_part(s, :E, e)
has_edge(s::HasDeltaSet1D, src::Int, tgt::Int) =
  has_vertex(s, src) && any(e -> ∂(1,0,s,e) == tgt, coface(1,1,s,src))

src(s::HasDeltaSet1D, args...) = subpart(s, args..., :∂v1)
tgt(s::HasDeltaSet1D, args...) = subpart(s, args..., :∂v0)
face(::Type{Val{(1,0)}}, s::HasDeltaSet1D, args...) = subpart(s, args..., :∂v0)
face(::Type{Val{(1,1)}}, s::HasDeltaSet1D, args...) = subpart(s, args..., :∂v1)

coface(::Type{Val{(1,0)}}, s::HasDeltaSet1D, args...) = incident(s, args..., :∂v0)
coface(::Type{Val{(1,1)}}, s::HasDeltaSet1D, args...) = incident(s, args..., :∂v1)

""" Boundary vertices of an edge.
"""
edge_vertices(s::HasDeltaSet1D, e...) = SVector(∂(1,0,s,e...), ∂(1,1,s,e...))

add_edge!(s::HasDeltaSet1D, src::Int, tgt::Int; kw...) =
  add_part!(s, :E; ∂v1=src, ∂v0=tgt, kw...)

function add_edges!(s::HasDeltaSet1D, srcs::AbstractVector{Int},
                    tgts::AbstractVector{Int}; kw...)
  @assert (n = length(srcs)) == length(tgts)
  add_parts!(s, :E, n; ∂v1=srcs, ∂v0=tgts, kw...)
end

""" Add edge to simplicial set, respecting the order of the vertex IDs.
"""
add_sorted_edge!(s::HasDeltaSet1D, v₀::Int, v₁::Int; kw...) =
  add_edge!(s, min(v₀, v₁), max(v₀, v₁); kw...)

""" Add edges to simplicial set, respecting the order of the vertex IDs.
"""
function add_sorted_edges!(s::HasDeltaSet1D, vs₀::AbstractVector{Int},
                           vs₁::AbstractVector{Int}; kw...)
  add_edges!(s, min.(vs₀, vs₁), max.(vs₀, vs₁); kw...)
end

# 1D oriented simplicial sets
#----------------------------

@present SchOrientedDeltaSet1D <: SchDeltaSet1D begin
  Orientation::AttrType
  edge_orientation::Attr(E,Orientation)
end

""" A one-dimensional oriented delta set.

Edges are oriented from source to target when `edge_orientation` is
true/positive and from target to source when it is false/negative.
"""
@acset_type OrientedDeltaSet1D(SchOrientedDeltaSet1D,
                               index=[:∂v0,:∂v1]) <: AbstractDeltaSet1D

orientation(::Type{Val{1}}, s::HasDeltaSet1D, args...) =
  s[args..., :edge_orientation]
set_orientation!(::Type{Val{1}}, s::HasDeltaSet1D, e, orientation) =
  (s[e, :edge_orientation] = orientation)

function ∂_nz(::Type{Val{1}}, s::HasDeltaSet1D, e::Int)
  (edge_vertices(s, e), sign(1,s,e) * @SVector([1,-1]))
end

function d_nz(::Type{Val{0}}, s::HasDeltaSet1D, v::Int)
  e₀, e₁ = coface(1,0,s,v), coface(1,1,s,v)
  (lazy(vcat, e₀, e₁), lazy(vcat, sign(1,s,e₀), -sign(1,s,e₁)))
end

# 1D embedded simplicial sets
#----------------------------

@present SchEmbeddedDeltaSet1D <: SchOrientedDeltaSet1D begin
  Point::AttrType
  point::Attr(V, Point)
end

""" A one-dimensional, embedded, oriented delta set.
"""
@acset_type EmbeddedDeltaSet1D(SchEmbeddedDeltaSet1D,
                               index=[:∂v0,:∂v1]) <: AbstractDeltaSet1D

""" Point associated with vertex of complex.
"""
point(s::HasDeltaSet, args...) = s[args..., :point]

struct CayleyMengerDet end

volume(::Type{Val{n}}, s::EmbeddedDeltaSet1D, x) where n =
  volume(Val{n}, s, x, CayleyMengerDet())
volume(::Type{Val{1}}, s::HasDeltaSet1D, e::Int, ::CayleyMengerDet) =
  volume(point(s, edge_vertices(s, e)))

# 2D simplicial sets
####################

@present SchDeltaSet2D <: SchDeltaSet1D begin
  Tri::Ob
  (∂e0, ∂e1, ∂e2)::Hom(Tri,E) # (∂₂(0), ∂₂(1), ∂₂(2))

  # Simplicial identities.
  ∂e1 ⋅ ∂v1 == ∂e2 ⋅ ∂v1 # ∂₂(1) ⋅ ∂₁(1) == ∂₂(2) ⋅ ∂₁(1) == v₀
  ∂e0 ⋅ ∂v1 == ∂e2 ⋅ ∂v0 # ∂₂(0) ⋅ ∂₁(1) == ∂₂(2) ⋅ ∂₁(0) == v₁
  ∂e0 ⋅ ∂v0 == ∂e1 ⋅ ∂v0 # ∂₂(0) ⋅ ∂₁(0) == ∂₂(1) ⋅ ∂₁(0) == v₂
end

""" Abstract type for C-sets containing a 2D delta set.
"""
@abstract_acset_type HasDeltaSet2D <: HasDeltaSet1D

""" Abstract type for 2D delta sets.
"""
@abstract_acset_type AbstractDeltaSet2D <: HasDeltaSet2D

""" A 2D delta set, aka semi-simplicial set.

The triangles in a semi-simpicial set can be interpreted in several ways.
Geometrically, they are triangles (2-simplices) whose three edges are directed
according to a specific pattern, determined by the ordering of the vertices or
equivalently by the simplicial identities. This geometric perspective is present
through the subpart names `∂e0`, `∂e1`, and `∂e2` and through the boundary map
[`∂`](@ref). Alternatively, the triangle can be interpreted as a
higher-dimensional link or morphism, going from two edges in sequence (which
might be called `src2_first` and `src2_last`) to a transitive edge (say `tgt2`).
This is the shape of the binary composition operation in a category.
"""
@acset_type DeltaSet2D(SchDeltaSet2D,
                       index=[:∂v0,:∂v1,:∂e0,:∂e1,:∂e2]) <: AbstractDeltaSet2D

triangles(s::HasDeltaSet2D) = parts(s, :Tri)
ntriangles(s::HasDeltaSet2D) = nparts(s, :Tri)
nsimplices(::Type{Val{2}}, s::HasDeltaSet2D) = ntriangles(s)

face(::Type{Val{(2,0)}}, s::HasDeltaSet2D, args...) = subpart(s, args..., :∂e0)
face(::Type{Val{(2,1)}}, s::HasDeltaSet2D, args...) = subpart(s, args..., :∂e1)
face(::Type{Val{(2,2)}}, s::HasDeltaSet2D, args...) = subpart(s, args..., :∂e2)

coface(::Type{Val{(2,0)}}, s::HasDeltaSet2D, args...) = incident(s, args..., :∂e0)
coface(::Type{Val{(2,1)}}, s::HasDeltaSet2D, args...) = incident(s, args..., :∂e1)
coface(::Type{Val{(2,2)}}, s::HasDeltaSet2D, args...) = incident(s, args..., :∂e2)

""" Boundary edges of a triangle.
"""
function triangle_edges(s::HasDeltaSet2D, t...)
  SVector(∂(2,0,s,t...), ∂(2,1,s,t...), ∂(2,2,s,t...))
end

""" Boundary vertices of a triangle.

This accessor assumes that the simplicial identities hold.
"""
function triangle_vertices(s::HasDeltaSet2D, t...)
  SVector(s[s[t..., :∂e1], :∂v1],
          s[s[t..., :∂e2], :∂v0],
          s[s[t..., :∂e1], :∂v0])
end

""" Add a triangle (2-simplex) to a simplicial set, given its boundary edges.

In the arguments to this function, the boundary edges have the order ``0 → 1``,
``1 → 2``, ``0 → 2``.

!!! warning

    This low-level function does not check the simplicial identities. It is your
    responsibility to ensure they are satisfied. By contrast, triangles added
    using the function [`glue_triangle!`](@ref) always satisfy the simplicial
    identities, by construction. Thus it is often easier to use this function.
"""
add_triangle!(s::HasDeltaSet2D, src2_first::Int, src2_last::Int, tgt2::Int; kw...) =
  add_part!(s, :Tri; ∂e0=src2_last, ∂e1=tgt2, ∂e2=src2_first, kw...)

""" Glue a triangle onto a simplicial set, given its boundary vertices.

If a needed edge between two vertices exists, it is reused (hence the "gluing");
otherwise, it is created.
"""
function glue_triangle!(s::HasDeltaSet2D, v₀::Int, v₁::Int, v₂::Int; kw...)
  add_triangle!(s, get_edge!(s, v₀, v₁), get_edge!(s, v₁, v₂),
                get_edge!(s, v₀, v₂); kw...)
end

function get_edge!(s::HasDeltaSet1D, src::Int, tgt::Int)
  es = edges(s, src, tgt)
  isempty(es) ? add_edge!(s, src, tgt) : first(es)
end

""" Glue a triangle onto a simplicial set, respecting the order of the vertices.
"""
function glue_sorted_triangle!(s::HasDeltaSet2D, v₀::Int, v₁::Int, v₂::Int; kw...)
  v₀, v₁, v₂ = sort(SVector(v₀, v₁, v₂))
  glue_triangle!(s, v₀, v₁, v₂; kw...)
end

# 2D oriented simplicial sets
#----------------------------

@present SchOrientedDeltaSet2D <: SchDeltaSet2D begin
  Orientation::AttrType
  edge_orientation::Attr(E,Orientation)
  tri_orientation::Attr(Tri,Orientation)
end

""" A two-dimensional oriented delta set.

Triangles are ordered in the cyclic order ``(0,1,2)`` when `tri_orientation` is
true/positive and in the reverse order when it is false/negative.
"""
@acset_type OrientedDeltaSet2D(SchOrientedDeltaSet2D,
                               index=[:∂v0,:∂v1,:∂e0,:∂e1,:∂e2]) <: AbstractDeltaSet2D

orientation(::Type{Val{2}}, s::HasDeltaSet2D, args...) =
  s[args..., :tri_orientation]
set_orientation!(::Type{Val{2}}, s::HasDeltaSet2D, t, orientation) =
  (s[t, :tri_orientation] = orientation)

function ∂_nz(::Type{Val{2}}, s::HasDeltaSet2D, t::Int)
  edges = triangle_edges(s,t)
  (edges, sign(2,s,t) * sign(1,s,edges) .* @SVector([1,-1,1]))
end

function d_nz(::Type{Val{1}}, s::HasDeltaSet2D, e::Int)
  sgn = sign(1, s, e)
  t₀, t₁, t₂ = coface(2,0,s,e), coface(2,1,s,e), coface(2,2,s,e)
  (lazy(vcat, t₀, t₁, t₂),
   lazy(vcat, sgn*sign(2,s,t₀), -sgn*sign(2,s,t₁), sgn*sign(2,s,t₂)))
end

# 2D embedded simplicial sets
#----------------------------

@present SchEmbeddedDeltaSet2D <: SchOrientedDeltaSet2D begin
  Point::AttrType
  point::Attr(V, Point)
end

""" A two-dimensional, embedded, oriented delta set.
"""
@acset_type EmbeddedDeltaSet2D(SchEmbeddedDeltaSet2D,
                               index=[:∂v0,:∂v1,:∂e0,:∂e1,:∂e2]) <: AbstractDeltaSet2D

volume(::Type{Val{n}}, s::EmbeddedDeltaSet2D, x) where n =
  volume(Val{n}, s, x, CayleyMengerDet())
volume(::Type{Val{2}}, s::HasDeltaSet2D, t::Int, ::CayleyMengerDet) =
  volume(point(s, triangle_vertices(s,t)))

# General operators
###################

""" Wrapper for simplex or simplices of dimension `n`.

See also: [`V`](@ref), [`E`](@ref), [`Tri`](@ref).
"""
@parts_array_struct Simplex{n}

""" Vertex in simplicial set: alias for `Simplex{0}`.
"""
const V = Simplex{0}

""" Edge in simplicial set: alias for `Simplex{1}`.
"""
const E = Simplex{1}

""" Triangle in simplicial set: alias for `Simplex{2}`.
"""
const Tri = Simplex{2}

""" Wrapper for chain of oriented simplices of dimension `n`.
"""
@vector_struct SimplexChain{n}

const VChain = SimplexChain{0}
const EChain = SimplexChain{1}
const TriChain = SimplexChain{2}

""" Wrapper for discrete form, aka cochain, in simplicial set.
"""
@vector_struct SimplexForm{n}

const VForm = SimplexForm{0}
const EForm = SimplexForm{1}
const TriForm = SimplexForm{2}

""" Simplices of given dimension in a simplicial set.
"""
@inline simplices(n::Int, s::HasDeltaSet) = 1:nsimplices(Val{n}, s)

""" Number of simplices of given dimension in a simplicial set.
"""
@inline nsimplices(n::Int, s::HasDeltaSet) = nsimplices(Val{n}, s)

""" Face map and boundary operator on simplicial sets.

Given numbers `n` and `0 <= i <= n` and a simplicial set of dimension at least
`n`, the `i`th face map is implemented by the call

```julia
∂(n, i, s, ...)
```

The boundary operator on `n`-faces and `n`-chains is implemented by the call

```julia
∂(n, s, ...)
```

Note that the face map returns *simplices*, while the boundary operator returns
*chains* (vectors in the free vector space spanned by oriented simplices).
"""
@inline ∂(i::Int, s::HasDeltaSet, x::Simplex{n}) where n =
  Simplex{n-1}(face(Val{(n,i)}, s, x.data))
@inline ∂(n::Int, i::Int, s::HasDeltaSet, args...) =
  face(Val{(n,i)}, s, args...)

@inline coface(i::Int, s::HasDeltaSet, x::Simplex{n}) where n =
  Simplex{n+1}(coface(Val{(n+1,i)}, s, x.data))
@inline coface(n::Int, i::Int, s::HasDeltaSet, args...) =
  coface(Val{(n,i)}, s, args...)

∂(s::HasDeltaSet, x::SimplexChain{n}) where n =
  SimplexChain{n-1}(∂(Val{n}, s, x.data))
@inline ∂(n::Int, s::HasDeltaSet, args...) = ∂(Val{n}, s, args...)

function ∂(::Type{Val{n}}, s::HasDeltaSet, args...) where n
  operator_nz(Int, nsimplices(n-1,s), nsimplices(n,s), args...) do x
    ∂_nz(Val{n}, s, x)
  end
end

""" Alias for the face map and boundary operator [`∂`](@ref).
"""
const boundary = ∂

""" The discrete exterior derivative, aka the coboundary operator.
"""
d(s::HasDeltaSet, x::SimplexForm{n}) where n =
  SimplexForm{n+1}(d(Val{n}, s, x.data))
@inline d(n::Int, s::HasDeltaSet, args...) = d(Val{n}, s, args...)

function d(::Type{Val{n}}, s::HasDeltaSet, args...) where n
  operator_nz(Int, nsimplices(n+1,s), nsimplices(n,s), args...) do x
    d_nz(Val{n}, s, x)
  end
end

""" Alias for the coboundary operator [`d`](@ref).
"""
const coboundary = d

""" Alias for the discrete exterior derivative [`d`](@ref).
"""
const exterior_derivative = d

""" Orientation of simplex.
"""
orientation(s::HasDeltaSet, x::Simplex{n}) where n =
  orientation(Val{n}, s, x.data)
@inline orientation(n::Int, s::HasDeltaSet, args...) =
  orientation(Val{n}, s, args...)

@inline Base.sign(n::Int, s::HasDeltaSet, args...) = sign(Val{n}, s, args...)
Base.sign(::Type{Val{n}}, s::HasDeltaSet, args...) where n =
  numeric_sign.(orientation(Val{n}, s, args...))

numeric_sign(x) = sign(x)
numeric_sign(x::Bool) = x ? +1 : -1

""" Set orientation of simplex.
"""
@inline set_orientation!(n::Int, s::HasDeltaSet, args...) =
  set_orientation!(Val{n}, s, args...)

""" ``n``-dimensional volume of ``n``-simplex in an embedded simplicial set.
"""
volume(s::HasDeltaSet, x::Simplex{n}, args...) where n =
  volume(Val{n}, s, x.data, args...)
@inline volume(n::Int, s::HasDeltaSet, args...) = volume(Val{n}, s, args...)

""" Convenience function for linear operator based on structural nonzero values.
"""
operator_nz(f, ::Type{T}, m::Int, n::Int,
            x::Int, Vec::Type=SparseVector{T}) where T = fromnz(Vec, f(x)..., m)
operator_nz(f, ::Type{T}, m::Int, n::Int,
            vec::AbstractVector) where T = applynz(f, vec, m, n)
operator_nz(f, ::Type{T}, m::Int, n::Int,
            Mat::Type=SparseMatrixCSC{T}) where T = fromnz(f, Mat, m, n)

# Consistent orientation
########################

""" Consistently orient simplices in a simplicial set, if possible.

Two simplices with a common face are *consistently oriented* if they induce
opposite orientations on the shared face. This function attempts to consistently
orient all simplices of a given dimension and returns whether this has been
achieved. Each connected component is oriently independently using the helper
function [`orient_component!`](@ref).
"""
orient!(s::AbstractDeltaSet1D) = orient!(s, E)
orient!(s::AbstractDeltaSet2D) = orient!(s, Tri)

function orient!(s::HasDeltaSet, ::Type{Simplex{n}}) where n
  # Compute connected components as coequalizer of face maps.
  ndom, ncodom = nsimplices(n, s), nsimplices(n-1, s)
  face_maps = SVector{n+1}([ FinFunction(x -> ∂(n,i,s,x), ndom, ncodom)
                             for i in 0:n ])
  π = only(coequalizer(face_maps))

  # Choose an arbitrary representative of each component.
  reps = zeros(Int, length(codom(π)))
  for x in reverse(simplices(n, s))
    reps[π(∂(n,0,s,x))] = x
  end

  # Orient each component, starting at the chosen representative.
  init_orientation = one(eltype(orientation(n, s)))
  for x in reps
    orient_component!(s, Simplex{n}(x), init_orientation) || return false
  end
  true
end

""" Consistently orient simplices in the same connected component, if possible.

Given an ``n``-simplex and a choice of orientation for it, this function
attempts to consistently orient all ``n``-simplices that may be reached from it
by traversing ``(n-1)``-faces. The traversal is depth-first. If a consistent
orientation is possible, the function returns `true` and the orientations are
assigned; otherwise, it returns `false` and no orientations are changed.

If the simplicial set is not connected, the function [`orient!`](@ref) may be
more convenient.
"""
orient_component!(s::AbstractDeltaSet1D, e::Int, args...) =
  orient_component!(s, E(e), args...)
orient_component!(s::AbstractDeltaSet2D, t::Int, args...) =
  orient_component!(s, Tri(t), args...)

function orient_component!(s::HasDeltaSet, x::Simplex{n},
                           x_orientation::Orientation) where {n, Orientation}
  orientations = repeat(Union{Orientation,Nothing}[nothing], nsimplices(n, s))

  orient_stack = Vector{Pair{Int64, Orientation}}()

  push!(orient_stack, x[] => x_orientation)
  is_orientable = true
  while !isempty(orient_stack)
    x, target = pop!(orient_stack)
    current = orientations[x]
    if isnothing(current)
      # If not visited, set the orientation and add neighbors to stack.
      orientations[x] = target
      for i in 0:n, j in 0:n
        next = iseven(i+j) ? negate(target) : target
        for y in coface(n, j, s, ∂(n, i, s, x))
          y == x || push!(orient_stack, y=>next)
        end
      end
    elseif current != target
      is_orientable = false
      break
    end
  end

  if is_orientable
    component = findall(!isnothing, orientations)
    set_orientation!(n, s, component, orientations[component])
  end
  is_orientable
end

negate(x) = -x
negate(x::Bool) = !x

# Euclidean geometry
####################

""" ``n``-dimensional volume of ``n``-simplex spanned by given ``n+1`` points.
"""
function volume(points)
  CM = cayley_menger(points...)
  n = length(points) - 1
  sqrt(abs(det(CM)) / 2^n) / factorial(n)
end

""" Construct Cayley-Menger matrix for simplex spanned by given points.

For an ``n`-simplex, this is the ``(n+2)×(n+2)`` matrix that appears in the
[Cayley-Menger
determinant](https://en.wikipedia.org/wiki/Cayley-Menger_determinant).
"""
function cayley_menger(p0::V, p1::V) where V <: AbstractVector
  d01 = sqdistance(p0, p1)
  SMatrix{3,3}(0,  1,   1,
               1,  0,   d01,
               1,  d01, 0)
end
function cayley_menger(p0::V, p1::V, p2::V) where V <: AbstractVector
  d01, d12, d02 = sqdistance(p0, p1), sqdistance(p1, p2), sqdistance(p0, p2)
  SMatrix{4,4}(0,  1,   1,   1,
               1,  0,   d01, d02,
               1,  d01, 0,   d12,
               1,  d02, d12, 0)
end
function cayley_menger(p0::V, p1::V, p2::V, p3::V) where V <: AbstractVector
  d01, d12, d02 = sqdistance(p0, p1), sqdistance(p1, p2), sqdistance(p0, p2)
  d03, d13, d23 = sqdistance(p0, p3), sqdistance(p1, p3), sqdistance(p2, p3)
  SMatrix{5,5}(0,  1,   1,   1,   1,
               1,  0,   d01, d02, d03,
               1,  d01, 0,   d12, d13,
               1,  d02, d12, 0,   d23,
               1,  d03, d13, d23, 0)
end

""" Squared Euclidean distance between two points.
"""
sqdistance(x, y) = sum((x-y).^2)

end
