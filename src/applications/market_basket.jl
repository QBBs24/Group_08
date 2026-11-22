module MarketBasketApp

using Printf

include(joinpath(@__DIR__, "..", "structures.jl"))
include(joinpath(@__DIR__, "..", "utils.jl"))
include(joinpath(@__DIR__, "..", "algorithm", "optimized.jl"))
include(joinpath(@__DIR__, "..", "algorithm", "rules.jl"))

using .Structures
using .Utils
using .OptimizedEclat
using .AssociationRules

export prepare_groceries_vertical_db, run_market_basket_analysis


function parse_csv_line(line::AbstractString)::Vector{String}
    fields = String[]
    buf = IOBuffer()
    in_quotes = false
    for c in line
        if c == '"'
            in_quotes = !in_quotes
        elseif c == ',' && !in_quotes
            push!(fields, strip(String(take!(buf))))
        else
            write(buf, c)
        end
    end
    push!(fields, strip(String(take!(buf))))
    return fields
end

function prepare_groceries_vertical_db(filepath::String)
    raw_lines = filter(l -> !isempty(strip(l)), readlines(filepath))
    isempty(raw_lines) && error("File dữ liệu rỗng: $filepath")

    first_fields = lowercase.(parse_csv_line(raw_lines[1]))
    is_long_format = ("member_number" in first_fields) && ("itemdescription" in first_fields)

    transactions_str = Vector{Vector{String}}()

    if is_long_format
        # Định dạng bảng quan hệ: gom nhóm theo (Member_number, Date)
        idx_member = findfirst(==("member_number"), first_fields)
        idx_date   = findfirst(==("date"), first_fields)
        idx_item   = findfirst(==("itemdescription"), first_fields)

        baskets = Dict{Tuple{String, String}, Vector{String}}()
        basket_order = Tuple{String, String}[]

        for line in @view raw_lines[2:end]
            cols = parse_csv_line(line)
            length(cols) < max(idx_member, idx_date, idx_item) && continue
            key = (cols[idx_member], cols[idx_date])
            item_name = strip(cols[idx_item])
            isempty(item_name) && continue

            if !haskey(baskets, key)
                baskets[key] = String[]
                push!(basket_order, key)
            end
            push!(baskets[key], item_name)
        end

        for key in basket_order
            push!(transactions_str, unique(baskets[key]))
        end
    else
        # Định dạng mỗi dòng một giỏ hàng
        has_header = startswith(first_fields[1], "item")
        has_count_col = (first_fields[1] == "item(s)")
        start_idx = has_header ? 2 : 1

        for line in @view raw_lines[start_idx:end]
            cols = parse_csv_line(line)
            isempty(cols) && continue
            item_cols = has_count_col && length(cols) > 1 ? cols[2:end] : cols
            items = unique(filter(!isempty, strip.(item_cols)))
            !isempty(items) && push!(transactions_str, items)
        end
    end

    # Ánh xạ tên mặt hàng (String) -> ID số nguyên (1..M) và xây dựng CSDL dọc
    item_to_id = Dict{String, Int}()
    id_to_item = String[]
    vdb = Dict{Int, Vector{Int}}()
    transactions_int = Vector{Vector{Int}}()

    for (tid, tx_items) in enumerate(transactions_str)
        tx_ids = Int[]
        for name in tx_items
            id = get!(item_to_id, name) do
                push!(id_to_item, name)
                length(id_to_item)
            end
            push!(tx_ids, id)
            if !haskey(vdb, id)
                vdb[id] = Int[]
            end
            push!(vdb[id], tid)
        end
        sort!(tx_ids)
        push!(transactions_int, tx_ids)
    end

    return vdb, length(transactions_int), id_to_item, transactions_int
end

function format_itemset(ids::Vector{Int}, id_to_item::Vector{String})::String
    return "{" * join((id_to_item[id] for id in ids), ", ") * "}"
end

function save_rules_csv(filepath::String, rules::Vector{AssociationRule}, id_to_item::Vector{String})
    mkpath(dirname(filepath))
    open(filepath, "w") do io
        println(io, "rank,antecedent,consequent,support_count,support,confidence,lift")
        for (idx, r) in enumerate(rules)
            ant = "\"" * join((id_to_item[id] for id in r.antecedent), ", ") * "\""
            con = "\"" * join((id_to_item[id] for id in r.consequent), ", ") * "\""
            @printf(io, "%d,%s,%s,%d,%.6f,%.6f,%.4f\n",
                idx, ant, con, r.support_count, r.support, r.confidence, r.lift)
        end
    end
end

function run_market_basket_analysis(;
    input_path::String,
    minsup::Float64 = 0.01,
    minconf::Float64 = 0.30,
    top_k::Int = 10,
    output_dir::String = joinpath(@__DIR__, "..", "..", "results", "app1")
)
    println("=== ỨNG DỤNG 1: PHÂN TÍCH GIỎ HÀNG (MARKET BASKET ANALYSIS) ===")
    vdb, num_tx, id_to_item, tx_ints = prepare_groceries_vertical_db(input_path)
    println("• Dữ liệu đầu vào : $input_path")
    println("• Tổng giao dịch  : $num_tx | Số mặt hàng phân biệt: $(length(id_to_item))")

    # Lưu bản chuyển đổi dạng SPMF .txt để kiểm chứng minh bạch
    mkpath(output_dir)
    spmf_tx_path = joinpath(output_dir, "app1_groceries_transactions.txt")
    open(spmf_tx_path, "w") do io
        for tx in tx_ints
            println(io, join(tx, " "))
        end
    end

    # Chạy chính thuật toán OptimizedEclat của nhóm
    t_eclat = @elapsed freq_itemsets = run_eclat_optimized(vdb, num_tx, minsup)
    println("• Frequent Itemsets tìm được (minsup=$minsup): $(length(freq_itemsets)) (trong $(round(t_eclat; digits=4))s)")

    # Tự sinh luật kết hợp từ frequent itemsets
    t_rules = @elapsed rules = generate_association_rules(freq_itemsets, num_tx, minconf; min_lift = 1.0)
    println("• Luật kết hợp thỏa mãn (minconf=$minconf, Lift >= 1.0): $(length(rules)) (trong $(round(t_rules; digits=4))s)\n")

    k_show = min(top_k, length(rules))
    println("TOP-$k_show LUẬT KẾT HỢP CÓ CHỈ SỐ LIFT CAO NHẤT:")
    println("-" ^ 105)
    @printf("%-4s | %-34s => %-24s | %-7s | %-7s | %-6s\n",
            "Top", "Antecedent (X)", "Consequent (Y)", "Support", "Conf.", "Lift")
    println("-" ^ 105)
    for i in 1:k_show
        r = rules[i]
        @printf("%-4d | %-34s => %-24s | %.4f  | %.4f  | %.4f\n",
                i,
                format_itemset(r.antecedent, id_to_item),
                format_itemset(r.consequent, id_to_item),
                r.support,
                r.confidence,
                r.lift)
    end
    println("-" ^ 105)

    save_rules_csv(joinpath(output_dir, "app1_all_rules.csv"), rules, id_to_item)
    save_rules_csv(joinpath(output_dir, "app1_top$(k_show)_rules.csv"), rules[1:k_show], id_to_item)
    println("\nĐã xuất kết quả chi tiết vào: $output_dir")

    return rules, freq_itemsets, id_to_item
end

# Cho phép chạy trực tiếp từ dòng lệnh
if abspath(PROGRAM_FILE) == @__FILE__
    in_path  = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "..", "..", "data", "apps", "groceries.csv")
    min_sup  = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 0.01
    min_conf = length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : 0.30
    run_market_basket_analysis(input_path = in_path, minsup = min_sup, minconf = min_conf, top_k = 10)
end

end # module