export PowerConstraint, conic_form!, vexity

### (Primal) power cone constraint PowerConstraint(x,y,z,a) => x^a y^(1-a) >= |z|, x>=0, y>=0
type PowerConstraint <: Constraint
  head::Symbol
  id_hash::Uint64
  children::@compat Tuple{AbstractExpr, AbstractExpr, AbstractExpr, Number} # (x, y, z, a)
  size::@compat Tuple{Int, Int}
  dual::ValueOrNothing

  function PowerConstraint(x::AbstractExpr, y::AbstractExpr, z::AbstractExpr, a::Number)
    @assert(x.size == y.size == z.size,
           "Power constraint requires x, y, and z to be the same size")
    sz = x.size
    id_hash = hash((x, y, z, a, :power))
    return new(:power, id_hash, (x, y, z, a), sz, nothing)
  end
end

PowerConstraint(x::AbstractExpr, y, z::AbstractExpr, a::Number) = PowerConstraint(x, Constant(y), z, a::Number)
PowerConstraint(x::AbstractExpr, y::AbstractExpr, z, a::Number) = PowerConstraint(x, y, Constant(z), a::Number)
PowerConstraint(x, y::AbstractExpr, z::AbstractExpr, a::Number) = PowerConstraint(Constant(x), y, z, a::Number)

function vexity(c::PowerConstraint)
  # TODO: these might be too strict
  if vexity(c.x) != ConstantVexity() && vexity(c.x) != AffineVexity()
    error("Power constraint requires x to be affine")
  end
  if vexity(c.y) != ConstantVexity() && vexity(c.y) != AffineVexity()
    error("Power constraint requires y to be affine")
  end
  if vexity(c.z) != ConstantVexity() && vexity(c.z) != AffineVexity()
    error("Power constraint requires z to be affine")
  end
  return ConvexVexity()
end

# TODO: how to encode `a` into ConicConstr form? make it consistent with MathProgBase
function conic_form!(c::PowerConstraint, unique_conic_forms::UniqueConicForms)
  if !has_conic_form(unique_conic_forms, c)
    conic_constrs = ConicConstr[]
    if c.size == (1, 1)
      objectives = Array(ConicObj, 3)
      for iobj=1:3
        objectives[iobj] = conic_form!(c.children[iobj], unique_conic_forms)
      end
      push!(conic_constrs, ConicConstr(objectives, :Power, [1, 1, 1]))
    else
      for i=1:c.size[1]
        for j=1:c.size[2]
          objectives = Array(ConicObj, 3)
          for iobj=1:3
            objectives[iobj] = conic_form!(c.children[iobj][i,j], unique_conic_forms)
          end
          push!(conic_constrs, ConicConstr(objectives, :Power, [1, 1, 1]))
        end
      end
    end
    cache_conic_form!(unique_conic_forms, c, conic_constrs)
  end
  return get_conic_form(unique_conic_forms, c)
end
