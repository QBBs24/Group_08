using Test

include("../src/structures.jl")
include("../src/utils.jl")
include("../src/algorithm/baseline.jl")
include("../src/algorithm/optimized.jl")

using .Structures
using .Utils
using .BaselineEclat
using .OptimizedEclat

# CONFIGURATIONS
const REPO_ROOT = normpath(joinpath(@__DIR__, ".."))
const SPMF_JAR = joinpath(REPO_ROOT, "spmf.jar")
const TOY_DIR = joinpath(REPO_ROOT, "data", "toy")
const BENCHMARK_DIR = joinpath(REPO_ROOT, "data", "benchmark")
const SPMF_REF = joinpath(BENCHMARK_DIR, "spmf_reference")

# Cached SPMF outputs
const CSV_PATH = joinpath(REPO_ROOT, "results", "benchmark_results.csv")
# File name, minsup from high to low
const BENCHMARKS = [
    ("chess.txt", [0.90, 0.85, 0.80, 0.75, 0.70, 0.65]),
    ("mushrooms.txt", [0.50, 0.40, 0.30, 0.25, 0.20, 0.15]),
    ("retail.txt", [0.02, 0.01, 0.005, 0.003, 0.002, 0.001]),
    ("T10I4D100K.txt", [0.02, 0.01, 0.007, 0.005, 0.003, 0.002])
]

# Every implementation must have f(vertical_db, num_tx, minsup) and return a Vector{FrequentItemset}

const IMPLEMENTATIONS = Pair{String, Function}[
    "baseline" => run_eclat_baseline,
    "optimized" => run_eclat_optimized
]

# HELPERS
# Read an SPMF output file into a Dict (sorted items => support)
function read_spmf_reference(filepath::String)::Dict{Vector{Int}, Int}
    ground_truth = Dict{Vector{Int}, Int}()
    for line in eachline(filepath)
        s = strip(line)
        (isempty(s) || startswith(s, '@') || startswith(s, '#') || startswith(s, '%')) && continue
        parts = split(s, "#SUP:")
        items = sort!(parse.(Int, split(strip(parts[1]))))
        ground_truth[items] = parse(Int, strip(parts[2]))
    end
    return ground_truth
end

# Return the path of SPMF's Eclat output for (dataset, minsup), running SPMF
# If it is not cached yet. Returns nothing if SMPF cannot be run_eclat_baseline
function spmf_reference(dataset::String, minsup::Float64)::Union{String, Nothing}
    stem = splitext(dataset)[1]
    ref = joinpath(SPMF_REF, "$(stem)_minsup$(minsup).txt")
    isfile(ref) && return ref
    isfile(SPMF_JAR) || return nothing

    mkpath(SPMF_REF)
    # round() avoid strings like 5.000000001% that would make SPMF compute a slightly different absolute
    # threshold compare to ours
    pct = string(round(minsup * 100; digits = 6), '%')
    cmd = `java -jar $SPMF_JAR run Eclat $(joinpath(BENCHMARK_DIR, dataset)) $ref $pct`
    try
        run(pipeline(cmd; stdout = devnull, stderr = devnull))
    catch
        return nothing
    end
    return isfile(ref) ? ref : nothing
end

function compare_to_reference(results::Vector{FrequentItemset}, ground_truth::Dict{Vector{Int}, Int})
    mine = Dict{Vector{Int}, Int}()
    for fi in results
        mine[sort(fi.items)] = fi.support
    end
    n_exact = count(p -> get(ground_truth, p.first, -1) == p.second, mine)
    return (n_results = length(results), n_unique = length(mine), 
    n_ref = length(ground_truth), n_exact = n_exact)
end

# Run every implementation once on a toy file so compilation time is not
# included in the measured runtimes.
function warm_up()
    toy = joinpath(TOY_DIR, "sample1.txt")
    isfile(toy) || return
    vdb, n = load_vertical_db(toy)
    for (_, impl) in IMPLEMENTATIONS
        impl(vdb, n, 0.4)
    end
end

function write_csv(path::String, rows)
    isempty(rows) && return
    mkpath(dirname(path))
    cols = keys(first(rows))
    open(path, "w") do io
        println(io, join(cols, ","))
        for r in rows
            println(io, join((r[c] for c in cols), ","))
        end
    end
end

# TESTS
warm_up()
rows = NamedTuple[]

@testset "Benchmark: correctness and timing vs SPMF" begin
    for (dataset, minsups) in BENCHMARKS
        path = joinpath(BENCHMARK_DIR, dataset)
        if !isfile(path)
            @warn "Dataset not found, skipping" path
            continue
        end

        vdb, num_tx = load_vertical_db(path)

        for minsup in minsups
            ref = spmf_reference(dataset, minsup)
            if ref === nothing
                @warn "No SPMF reference (is Java installed and new enough for spmf.jar?), skipping" dataset minsup
                continue
            end
            ground_truth = read_spmf_reference(ref)

            for (name, impl) in IMPLEMENTATIONS
                stats = @timed impl(vdb, num_tx, minsup)
                cmp   = compare_to_reference(stats.value, ground_truth)
                match_pct = 100 * cmp.n_exact / max(cmp.n_unique, cmp.n_ref, 1)

                push!(rows, (
                    implementation = name,
                    dataset        = dataset,
                    minsup         = minsup,
                    n_itemsets     = cmp.n_results,
                    n_spmf         = cmp.n_ref,
                    match_percent  = round(match_pct; digits = 4),
                    seconds        = round(stats.time; digits = 4),
                    alloc_mb       = round(stats.bytes / 2^20; digits = 2),
                ))
                @info "$name | $dataset | minsup=$minsup | $(cmp.n_results) itemsets | " *
                      "$(round(match_pct; digits = 2))% match | $(round(stats.time; digits = 3)) s"

                @testset "$name | $dataset | minsup=$minsup" begin
                    @test cmp.n_results == cmp.n_unique   # no duplicated itemsets
                    @test cmp.n_unique  == cmp.n_ref      # same number of itemsets as SPMF
                    @test cmp.n_exact   == cmp.n_ref      # every itemset and support matches
                end
            end
        end
    end
end

write_csv(CSV_PATH, rows)
isempty(rows) || @info "Results written to $CSV_PATH"