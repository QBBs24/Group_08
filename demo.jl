#!/usr/bin/env julia
using Printf
using Dates
using Random

const ROOT_DIR = @__DIR__

# ==============================================================================
# 1. NẠP TOÀN BỘ MÔ-ĐUN LÕI & ỨNG DỤNG CỦA NHÓM
# ==============================================================================
include(joinpath(ROOT_DIR, "src", "structures.jl"))
include(joinpath(ROOT_DIR, "src", "utils.jl"))
include(joinpath(ROOT_DIR, "src", "algorithm", "baseline.jl"))
include(joinpath(ROOT_DIR, "src", "algorithm", "optimized.jl"))
include(joinpath(ROOT_DIR, "src", "algorithm", "rules.jl"))

using .Structures
using .Utils
using .BaselineEclat
using .OptimizedEclat
using .AssociationRules

function include_app_module(filename::String)
    for folder in ("applications", "apps")
        p = joinpath(ROOT_DIR, "src", folder, filename)
        if isfile(p)
            include(p)
            return p
        end
    end
    error("Không tìm thấy tệp ứng dụng $filename trong src/applications/ hoặc src/apps/")
end

const MB_PATH  = include_app_module("market_basket.jl")
const BIO_PATH = include_app_module("bio_mining.jl")

using .MarketBasketApp
using .BioSequenceMiningApp

# ==============================================================================
# 2. PHÂN TÍCH THAM SỐ DÒNG LỆNH (CLI)
# ==============================================================================
struct DemoConfig
    mode::String          # "all", "core", "app1", "app2"
    input_file::String    # Tệp .txt tùy chọn cho phần lõi (nếu truyền từ CLI)
    minsup_core::Float64
    minsup_app1::Float64
    minconf_app1::Float64
    minsup_ei::Float64
    minsup_ie::Float64
    minsup_n::Float64
end

function parse_cli_args(args::Vector{String})::DemoConfig
    mode         = "all"
    input_file   = ""
    minsup_core  = 0.40
    minsup_app1  = 0.002
    minconf_app1 = 0.07
    minsup_ei    = 0.45
    minsup_ie    = 0.40
    minsup_n     = 0.30

    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "--app" && i < length(args)
            mode = lowercase(args[i + 1]); i += 2
        elseif arg == "--minsup" && i < length(args)
            val = parse(Float64, args[i + 1])
            minsup_core = val
            minsup_app1 = val
            i += 2
        elseif arg == "--minconf" && i < length(args)
            minconf_app1 = parse(Float64, args[i + 1]); i += 2
        elseif arg == "--minsup-ei" && i < length(args)
            minsup_ei = parse(Float64, args[i + 1]); i += 2
        elseif arg == "--minsup-ie" && i < length(args)
            minsup_ie = parse(Float64, args[i + 1]); i += 2
        elseif arg == "--minsup-n" && i < length(args)
            minsup_n = parse(Float64, args[i + 1]); i += 2
        elseif !startswith(arg, "--") && isfile(arg)
            input_file = arg; i += 1
        else
            i += 1
        end
    end

    return DemoConfig(mode, input_file, minsup_core, minsup_app1, minconf_app1, minsup_ei, minsup_ie, minsup_n)
end

# ==============================================================================
# 3. TRÌNH DIỄN TỪNG PHẦN
# ==============================================================================
function demo_core_eclat(cfg::DemoConfig)
    println("\n" * "="^88)
    println("[PHẦN 1] KIỂM CHỨNG LÕI THUẬT TOÁN ECLAT (BASELINE SET{INT} VS. OPTIMIZED BITVECTOR)")
    println("="^88)

    sample_path = isempty(cfg.input_file) ? joinpath(ROOT_DIR, "data", "toy", "sample1.txt") : cfg.input_file
    if isfile(sample_path)
        vdb, num_tx = load_vertical_db(sample_path)
        res_base = run_eclat_baseline(vdb, num_tx, cfg.minsup_core)
        res_opt  = run_eclat_optimized(vdb, num_tx, cfg.minsup_core)

        dict_base = Dict(sort(fi.items) => fi.support for fi in res_base)
        dict_opt  = Dict(sort(fi.items) => fi.support for fi in res_opt)

        println("• Tệp kiểm chứng  : $sample_path (N = $num_tx giao dịch, minsup = $(cfg.minsup_core))")
        println("• Kết quả tìm được: Baseline = $(length(res_base)) | Optimized = $(length(res_opt)) | Khớp 100%: $(dict_base == dict_opt)")
    end

    # Benchmark nhanh trên dữ liệu mật độ cao tổng hợp (N = 3.000, M = 40)
    Random.seed!(42)
    n_tx, n_items = 3000, 40
    vdb_syn = Dict{Int, Vector{Int}}(i => Int[] for i in 1:n_items)
    for tid in 1:n_tx
        for item in 1:n_items
            rand() < 0.35 && push!(vdb_syn[item], tid)
        end
    end

    # Warm-up JIT compiler
    run_eclat_baseline(vdb_syn, n_tx, 0.30)
    run_eclat_optimized(vdb_syn, n_tx, 0.30)

    println("\nSo sánh hiệu năng trên dữ liệu dày đặc tổng hợp (3.000 giao dịch × 40 items, mật độ ~35%):")
    @printf("%-8s | %-10s | %-12s | %-12s | %-9s | %-11s\n",
            "minsup", "Itemsets", "Base (ms)", "Opt (ms)", "Speedup", "Giảm RAM")
    println("-"^76)

    for ms in (0.25, 0.20, 0.16, 0.13)
        GC.gc()
        t_base = @elapsed r_base = run_eclat_baseline(vdb_syn, n_tx, ms)
        m_base = @allocated run_eclat_baseline(vdb_syn, n_tx, ms)

        GC.gc()
        t_opt = @elapsed r_opt = run_eclat_optimized(vdb_syn, n_tx, ms)
        m_opt = @allocated run_eclat_optimized(vdb_syn, n_tx, ms)

        @assert length(r_base) == length(r_opt) "Sai lệch số lượng tập phổ biến tại minsup = $ms"
        speedup = t_base / max(t_opt, 1e-9)
        mem_red = (1.0 - m_opt / max(m_base, 1)) * 100.0

        @printf("%-8.2f | %-10d | %11.2f  | %11.2f  | %8.2fx | %9.1f%%\n",
                ms, length(r_opt), t_base * 1000, t_opt * 1000, speedup, mem_red)
    end
end

function find_data_file(candidates::Vector{String})
    for rel in candidates
        p = joinpath(ROOT_DIR, rel)
        isfile(p) && return p
    end
    return nothing
end

function demo_app1_market_basket(cfg::DemoConfig)
    println("\n" * "="^88)
    groc_path = find_data_file([
        "data/apps/Groceries_dataset.csv",
        "data/applications/Groceries_dataset.csv",
        "data/Groceries_dataset.csv",
        "data/apps/groceries.csv"
    ])
    if isnothing(groc_path)
        println("[BỎ QUA ỨNG DỤNG 1] Không tìm thấy Groceries_dataset.csv trong thư mục data/apps/.")
        return
    end

    run_market_basket_analysis(
        input_path = groc_path,
        minsup     = cfg.minsup_app1,
        minconf    = cfg.minconf_app1,
        top_k      = 10,
        output_dir = joinpath(ROOT_DIR, "results", "app1")
    )
end

function demo_app2_bio_sequence(cfg::DemoConfig)
    println("\n" * "="^88)
    dna_path = find_data_file([
        "data/apps/dna.csv",
        "data/applications/dna.csv",
        "data/dna.csv"
    ])
    if isnothing(dna_path)
        println("[BỎ QUA ỨNG DỤNG 2] Không tìm thấy dna.csv trong thư mục data/apps/.")
        return
    end

    run_bio_sequence_mining(
        input_path = dna_path,
        minsup_ei  = cfg.minsup_ei,
        minsup_ie  = cfg.minsup_ie,
        minsup_n   = cfg.minsup_n,
        top_k      = 10,
        output_dir = joinpath(ROOT_DIR, "results", "app2")
    )
end

function main()
    cfg = parse_cli_args(ARGS)
    println("="^88)
    println("  CHƯƠNG TRÌNH TRÌNH DIỄN ĐỒ ÁN KHAI PHÁ DỮ LIỆU (GROUP_08) — THUẬT TOÁN ECLAT")
    println("  Thời gian chạy: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS")) | Chế độ: $(uppercase(cfg.mode))")
    println("="^88)

    if cfg.mode in ("all", "core")
        demo_core_eclat(cfg)
    end
    if cfg.mode in ("all", "app1")
        demo_app1_market_basket(cfg)
    end
    if cfg.mode in ("all", "app2")
        demo_app2_bio_sequence(cfg)
    end

    println("\n" * "="^88)
    println("  HOÀN TẤT TOÀN BỘ CHƯƠNG TRÌNH DEMO!")
    println("="^88)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end