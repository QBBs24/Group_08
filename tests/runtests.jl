using Test
using Random

const REPO_ROOT = normpath(joinpath(@__DIR__, ".."))

# Nạp các mô-đun lõi
include(joinpath(REPO_ROOT, "src", "structures.jl"))
include(joinpath(REPO_ROOT, "src", "utils.jl"))
include(joinpath(REPO_ROOT, "src", "algorithm", "baseline.jl"))
include(joinpath(REPO_ROOT, "src", "algorithm", "optimized.jl"))
include(joinpath(REPO_ROOT, "src", "algorithm", "rules.jl"))

using .Structures
using .Utils
using .BaselineEclat
using .OptimizedEclat
using .AssociationRules

# Nạp mô-đun Ứng dụng 1 và Ứng dụng 2 (hỗ trợ cả src/applications và src/apps)
function include_app_file(filename::String)
    for folder in ("applications", "apps")
        p = joinpath(REPO_ROOT, "src", folder, filename)
        if isfile(p)
            include(p)
            return
        end
    end
    error("Không tìm thấy $filename trong src/applications/ hoặc src/apps/")
end

include_app_file("market_basket.jl")
include_app_file("bio_mining.jl")

using .MarketBasketApp
using .BioSequenceMiningApp

function parse_spmf_result(filepath::String)::Dict{Vector{Int}, Int}
    ground_truth = Dict{Vector{Int}, Int}()
    open(filepath, "r") do io
        for line in eachline(io)
            s = strip(line)
            (isempty(s) || startswith(s, '@') || startswith(s, '#') || startswith(s, '%')) && continue
            parts = split(s, "#SUP:")
            items = sort!(parse.(Int, split(strip(parts[1]))))
            sup = parse(Int, strip(parts[2]))
            ground_truth[items] = sup
        end
    end
    return ground_truth
end

@testset "Group_08 — Toàn bộ Unit Test (Core Eclat + App 1 + App 2)" begin

    # ==========================================================================
    # PHẦN 1: KIỂM THỬ LÕI ECLAT (BASELINE & OPTIMIZED VS. SPMF)
    # ==========================================================================
    @testset "1. Eclat Baseline & Optimized vs SPMF (5 Datasets)" begin
        test_cases = [
            ("sample1", 0.4),
            ("sample2", 0.5),
            ("sample3", 0.4),
            ("sample4", 1.0),
            ("sample5", 0.15)
        ]

        for (name, minsup) in test_cases
            @testset "$name (minsup=$minsup)" begin
                input_path = joinpath(REPO_ROOT, "data", "toy", "$(name).txt")
                spmf_path  = joinpath(REPO_ROOT, "data", "toy", "$(name)_spmf.txt")

                vdb, num_tx = load_vertical_db(input_path)
                gt = parse_spmf_result(spmf_path)

                res_base = run_eclat_baseline(vdb, num_tx, minsup)
                res_opt  = run_eclat_optimized(vdb, num_tx, minsup)

                dict_base = Dict(sort(fi.items) => fi.support for fi in res_base)
                dict_opt  = Dict(sort(fi.items) => fi.support for fi in res_opt)

                @test length(dict_base) == length(res_base)
                @test length(dict_opt)  == length(res_opt)
                @test dict_base == gt
                @test dict_opt  == gt
            end
        end
    end

    # ==========================================================================
    # PHẦN 2: ĐỐI CHIẾU CHÉO DỮ LIỆU THƯA & DỮ LIỆU DÀY ĐẶC
    # ==========================================================================
    @testset "2. Đối chiếu chéo Baseline vs Optimized (Sparse & Dense)" begin
        Random.seed!(2026)
        for density in (0.15, 0.55)
            n_tx, n_items = 200, 18
            vdb = Dict{Int, Vector{Int}}(i => Int[] for i in 1:n_items)
            for tid in 1:n_tx
                for item in 1:n_items
                    rand() < density && push!(vdb[item], tid)
                end
            end
            for ms in (0.15, 0.30)
                d_base = Dict(sort(fi.items) => fi.support for fi in run_eclat_baseline(vdb, n_tx, ms))
                d_opt  = Dict(sort(fi.items) => fi.support for fi in run_eclat_optimized(vdb, n_tx, ms))
                @test d_base == d_opt
            end
        end
    end

    # ==========================================================================
    # PHẦN 3: ỨNG DỤNG 1 — MARKET BASKET ANALYSIS & ASSOCIATION RULES
    # ==========================================================================
    @testset "3. Ứng dụng 1: Chuyển đổi giỏ hàng & Sinh luật kết hợp" begin
        mktempdir() do tmpdir
            csv_path = joinpath(tmpdir, "mini_groceries.csv")
            # Tạo 5 giao dịch thực tế (giao dịch đầu cố tình có 2 dòng "whole milk" trùng nhau)
            open(csv_path, "w") do io
                println(io, "Member_number,Date,itemDescription")
                println(io, "1001,01-01-2026,whole milk")
                println(io, "1001,01-01-2026,whole milk")
                println(io, "1001,01-01-2026,rolls/buns")
                println(io, "1002,01-01-2026,whole milk")
                println(io, "1002,01-01-2026,rolls/buns")
                println(io, "1003,01-01-2026,whole milk")
                println(io, "1003,01-01-2026,yogurt")
                println(io, "1004,01-01-2026,rolls/buns")
                println(io, "1004,01-01-2026,soda")
                println(io, "1005,01-01-2026,whole milk")
                println(io, "1005,01-01-2026,rolls/buns")
                println(io, "1005,01-01-2026,soda")
            end

            vdb, num_tx, id_to_item, _ = prepare_groceries_vertical_db(csv_path)
            @test num_tx == 5
            @test length(id_to_item) == 4

            fi = run_eclat_optimized(vdb, num_tx, 0.40) # min_count = 2
            rules = generate_association_rules(fi, num_tx, 0.70; min_lift = 0.5)

            # Kiểm tra luật {rolls/buns} => {whole milk}:
            # sup({milk, rolls}) = 3/5 = 0.6; sup({rolls}) = 4/5 = 0.8; sup({milk}) = 4/5 = 0.8
            # conf = 0.6 / 0.8 = 0.75; lift = 0.75 / 0.8 = 0.9375
            id_milk  = findfirst(==("whole milk"), id_to_item)
            id_rolls = findfirst(==("rolls/buns"), id_to_item)

            target = filter(r -> r.antecedent == [id_rolls] && r.consequent == [id_milk], rules)
            @test length(target) == 1
            @test target[1].support_count == 3
            @test target[1].support       ≈ 0.60
            @test target[1].confidence    ≈ 0.75
            @test target[1].lift          ≈ 0.9375

            # Đảm bảo danh sách luật được sắp xếp giảm dần theo Lift
            @test issorted([r.lift for r in rules], rev = true)
        end
    end

    # ==========================================================================
    # PHẦN 4: ỨNG DỤNG 2 — KHAI THÁC MẪU TRÌNH TỰ GEN DNA (BIO_MINING.JL)
    # ==========================================================================
    @testset "4. Ứng dụng 2: Giải mã 3-bit DNA & Khai thác Splice-Junction" begin
        # 4.1 Kiểm tra giải mã 3-bit nucleotide
        @test BioSequenceMiningApp.decode_3bit_base(1, 0, 0) == 'A'
        @test BioSequenceMiningApp.decode_3bit_base(0, 1, 0) == 'C'
        @test BioSequenceMiningApp.decode_3bit_base(0, 0, 1) == 'G'
        @test BioSequenceMiningApp.decode_3bit_base(0, 0, 0) == 'T'
        @test_throws ErrorException BioSequenceMiningApp.decode_3bit_base(1, 1, 0)

        # 4.2 Kiểm tra ánh xạ 240 nhãn vị trí Pos01=A .. Pos60=T
        labels = BioSequenceMiningApp.build_dna_item_labels()
        @test length(labels) == 240
        @test labels[1]   == "Pos01=A"
        @test labels[4]   == "Pos01=T"
        @test labels[123] == "Pos31=G"   # (31 - 1)*4 + 3 = 123
        @test labels[128] == "Pos32=T"   # (32 - 1)*4 + 4 = 128
        @test labels[240] == "Pos60=T"

        # 4.3 Kiểm tra pipeline đầy đủ trên dữ liệu DNA 180 cột nhị phân + 1 cột class
        mktempdir() do tmpdir
            Random.seed!(42)
            dna_csv = joinpath(tmpdir, "synthetic_dna.csv")
            out_dir = joinpath(tmpdir, "results_app2")

            # Mã hóa ký tự nucleotide -> chuỗi 3 bit "b0,b1,b2"
            encode_base(c::Char) = c == 'A' ? "1,0,0" : (c == 'C' ? "0,1,0" : (c == 'G' ? "0,0,1" : "0,0,0"))
            bases = ['A', 'C', 'G', 'T']

            open(dna_csv, "w") do io
                println(io, join(["f$i" for i in 1:180], ",") * ",class")

                # Tạo 10 trình tự Class 1 (EI_Donor): 9/10 trình tự bảo thủ GT tại Pos31=G, Pos32=T
                for seq_idx in 1:10
                    seq = [bases[mod1(seq_idx + pos, 4)] for pos in 1:60]
                    if seq_idx <= 9
                        seq[31] = 'G'
                        seq[32] = 'T'
                    end
                    println(io, join(encode_base.(seq), ",") * ",1")
                end

                # Tạo 10 trình tự Class 2 (IE_Acceptor): 8/10 trình tự bảo thủ AG tại Pos29=A, Pos30=G
                for seq_idx in 1:10
                    seq = [bases[mod1(seq_idx * 2 + pos, 4)] for pos in 1:60]
                    if seq_idx <= 8
                        seq[29] = 'A'
                        seq[30] = 'G'
                    end
                    println(io, join(encode_base.(seq), ",") * ",2")
                end

                # Tạo 10 trình tự Class 3 (N_Neither): phân bố luân phiên đều, không có motif > 40%
                for seq_idx in 1:10
                    seq = [bases[mod1(seq_idx + pos, 4)] for pos in 1:60]
                    println(io, join(encode_base.(seq), ",") * ",3")
                end
            end

            summaries, id_to_label = run_bio_sequence_mining(
                input_path = dna_csv,
                minsup_ei  = 0.80,
                minsup_ie  = 0.75,
                minsup_n   = 0.50,
                top_k      = 5,
                output_dir = out_dir
            )

            # Kiểm tra lớp EI_Donor tìm đúng motif {Pos31=G, Pos32=T} với support = 9/10
            ei_pairs = filter(fi -> sort(fi.items) == [123, 128], summaries["EI_Donor"])
            @test length(ei_pairs) == 1
            @test ei_pairs[1].support == 9

            # Kiểm tra lớp IE_Acceptor tìm đúng motif {Pos29=A, Pos30=G} với support = 8/10
            # Pos29=A -> (29-1)*4 + 1 = 113; Pos30=G -> (30-1)*4 + 3 = 119
            ie_pairs = filter(fi -> sort(fi.items) == [113, 119], summaries["IE_Acceptor"])
            @test length(ie_pairs) == 1
            @test ie_pairs[1].support == 8

            # Lớp N_Neither không có mẫu nào vượt ngưỡng 0.50
            @test isempty(summaries["N_Neither"])

            # Kiểm tra đầy đủ 3 tệp CSV và 3 tệp giao dịch SPMF đã được xuất
            @test isfile(joinpath(out_dir, "app2_dna_EI_Donor_patterns.csv"))
            @test isfile(joinpath(out_dir, "app2_dna_IE_Acceptor_patterns.csv"))
            @test isfile(joinpath(out_dir, "app2_dna_N_Neither_patterns.csv"))
            @test isfile(joinpath(out_dir, "app2_dna_EI_Donor_transactions.txt"))
        end
    end
end