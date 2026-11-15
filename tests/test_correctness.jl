using Test

include("../src/structures.jl")
include("../src/algorithm/baseline.jl")
include("../src/utils.jl")

using .Structures
using .Utils
using .BaselineEclat

@testset "Eclat Baseline vs SPMF Correctness" begin
    vertical_db, num_tx = load_vertical_db("data/toy/sample1.txt")
    results = run_eclat_baseline(vertical_db, num_tx, 0.4)
    gt = parse_spmf_result("data/toy/sample1_spmf.txt")

    @test length(results) == length(gt)
    for fi in results
        key = sort(fi.items)
        @test haskey(gt, key)
        @test gt[key] == fi.support
    end
end
