module Utils
using ..Structures
export load_vertical_db, save_to_spmf

# Hàm đọc file và biến đổi từ Itemset sang Tidset

function load_vertical_db(filepath::String)::Tuple{Dict{Int, Vector{Int}}, Int}
    vertical_db = Dict{Int, Vector{Int}}()
    tid = 0
    open(filepath, "r") do io

        # Đọc từng hàng trong file data
        for line in eachline(io)
            s = strip(line)            # Loại bỏ khoảng trắng
            (isempty(s) || startswith(s, "@") || startswith(s, "#") || startswith(s, "%")) && continue     # Nếu hàng đó trống, invalid format => Bỏ qua
            tid += 1                   # Transaction ID tăng theo thứ tự số nguyên => Biến đếm

            seen_in_tx = Set{Int}()                 # Loại bỏ các item trùng nhau bằng Set
            for token in split(s)                   # Duyệt từng item trong 1 transaction s
                item = parse(Int, token)            # Parse token to String sang Int
                if !(item in seen_in_tx)            # Nếu item chưa từng được duyệt qua
                    push!(seen_in_tx, item)         # Item này sẽ trở thành 1 key
                    if !haskey(vertical_db, item)   # Nếu key đó chưa có trong database
                        vertical_db[item] = Int[]   # Thì tạo 1 array cho key là item để lưu các transaction chứa nó.
                    end
                    push!(vertical_db[item], tid)   # Còn nếu key(item) đó đã có trong databse hoặc được tạo ra ở bước trên,
                end                                 # thì thêm tid (dòng) hiện tại đang duyệt vào vì tìm thấy item đó ở đây.
            end
        end
    end
    return vertical_db, tid
end

# Sau khi xử lý tìm FrequentItemset, gọi hàm này để viết ra file
function save_to_spmf(filepath::String, results::Vector{FrequentItemset})
    open(filepath, "w") do io                                               # Sử dụng io dạng "w" để viết file                                            
        for fi in results                                                   # Duyệt qua các FrequentItemset đúc kết ra sau khi chạy thuật toán
            println(io, join(fi.item, " "), " #SUP: ", fi.support)         # In ra các items của Itemset đó cùng với support count.
        end
    end
end

end # module


    
