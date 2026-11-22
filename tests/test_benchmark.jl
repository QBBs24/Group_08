using Test
using Random

include("../src/structures.jl")
include("../src/utils.jl")
include("../src/algorithm/baseline.jl")
include("../src/algorithm/optimized.jl")

using .Structures
using .Utils
using .BaselineEclat
using .OptimizedEclat

Random.seed!(42)

# CONFIGURATIONS
const REPO_ROOT     = normpath(joinpath(@__DIR__, ".."))
const SPMF_JAR      = joinpath(REPO_ROOT, "spmf.jar")
const TOY_DIR       = joinpath(REPO_ROOT, "data", "toy")
const BENCHMARK_DIR = joinpath(REPO_ROOT, "data", "benchmark")
const SPMF_REF      = joinpath(BENCHMARK_DIR, "spmf_reference")
const RESULTS_DIR   = joinpath(REPO_ROOT, "results/benchmark")

# 6 mốc minsup giảm dần cho Thực nghiệm 1, 2, 3
const BENCHMARKS = [
    ("chess.txt",      [0.90, 0.85, 0.80, 0.75, 0.70, 0.65]),
    ("mushrooms.txt",  [0.50, 0.40, 0.30, 0.25, 0.20, 0.15]),
    ("retail.txt",     [0.02, 0.01, 0.005, 0.003, 0.002, 0.001]),
    ("T10I4D100K.txt", [0.02, 0.01, 0.007, 0.005, 0.003, 0.002])
]

# Mốc minsup trung bình để đo Peak RAM (Thực nghiệm 4)
const MEDIUM_MINSUPS = Dict(
    "chess.txt"      => 0.75,
    "mushrooms.txt"  => 0.25,
    "retail.txt"     => 0.005,
    "T10I4D100K.txt" => 0.005
)

const IMPLEMENTATIONS = Pair{String, Function}[
    "baseline"  => run_eclat_baseline,
    "optimized" => run_eclat_optimized
]

# HELPERS
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

# Chạy SPMF và lưu kèm file .log để lấy cả thời gian chạy lẫn bộ nhớ của SPMF
function spmf_reference(dataset::String, minsup::Float64)
    stem     = splitext(dataset)[1]
    ref      = joinpath(SPMF_REF, "$(stem)_minsup$(minsup).txt")
    log_path = joinpath(SPMF_REF, "$(stem)_minsup$(minsup).log")
    mkpath(SPMF_REF)

    if !isfile(ref) || !isfile(log_path)
        isfile(SPMF_JAR) || return nothing
        pct = string(round(minsup * 100; digits = 6), '%')
        cmd = `java -jar $SPMF_JAR run Eclat $(joinpath(BENCHMARK_DIR, dataset)) $ref $pct`
        try
            out = read(cmd, String)
            write(log_path, out)
        catch
            return nothing
        end
    end

    isfile(ref) || return nothing
    log_txt = isfile(log_path) ? read(log_path, String) : ""
    m_time  = match(r"Total time ~ (\d+) ms", log_txt)
    m_mem   = match(r"Maximum memory usage : ([\d.]+) mb", log_txt)

    spmf_sec = m_time === nothing ? NaN : parse(Int, m_time.captures[1]) / 1000.0
    spmf_mb  = m_mem  === nothing ? NaN : parse(Float64, m_mem.captures[1])
    return (ref = ref, spmf_seconds = spmf_sec, spmf_mem_mb = spmf_mb)
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

# Đo Peak RAM (Max RSS) trong tiến trình con độc lập cho Thực nghiệm 4
function measure_peak_rss_mb(impl_name::String, dataset_path::String, minsup::Float64)::Float64
    fn = impl_name == "baseline" ? "run_eclat_baseline" : "run_eclat_optimized"
    code = """
    include("src/structures.jl")
    include("src/utils.jl")
    include("src/algorithm/baseline.jl")
    include("src/algorithm/optimized.jl")
    using .Structures, .Utils, .BaselineEclat, .OptimizedEclat
    vdb, num_tx = load_vertical_db($(repr(dataset_path)))
    $fn(vdb, num_tx, $minsup)
    println(Sys.maxrss() / 2^20)
    """
    out = read(Cmd(`$(Base.julia_cmd()) --project=$REPO_ROOT -e $code`; dir = REPO_ROOT), String)
    return round(parse(Float64, strip(out)); digits = 2)
end

# THỰC NGHIỆM 5: Scalability (10%, 25%, 50%, 75%, 100% giao dịch)
function run_scalability_experiment(dataset::String = "retail.txt", minsup::Float64 = 0.005)
    src_path = joinpath(BENCHMARK_DIR, dataset)
    isfile(src_path) || return NamedTuple[]

    lines = filter(l -> !isempty(strip(l)) && !startswith(strip(l), ('@', '#', '%')), readlines(src_path))
    total_tx  = length(lines)
    fractions = [0.10, 0.25, 0.50, 0.75, 1.00]
    scale_rows = NamedTuple[]

    tmp_dir = joinpath(BENCHMARK_DIR, "tmp_scale")
    mkpath(tmp_dir)
    for frac in fractions
        n_sub    = round(Int, total_tx * frac)
        sub_path = joinpath(tmp_dir, "sub_$(Int(frac * 100)).txt")
        write(sub_path, join(lines[1:n_sub], "\n"))

        t_load = @elapsed vdb, num_tx = load_vertical_db(sub_path)
        GC.gc()
        stats = @timed run_eclat_optimized(vdb, num_tx, minsup)

        push!(scale_rows, (
            dataset       = dataset,
            fraction      = frac,
            num_tx        = num_tx,
            n_itemsets    = length(stats.value),
            load_seconds  = round(t_load; digits = 4),
            algo_seconds  = round(stats.time; digits = 4),
            total_seconds = round(t_load + stats.time; digits = 4),
            alloc_mb      = round(stats.bytes / 2^20; digits = 2)
        ))
    end
    rm(tmp_dir; recursive = true, force = true)
    return scale_rows
end

# THỰC NGHIỆM 6: Ảnh hưởng của độ dài giao dịch trung bình (CSDL tổng hợp)
function run_tx_length_experiment(; num_tx::Int = 30_000, num_items::Int = 2000, minsup::Float64 = 0.05)
    Random.seed!(42)
    lengths  = [10, 20, 30, 40, 50]
    len_rows = NamedTuple[]

    tmp_dir = joinpath(BENCHMARK_DIR, "tmp_txlen")
    mkpath(tmp_dir)
    for avg_len in lengths
        syn_path = joinpath(tmp_dir, "syn_len_$(avg_len).txt")
        open(syn_path, "w") do io
            for _ in 1:num_tx
                tx = Int[]
                for item in 1:30
                    rand() < 0.08 && push!(tx, item)
                end
                rem_needed = max(0, avg_len - length(tx))
                if rem_needed > 0
                    append!(tx, randperm(num_items - 30)[1:min(rem_needed, num_items - 30)] .+ 30)
                end
                sort!(unique!(tx))
                println(io, join(tx, " "))
            end
        end

        t_load = @elapsed vdb, n = load_vertical_db(syn_path)
        GC.gc()
        stats = @timed run_eclat_optimized(vdb, n, minsup)

        push!(len_rows, (
            avg_tx_length = avg_len,
            num_tx        = n,
            n_itemsets    = length(stats.value),
            load_seconds  = round(t_load; digits = 4),
            algo_seconds  = round(stats.time; digits = 4),
            total_seconds = round(t_load + stats.time; digits = 4)
        ))
    end
    rm(tmp_dir; recursive = true, force = true)
    return len_rows
end

# MAIN EXECUTION
warm_up()
main_rows = NamedTuple[]
mem_rows  = NamedTuple[]

@testset "Chapter 2: Benchmark Experiments" begin
    # 1. Thực nghiệm 1, 2, 3: Correctness, Runtime vs minsup, Output Size vs minsup
    for (dataset, minsups) in BENCHMARKS
        path = joinpath(BENCHMARK_DIR, dataset)
        if !isfile(path)
            @warn "Dataset not found, skipping" path
            continue
        end

        t_load = @elapsed vdb, num_tx = load_vertical_db(path)

        for minsup in minsups
            spmf_info = spmf_reference(dataset, minsup)
            if spmf_info === nothing
                @warn "No SPMF reference, skipping" dataset minsup
                continue
            end
            ground_truth = read_spmf_reference(spmf_info.ref)

            for (name, impl) in IMPLEMENTATIONS
                GC.gc()
                stats     = @timed impl(vdb, num_tx, minsup)
                cmp       = compare_to_reference(stats.value, ground_truth)
                match_pct = 100 * cmp.n_exact / max(cmp.n_unique, cmp.n_ref, 1)

                push!(main_rows, (
                    implementation = name,
                    dataset        = dataset,
                    minsup         = minsup,
                    n_itemsets     = cmp.n_results,
                    n_spmf         = cmp.n_ref,
                    match_percent  = round(match_pct; digits = 4),
                    load_seconds   = round(t_load; digits = 4),
                    algo_seconds   = round(stats.time; digits = 4),
                    total_seconds  = round(t_load + stats.time; digits = 4),
                    spmf_seconds   = round(spmf_info.spmf_seconds; digits = 4),
                    alloc_mb       = round(stats.bytes / 2^20; digits = 2)
                ))

                @info "$name | $dataset | minsup=$minsup | $(cmp.n_results) itemsets | " *
                      "$(round(match_pct; digits = 2))% match | algo=$(round(stats.time; digits = 3))s vs spmf=$(spmf_info.spmf_seconds)s"

                @testset "$name | $dataset | minsup=$minsup" begin
                    @test cmp.n_results == cmp.n_unique
                    @test cmp.n_unique  == cmp.n_ref
                    @test cmp.n_exact   == cmp.n_ref
                end
            end
        end

        # 2. Thực nghiệm 4: Peak RAM (Baseline vs Optimized) tại minsup trung bình
        med_sup = MEDIUM_MINSUPS[dataset]
        for (name, _) in IMPLEMENTATIONS
            peak_mb = measure_peak_rss_mb(name, path, med_sup)
            push!(mem_rows, (
                implementation = name,
                dataset        = dataset,
                minsup         = med_sup,
                peak_rss_mb    = peak_mb
            ))
            @info "Memory | $name | $dataset | minsup=$med_sup | Peak RSS = $(peak_mb) MB"
        end
    end
end

# 3. Thực nghiệm 5 & 6
scale_rows = run_scalability_experiment("retail.txt", 0.005)
len_rows   = run_tx_length_experiment()

write_csv(joinpath(RESULTS_DIR, "exp1_2_3_main.csv"), main_rows)
write_csv(joinpath(RESULTS_DIR, "exp4_memory.csv"), mem_rows)
write_csv(joinpath(RESULTS_DIR, "exp5_scalability.csv"), scale_rows)
write_csv(joinpath(RESULTS_DIR, "exp6_tx_length.csv"), len_rows)
@info "All Chapter 2 CSV results saved to $RESULTS_DIR"