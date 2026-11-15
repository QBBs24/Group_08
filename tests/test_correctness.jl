using Test

include("../src/structures.jl")
include("../src/algorithm/baseline.jl")
include("../src/utils.jl")

using .Structures
using .Utils
using .BaselineEclat

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

@testset "Eclat Baseline vs SPMF Correctness" begin
    vertical_db, num_tx = load_vertical_db("data/toy/sample1.txt")  # Load database dọc và lấy số transaction
    results = run_eclat_baseline(vertical_db, num_tx, 0.4)          # Chạy eclat tự tạo với minsup = 0.4
    gt = parse_spmf_result("data/toy/sample1_spmf.txt")             # Trích kết quả của spmf eclat với minsup = 0.4

    @test length(results) == length(gt)                             # Thử độ dài của 2 kết quả giống nhau
    for fi in results                                               # Với từng tập phổ biến trong results
        key = sort(fi.items)                                        # Sắp xếp các item theo thứ tự tăng dần và gán vào biến "key"
        @test haskey(gt, key)                                       # Xem gt có chứa key đó hay không
        @test gt[key] == fi.support                                 # Xem support của key đó ở 2 kết quả bằng nhau hay không
    end
end
