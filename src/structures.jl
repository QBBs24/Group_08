module Structures

export FrequentItemset, EclatNode

struct EclatNode
    item::Int
    tidset::Vector{Int}
end

struct FrequentItemset
    items::Vector{Int}
    support::Int
end

end
