module BaselineEclat

using ..Structures
export run_eclat_baseline

# Giao 2 tidset đã sắp xếp bằng 2 con trỏ
function intersect_sorted(a::Vector{Int}, b::Vector{Int})::Vector{Int}
    # Khai báo các biến dữ liệu cần thiết
    res = Int[]
    sizehint!(res, min(length(a), length(b)))    # Độ dài của res là min giữa độ dài của a và b
    i, j = 1, 1
    len_a, len_b = length(a), length(b)

    @inbounds while i <= len_a && j <= len_b     # Duyệt song song 2 tidset a và b
        va, vb = a[i], b[j]                     # Lấy 2 phần tử mà 2 con trỏ đang chỉ
        if va == vb                             # Nếu 2 phần tử bằng nhau
            push!(res, va)                      # Lấy 1 trong 2 phần tử
            i += 1                              # Rồi đẩy cả 2 index lên
            j += 1

        elseif va < vb                          # Nếu phần tử a < phần tử b 
            i += 1                              # Đẩy index của a lên để xét phần tử mới
        
        else                                    # Ngược lại nếu b < a
            j += 1                              # Đẩy index b lên 1 để xét phần tử mới
        end                                     
    end
    return res
end

function eclat_dfs!(
    prefix::Vector{Int},                                                     # Tiền tố tid (VD: 12, 13,...)
    nodes::Vector{EclatNode},                                                # Các node con cần duyệt
    min_sup_count::Int,                                                      # Độ support count tối thiểu
    results::Vector{FrequentItemset}                                        # Các Frequent Itemsets rút ra được
)
    n = length(nodes)                                                       # Lấy số con của node hiện tại
    for i in 1:n                                                            # Duyệt qua từng node con
        node_i = nodes[i]                                                   # Xét node con đầu tiên
        new_prefix = vcat(prefix, node_i.item)                              # Lấy tiền tố hiện tại ghép với tiền tố trước đó
        push!(results, FrequentItemset(new_prefix, length(node_i.tidset)))  # Đẩy vào những Frequent Itemset vào results

        next_nodes = EclatNode[]                                            # Tạo node tiếp theo
        for j in (i + 1):n                                                  # Lấy node con tiếp theo
            node_j = nodes[j]                                                # Gán node con là node_j
            same_tids = intersect_sorted(node_i.tidset, node_j.tidset)      # Giao tidset node hiện tại với tidset node tiếp theo => Những tid ở cả 2 node
            if (length(same_tids) >= min_sup_count)                          # Xét tidset giao của node_i và node_j có phổ biến hay không
                push!(next_nodes, EclatNode(node_j.item, same_tids))        # Nếu có, thêm node mới gồm cả 2 tiền tố i và j vào mảng next_nodes 
                                                                            # => Tạo ra các k-itemsets phổ biến
            end
        end

        if !isempty(next_nodes)                                             # Nếu next_nodes không rỗng
            eclat_dfs!(new_prefix, next_nodes, min_sup_count, results)      # Gọi đệ quy DFS để tìm ra các (k+1)-itemsets phổ biến mới
        end
    end
end

function run_eclat_baseline(
    vertical_db::Dict{Int, Vector{Int}},                 # Lấy bảng data dọc mới tạo được
    num_tx::Int,                                        # Số transaction trong bảng
    minsup::Float64,                                     # Phần trăm support tối thiểu
)::Vector{FrequentItemset}                              # Trả về 1 mảng gồm những Itemset phổ biến
                        
    min_sup_count = ceil(Int, minsup * num_tx)          # Tính min_sup_count bằng nhân số transaction với minsup
    results = FrequentItemset[]                         # Khởi tạo mảng result chứa những Itemset phổ biến

    freq_1 = EclatNode[]                                # Khởi tạo mảng freq_1 là những Itemset phổ biến có độ dài bằng 1
    for (item, tids) in vertical_db                     # Duyệt qua từng item và tidset của item đó
        if length(tids) >= min_sup_count                # Nếu độ support (độ dài của tidset) của item đó lớn hơn (hoặc bằng) min support count (support của item >= minsup)
            push!(freq_1, EclatNode(item, tids))        # Đẩy item đó vào freq_1 => 1-itemset đó là phổ biến
        end
    end
    sort!(freq_1, by = x -> (length(x.tidset), x.item)) # Sắp xếp các 1-itemset theo độ phổ biến tăng dần

    eclat_dfs!(Int[], freq_1, min_sup_count, results)   # Chạy DFS đệ quy để tìm các k-itemset phổ biến
    
    return results
end

end # module
