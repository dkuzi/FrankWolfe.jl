using FrankWolfe
using LinearAlgebra
using Random
import GLPK

include("../examples/plot_utils.jl")

# s = rand(1:100)
s = 98
@info "Seed $s"
Random.seed!(s)

n = Int(1e2)
k = 3000

xpi = rand(n, n)
# total = sum(xpi)
const xp = xpi # / total
const normxp2 = dot(xp, xp)

# better for memory consumption as we do coordinate-wise ops

function cf(x, xp, normxp2)
    return (normxp2 - 2dot(x, xp) + dot(x, x)) / n^2
end

function cgrad!(storage, x, xp)
    return @. storage = 2 * (x - xp) / n^2
end

# BirkhoffPolytopeLMO via Hungarian Method
lmo_native = FrankWolfe.BirkhoffPolytopeLMO()

# BirkhoffPolytopeLMO realized via LP solver
lmo_moi = FrankWolfe.convert_mathopt(lmo_native, GLPK.Optimizer(), dimension=n)

# choose between lmo_native (= Hungarian Method) and lmo_moi (= LP formulation solved with GLPK)
lmo = lmo_native

# initial direction for first vertex
direction_mat = randn(n, n)
x0 = FrankWolfe.compute_extreme_point(lmo, direction_mat)

FrankWolfe.benchmark_oracles(
    x -> cf(x, xp, normxp2),
    (str, x) -> cgrad!(str, x, xp),
    () -> randn(n, n),
    lmo;
    k=100,
)

# BCG run
@time x, v, primal, dual_gap, trajectoryBCG, _ = FrankWolfe.blended_conditional_gradient(
    x -> cf(x, xp, normxp2),
    (str, x) -> cgrad!(str, x, xp),
    lmo,
    x0;
    max_iteration=k,
    line_search=FrankWolfe.Shortstep(2/n^2),
    print_iter=k / 10,
    memory_mode=FrankWolfe.InplaceEmphasis(),
    trajectory=true,
    verbose=true,
)

data = [trajectoryBCG]
label = ["BCG"]

plot_trajectories(data, label, reduce_size=true, marker_shapes=[:dtriangle])
