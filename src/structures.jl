module Structures

export FrequentItemset, EclatNode, BitEclatNode

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

end
