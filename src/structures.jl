module Structures

export FrequentItemset, EclatNode

struct EclatNode
    item::Int
    tidset::Vector{Int}
end

struct FrequentItemset
    item::Vector{Int}
    support::Int
end

end
