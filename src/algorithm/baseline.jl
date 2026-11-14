module BaselineEclat
using ..Structures
export run_eclat_baseline

# Giao 2 tidset đã sắp xếp bằng 2 con trỏ
function intersect_sorted(a::Vector{Int}, b::Vector{Int})::Vector{Int}
    # Khai báo các biến dữ liệu cần thiết
    res = Int[]
    sizeint!(res, min(length(a), length(b)))
    i, j = 1, 1
    len_a, len_b = length(a), length(b)

    @inbound while i <= len_a && j <= len_b     # Duyệt song song 2 tidset a và b
        va, vb = a[i], b[j]                     # Lấy 2 phần tử mà 2 con trỏ đang chỉ
        if (va == vb)                           # Nếu 2 phần tử bằng nhau
            push!(res, va)                      # Lấy 1 trong 2 phần tử
            i += 1                              # Rồi đẩy cả 2 index lên
            j += 1

        elseif va < vb:                         # Nếu phần tử a < phần tử b
            push!(res, va)                      # Thêm phần tử a vào res
            i += 1                              # Đẩy index của a lên để xét phần tử mới
        
        else:
            push!(res, vb)                      # Ngược lại nếu b < a
            j += 1                              # Thêm item của tidset b vào res và đẩy index lên 1
        end                                     
    end
    return res
end

