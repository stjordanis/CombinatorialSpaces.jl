""" Simplicial sets in one, two, and three dimensions.

For the time being, this module provides data structures only for
*semi*-simplicial sets, which include the face maps but not the degeneracy maps.
In the future we may add support for simplicial sets having both face and
degeneracy maps. The analogy to keep in mind is that graphs are to
semi-simpicial sets as reflexive graphs are to simplicial sets.

Simplicial sets are inherently ordered structures. The "unordered" version of
simplicial sets are symmetric simplicial sets, sometimes called just "symmetric
sets." In one dimension, symmetric semi-simplicial sets are symmetric graphs.

This module does not *directly* implement symmetric simplicial sets. However,
they can be simulated with simplicial sets by enforcing that the ordering of the
vertices of each face matches the ordering of the integer vertex IDs. The
simplicial set then "presents" a symmetric simplicial set in a canonical way.
The functions [`add_sorted_edge!`](@ref) and [`glue_sorted_triangle!`](@ref)
automatically sort their inputs to ensure that the ordering condition is
satisfied.
"""
module SimplicialSets
export AbstractSemiSimplicialSet1D, SemiSimplicialSet1D,
  ∂₁, src, tgt, nv, ne, vertices, edges, has_vertex, has_edge,
  add_vertex!, add_vertices!, add_edge!, add_edges!,
  add_sorted_edge!, add_sorted_edges!,
  AbstractSemiSimplicialSet2D, SemiSimplicialSet2D,
  ∂₂, triangle_vertex, ntriangles, triangles,
  add_triangle!, glue_triangle!, glue_sorted_triangle!

using StaticArrays: SVector

using Catlab, Catlab.CategoricalAlgebra.CSets, Catlab.Graphs
using Catlab.Graphs.BasicGraphs: TheoryGraph, TheoryReflexiveGraph

# 1D simplicial sets
####################

const SemiSimplexCategory1D = TheoryGraph
const SimplexCategory1D = TheoryReflexiveGraph

""" Abstract type for 1D semi-simplicial sets.
"""
const AbstractSemiSimplicialSet1D = AbstractGraph

""" A 1D semi-simplicial set.

One-dimensional semi-simplicial sets are the same as graphs, and this type is
just an alias for `Graph`. The boundary operator [`∂₁`](@ref) translates the
graph-theoretic terminology into simplicial terminology.
"""
const SemiSimplicialSet1D = Graph

""" Boundary operator on edges or 1-chains in simplicial set.
"""
@inline ∂₁(s::AbstractACSet, i::Int, args...) =
  ∂₁(s::AbstractACSet, Val{i}, args...)

∂₁(s::AbstractACSet, ::Type{Val{0}}, args...) = s[args..., :tgt]
∂₁(s::AbstractACSet, ::Type{Val{1}}, args...) = s[args..., :src]

""" Add edge to simplicial set, respecting the order of the vertex IDs.
"""
add_sorted_edge!(s::AbstractACSet, v₀::Int, v₁::Int; kw...) =
  add_edge!(s, min(v₀, v₁), max(v₀, v₁); kw...)

""" Add edges to simplicial set, respecting the order of the vertex IDs.
"""
function add_sorted_edges!(s::AbstractACSet, vs₀::AbstractVector{Int},
                           vs₁::AbstractVector{Int}; kw...)
  add_edges!(s, min.(vs₀, vs₁), max.(vs₀, vs₁); kw...)
end

# 2D simplicial sets
####################

@present SemiSimplexCategory2D <: SemiSimplexCategory1D begin
  Tri::Ob
  src2_first::Hom(Tri,E) # ∂₂(2)
  src2_last::Hom(Tri,E)  # ∂₂(0)
  tgt2::Hom(Tri,E)       # ∂₂(1)

  # Simplicial identities.
  # ∂₂(1) ⋅ ∂₁(1) == ∂₂(2) ⋅ ∂₁(1)
  compose(tgt2, src) == compose(src2_first, src) # == v₀
  # ∂₂(0) ⋅ ∂₁(1) == ∂₂(2) ⋅ ∂₁(0)
  compose(src2_last, src) == compose(src2_first, tgt) # == v₁
  # ∂₂(0) ⋅ ∂₁(0) == ∂₂(1) ⋅ ∂₁(0)
  compose(src2_last, tgt) == compose(tgt2, tgt) # == v₂
end

""" Abstract type for 2D semi-simplicial sets.
"""
const AbstractSemiSimplicialSet2D = AbstractACSetType(SemiSimplexCategory2D)

""" A 2D semi-simplicial set.
"""
const SemiSimplicialSet2D = CSetType(SemiSimplexCategory2D,
  index=[:src, :tgt, :src2_first, :src2_last, :tgt2])

""" Boundary operator on triangles or 2-chains in simplicial set.
"""
@inline ∂₂(s::AbstractACSet, i::Int, args...) =
  ∂₂(s::AbstractACSet, Val{i}, args...)

∂₂(s::AbstractACSet, ::Type{Val{0}}, args...) = s[args..., :src2_last]
∂₂(s::AbstractACSet, ::Type{Val{1}}, args...) = s[args..., :tgt2]
∂₂(s::AbstractACSet, ::Type{Val{2}}, args...) = s[args..., :src2_first]

triangles(s::AbstractACSet) = parts(s, :Tri)
ntriangles(s::AbstractACSet) = nparts(s, :Tri)

""" Boundary vertex of a triangle.

This accessor assumes that the simplicial identities hold.
"""
@inline triangle_vertex(s::AbstractACSet, i::Int, args...) =
  triangle_vertex(s, Val{i}, args...)

triangle_vertex(s::AbstractACSet, ::Type{Val{0}}, args...) =
  s[s[args..., :tgt2], :src]
triangle_vertex(s::AbstractACSet, ::Type{Val{1}}, args...) =
  s[s[args..., :src2_first], :tgt]
triangle_vertex(s::AbstractACSet, ::Type{Val{2}}, args...) =
  s[s[args..., :tgt2], :tgt]

""" Add a triangle (2-simplex) to a simplicial set, given its boundary edges.

!!! warning

    This low-level function does not check the simplicial identities. It is your
    responsibility to ensure they are satisfied. By contrast, triangles added
    using the function [`glue_triangle!`](@ref) always satisfy the simplicial
    identities, by the nature of the construction.
"""
add_triangle!(s::AbstractACSet, src2_1::Int, src2_2::Int, tgt2::Int; kw...) =
  add_part!(s, :Tri; src2_first=src2_1, src2_last=src2_2, tgt2=tgt2, kw...)

""" Glue a triangle onto a simplicial set, given its boundary vertices.

If a needed edge between two vertices exists, it is reused (hence the "gluing");
otherwise, it is created.
"""
function glue_triangle!(s::AbstractACSet, v₀::Int, v₁::Int, v₂::Int; kw...)
  add_triangle!(s, get_edge!(s, v₀, v₁), get_edge!(s, v₁, v₂),
                get_edge!(s, v₀, v₂); kw...)
end

function get_edge!(s::AbstractACSet, src::Int, tgt::Int)
  es = edges(s, src, tgt)
  isempty(es) ? add_edge!(s, src, tgt) : first(es)
end

""" Glue a triangle onto a simplicial set, respecting the order of the vertices.
"""
function glue_sorted_triangle!(s::AbstractACSet, v₀::Int, v₁::Int, v₂::Int; kw...)
  v₀, v₁, v₂ = sort(SVector(v₀, v₁, v₂))
  glue_triangle!(s, v₀, v₁, v₂; kw...)
end

end
