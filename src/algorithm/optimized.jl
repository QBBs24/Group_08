module OptimizedEclat

using..Structures
export run_eclat_optimized

function intersect_bitset(a::BitVector, b::BitVector)::Tuple{BitVector, Int}
    res = BitVector(undef, length(a))
    ac, bc, rc = a.chunks, b.chunks, res.chunks
    sup = 0
    @inbound @simd for k in eachindex(rc)
        w = ac[k] & bc[k]
        rc[k] = w
        sup += count_ones(w)
    end
    return res, sup
end

function eclat_bit_dfs(prefix::Vector{Int}, nodes::Vector{BitEclatNode}, min_sup_count::Int, results::Vector{FrquentItemset})
    n = length(nodes)
    for i in 1:n
        node_i = nodes[i]
        new_prefix = vcat(prefix, node_i.item)
        push!(results, FrequentItemset(new_prefix, node_i.support))

        next_nodes = BitEclatNode
        for j in (i + 1):n
            node_j = nodes[j]
            common_bits, sup = intersect_bitset(node_i.bitset, node_j.bitset)
            if sup >= min_sup_count
                push!(next_nodes, BitEclatNode(node_j.item, common_bits, sup))
            end
        end

        if !isempty(next_nodes)
            eclat_bit_dfs(new_prefix, next_nodes, min_sup_count, results)
        end
    end
end

function run_eclat_optimized(vertical_db::Dict{Int, Vector{Int}}, num_tx::Int, minsup::Float64)::Vector{FrequentItemset}
    min_sup_count = ceil(Int, minsup * num_tx)
    results = FrequentItemset[]

    freq_1 = BitEclatNode[]
    for (item, tids) in vertical_db
        sup = length(tids)
        if sup >= min_sup_count
            bit_vector = false(num_tx)
            @inbounds for tid in tids
                bit_vector[tid] = true
            end
            push!(freq_1, BitEclatNode(item, bit_vector, sup))
        end
    end
    sort!(freq_1, by = x -> (x.support, x.item))

    eclat_bit_dfs(Int[], freq_1, min_sup_count, results)
    return results
end


end # module