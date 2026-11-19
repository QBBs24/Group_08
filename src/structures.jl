module Structures

export EclatNode, BitEclatNode, FrequentItemset, AssociationRule

struct EclatNode
    item::Int
    tidset::Vector{Int}
end

struct BitEclatNode
    item::Int
    bitset::BitVector
    support::Int
end

struct FrequentItemset
    items::Vector{Int}
    support::Int
end

struct AssociationRule
    antecedent::Vector{Int}   # Vế trái X
    consequent::Vector{Int}   # Vế phải Y
    support_count::Int        # Số giao dịch chứa (X ∪ Y)
    support::Float64          # Support(X => Y) = sup(X ∪ Y) / |D|
    confidence::Float64       # Confidence(X => Y) = sup(X ∪ Y) / sup(X)
    lift::Float64             # Lift(X => Y) = Confidence / Support(Y)
end

end # module