module BioSequenceMiningApp

using Printf

include(joinpath(@__DIR__, "..", "structures.jl"))
include(joinpath(@__DIR__, "..", "utils.jl"))
include(joinpath(@__DIR__, "..", "algorithm", "optimized.jl"))

using .Structures
using .Utils
using .OptimizedEclat

export prepare_dna_vertical_dbs, run_bio_sequence_mining

const BASES = ['A', 'C', 'G', 'T']

"""
Giải mã cụm 3 bit (b0, b1, b2) của Statlog DNA thành ký tự nucleotide:
  (1,0,0) -> 'A', (0,1,0) -> 'C', (0,0,1) -> 'G', (0,0,0) -> 'T'
"""
function decode_3bit_base(b0::Int, b1::Int, b2::Int)::Char
    if b0 == 1 && b1 == 0 && b2 == 0
        return 'A'
    elseif b0 == 0 && b1 == 1 && b2 == 0
        return 'C'
    elseif b0 == 0 && b1 == 0 && b2 == 1
        return 'G'
    elseif b0 == 0 && b1 == 0 && b2 == 0
        return 'T'
    else
        error("Tổ hợp bit không hợp lệ trong dữ liệu DNA: ($b0, $b1, $b2)")
    end
end

"""
Tạo bảng ánh xạ ID (1..240) -> nhãn 'PosXX=Base' (Pos01..Pos60, Base in A,C,G,T).
"""
function build_dna_item_labels()::Vector{String}
    labels = Vector{String}(undef, 240)
    for pos in 1:60
        for (b_idx, base) in enumerate(BASES)
            item_id = (pos - 1) * 4 + b_idx
            labels[item_id] = @sprintf("Pos%02d=%c", pos, base)
        end
    end
    return labels
end

"""
Đọc file dna.csv (180 cột đặc trưng nhị phân + 1 cột class), giải mã thành các giao dịch
60-item và nhóm theo từng lớp sinh học (1: EI/Donor, 2: IE/Acceptor, 3: Neither).
"""
function prepare_dna_vertical_dbs(filepath::String)
    raw_lines = filter(l -> !isempty(strip(l)), readlines(filepath))
    length(raw_lines) < 2 && error("File dữ liệu DNA không hợp lệ: $filepath")

    # Tách giao dịch theo nhãn class (1, 2, 3)
    class_txs = Dict{Int, Vector{Vector{Int}}}(
        1 => Vector{Vector{Int}}(),
        2 => Vector{Vector{Int}}(),
        3 => Vector{Vector{Int}}()
    )

    for line in @view raw_lines[2:end]
        cols = split(strip(line), ',')
        length(cols) < 181 && continue

        cls = parse(Int, strip(cols[181]))
        tx = Vector{Int}(undef, 60)

        @inbounds for pos in 1:60
            base_col = (pos - 1) * 3 + 1
            b0 = parse(Int, strip(cols[base_col]))
            b1 = parse(Int, strip(cols[base_col + 1]))
            b2 = parse(Int, strip(cols[base_col + 2]))
            nucleotide = decode_3bit_base(b0, b1, b2)

            b_idx = nucleotide == 'A' ? 1 : (nucleotide == 'C' ? 2 : (nucleotide == 'G' ? 3 : 4))
            tx[pos] = (pos - 1) * 4 + b_idx
        end
        push!(class_txs[cls], tx)
    end

    # Chuyển từng lớp thành CSDL dọc (Dict{Int, Vector{Int}}) cho Eclat
    vdbs = Dict{Int, Tuple{Dict{Int, Vector{Int}}, Int, Vector{Vector{Int}}}}()
    for (cls, txs) in class_txs
        vdb = Dict{Int, Vector{Int}}()
        for (tid, tx) in enumerate(txs)
            for item_id in tx
                if !haskey(vdb, item_id)
                    vdb[item_id] = Int[]
                end
                push!(vdb[item_id], tid)
            end
        end
        vdbs[cls] = (vdb, length(txs), txs)
    end

    return vdbs, build_dna_item_labels()
end

function format_pattern(ids::Vector{Int}, id_to_label::Vector{String})::String
    return "{" * join((id_to_label[id] for id in ids), ", ") * "}"
end

function save_bio_patterns_csv(
    filepath::String,
    class_label::String,
    itemsets::Vector{FrequentItemset},
    num_tx::Int,
    id_to_label::Vector{String}
)
    mkpath(dirname(filepath))
    open(filepath, "w") do io
        println(io, "class,rank,length,pattern,support_count,support_rel")
        for (idx, fi) in enumerate(itemsets)
            pat = "\"" * format_pattern(sort(fi.items), id_to_label) * "\""
            @printf(io, "%s,%d,%d,%s,%d,%.6f\n",
                class_label, idx, length(fi.items), pat, fi.support, fi.support / num_tx)
        end
    end
end

function run_bio_sequence_mining(;
    input_path::String,
    minsup_ei::Float64 = 0.45,
    minsup_ie::Float64 = 0.40,
    minsup_n::Float64  = 0.30,
    top_k::Int = 10,
    output_dir::String = joinpath(@__DIR__, "..", "..", "results", "app2")
)
    println("=== ỨNG DỤNG 2: KHAI THÁC MẪU TRÌNH TỰ GEN SPLICE-JUNCTION (DNA) ===")
    vdbs, id_to_label = prepare_dna_vertical_dbs(input_path)
    total_seqs = sum(v[2] for v in values(vdbs))
    println("• Dữ liệu đầu vào : $input_path (Tổng: $total_seqs trình tự, 60 vị trí -> 240 items)")

    mkpath(output_dir)

    configs = [
        (1, "EI_Donor",    "Class 1 - EI (Exon-Intron / Donor)",    minsup_ei),
        (2, "IE_Acceptor", "Class 2 - IE (Intron-Exon / Acceptor)", minsup_ie),
        (3, "N_Neither",   "Class 3 - N (Neither / Control Group)", minsup_n)
    ]

    all_summaries = Dict{String, Vector{FrequentItemset}}()

    for (cls, short_name, full_name, msup) in configs
        vdb, num_tx, txs = vdbs[cls]

        # Lưu bản giao dịch chuẩn SPMF .txt để kiểm chứng
        tx_out_path = joinpath(output_dir, "app2_dna_$(short_name)_transactions.txt")
        open(tx_out_path, "w") do io
            for tx in txs
                println(io, join(tx, " "))
            end
        end

        # Chạy chính thuật toán OptimizedEclat của nhóm
        t_run = @elapsed freq_itemsets = run_eclat_optimized(vdb, num_tx, msup)
        all_summaries[short_name] = freq_itemsets

        # Lọc các pattern có kích thước >= 2 (tổ hợp đa vị trí) và sắp xếp giảm dần theo support
        multi_patterns = filter(fi -> length(fi.items) >= 2, freq_itemsets)
        sort!(multi_patterns, by = fi -> (fi.support, length(fi.items)), rev = true)

        println("\n------------------------------------------------------------------------------------------")
        println("$full_name | N = $num_tx | minsup = $msup")
        println("• Tổng Frequent Itemsets: $(length(freq_itemsets)) (trong $(round(t_run; digits=4))s) | Tổ hợp k >= 2: $(length(multi_patterns))")

        k_show = min(top_k, length(multi_patterns))
        if k_show > 0
            @printf("%-4s | %-6s | %-52s | %-10s | %-8s\n", "Top", "Size", "Biological Position Pattern", "Sup.Count", "Support")
            println("-" ^ 90)
            for i in 1:k_show
                fi = multi_patterns[i]
                @printf("%-4d | %-6d | %-52s | %-10d | %.2f%%\n",
                    i, length(fi.items), format_pattern(sort(fi.items), id_to_label),
                    fi.support, 100.0 * fi.support / num_tx)
            end
        else
            println("  -> Không có tổ hợp vị trí nào vượt ngưỡng minsup = $msup (phân bố nền ngẫu nhiên ~25%).")
        end

        save_bio_patterns_csv(
            joinpath(output_dir, "app2_dna_$(short_name)_patterns.csv"),
            short_name, multi_patterns, num_tx, id_to_label
        )
    end

    println("\nĐã xuất toàn bộ dữ liệu giao dịch và bảng pattern sinh học vào: $output_dir")
    return all_summaries, id_to_label
end

if abspath(PROGRAM_FILE) == @__FILE__
    in_path = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "..", "..", "data", "apps", "dna.csv")
    run_bio_sequence_mining(input_path = in_path)
end

end # module