using Test

include("../src/structures.jl")
include("../src/algorithm/baseline.jl")
include("../src/algorithm/optimized.jl")
include("../src/utils.jl")

using .Structures
using .Utils
using .BaselineEclat
using .OptimizedEclat

function parse_spmf_result(filepath::String)::Dict{Vector{Int}, Int}
    ground_truth = Dict{Vector{Int}, Int}()     # Đáp án chuẩn (1 từ điển): Gồm các key là vector Integer (các item) và value là support count tương ứng
    open(filepath, "r") do io                   # Đọc từng hàng trong file được truyền vào
        for line in eachline(io)                # Với từng hàng đọc được
            s = strip(line)                     # Xóa ký tự khoảng trắng
            (isempty(s) || startswith(s, '@') || startswith(s, '#') || startswith(s, '%')) && continue   # Nếu hàng trống hoặc bắt đầu bằng các ký tự @, #, % => Bỏ qua
            parts = split(s, "#SUP:")           # Chia hàng đó thành 2 phần, trước và sau #SUP:
            items = sort!(parse.(Int, split(strip(parts[1]))))      # Lấy phần ở trước "#SUP:" và lần lượt thực hiện
                                                                    # Xóa ký tự khoảng trắng
                                                                    # Tách từng item và parse thành dạng Integer
                                                                    # Sắp xếp các item theo thứ tự tăng dần
            sup = parse(Int, strip(parts[2]))       # Parse phần ở đằng sau "#SUP:" => Lấy được support count và parse dạng Integer
            ground_truth[items] = sup               # Trong ground_truth, gán giá trị support count vào key items tương ứng
        end
    end
    return ground_truth
end

test_cases = [
    ("sample1", 0.4),   # CSDL chuẩn 5 giao dịch
    ("sample2", 0.5),   # CSDL dày đặc (nhiều item chung)
    ("sample3", 0.4),   # CSDL thưa, item chưa sắp xếp & có item trùng trong 1 dòng
    ("sample4", 1.0),   # Trường hợp biên: minsup = 100% (kết quả rỗng)
    ("sample5", 0.15),  # CSDL lớn hơn (20 giao dịch) với minsup thấp để test đệ quy sâu
]

function verify_against_gt(results::Vector{FrequentItemset}, gt::Dict{Vector{Int}, Int})
    res_dict = Dict{Vector{Int}, Int}(sort(fi.items) => fi.support for fi in results)
    @test length(res_dict) == length(results)
    @test res_dict == gt
end

@testset "Eclat Baseline & Optimized vs SPMF (5 Datasets)" begin
    for (name, minsup) in test_cases
        @testset "$name (minsup=$minsup)" begin
            input_path = "data/toy/$(name).txt"
            spmf_path  = "data/toy/$(name)_spmf.txt"

            vdb, num_tx = load_vertical_db(input_path)
            gt = parse_spmf_result(spmf_path)

            res_baseline = run_eclat_baseline(vdb, num_tx, minsup)
            res_optimized  = run_eclat_optimized(vdb, num_tx, minsup)

            verify_against_gt(res_baseline, gt)
            verify_against_gt(res_optimized, gt)
        end
    end
end


#     vertical_db, num_tx = load_vertical_db("data/toy/sample1.txt")  # Load database dọc và lấy số transaction
#     results = run_eclat_baseline(vertical_db, num_tx, 0.4)          # Chạy eclat tự tạo với minsup = 0.4
#     gt = parse_spmf_result("data/toy/sample1_spmf.txt")             # Trích kết quả của spmf eclat với minsup = 0.4

#     results2 = run_eclat_optimized(vertical_db, num_tx, 0.4)
#     gt2 = parse_spmf_result("data/toy/sample1_optimized_spmf.txt")

#     @test length(results) == length(gt)                             # Thử độ dài của 2 kết quả giống nhau
#     for fi in results                                               # Với từng tập phổ biến trong results
#         key = sort(fi.items)                                        # Sắp xếp các item theo thứ tự tăng dần và gán vào biến "key"
#         @test haskey(gt, key)                                       # Xem gt có chứa key đó hay không
#         @test gt[key] == fi.support                                 # Xem support của key đó ở 2 kết quả bằng nhau hay không
#     end
# end
