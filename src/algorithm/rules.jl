module AssociationRules

using ..Structures
export generate_association_rules

function generate_association_rules(
    frequent_itemsets::Vector{FrequentItemset},
    num_tx::Int,
    minconf::Float64;
    min_lift::Float64 = 1.0
)::Vector{AssociationRule}
    sup_map = Dict{Vector{Int}, Int}()
    sizehint!(sup_map, length(frequent_itemsets))
    for fi in frequent_itemsets
        sup_map[sort(fi.items)] = fi.support
    end

    rules = AssociationRule[]

    for fi in frequent_itemsets
        k = length(fi.items)
        k < 2 && continue

        items = sort(fi.items)
        sup_union = fi.support
        supp_rel = sup_union / num_tx

        max_mask = (1 << k) - 2
        for mask in 1:max_mask
            antecedent = Int[]
            consequent = Int[]
            @inbounds for bit in 0:(k - 1)
                if (mask >> bit) & 1 == 1
                    push!(antecedent, items[bit + 1])
                else
                    push!(consequent, items[bit + 1])
                end
            end

            sup_x = sup_map[antecedent]
            sup_y = sup_map[consequent]

            conf = sup_union / sup_x
            if conf >= minconf
                supp_y_rel = sup_y / num_tx
                lift = conf / supp_y_rel
                if lift >= min_lift
                    push!(rules, AssociationRule(
                        antecedent,
                        consequent,
                        sup_union,
                        supp_rel,
                        conf,
                        lift
                    ))
                end
            end
        end
    end

    sort!(rules, by = r -> (r.lift, r.confidence, r.support), rev = true)
    return rules
end

end # module