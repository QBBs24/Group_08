# Group_08

## Thành viên
- 24127278 - Hoàng Minh Huy
- 24127329 - Lê Nguyễn Quốc Bảo

## 2. Tài nguyên & Liên kết công khai

- Demo notebook (Google Colab): `https://colab.research.google.com/drive/1ypDhya17R0R00jJbfhUZ5GS0SjnWh0oF?usp=sharing`
- Báo cáo kỹ thuật (IEEE Format): `docs/Report.pdf`
- Nguồn dữ liệu Benchmark & Ứng dụng (Kaggle):
    + Chess, Mushrooms, Retail, T10I4D100K (Chương 2)
        + Chess: `https://www.philippe-fournier-viger.com/spmf/publicdatasets/chess.txt`
        + Mushrooms: `https://www.philippe-fournier-viger.com/spmf/publicdatasets/mushrooms.txt`
        + Retail: `https://www.philippe-fournier-viger.com/spmf/publicdatasets/retail.txt`
        + T10I4D100K: `https://www.philippe-fournier-viger.com/spmf/publicdatasets/T10I4D100K.txt`
    + Groceries Dataset (Chương 3 — Ứng dụng 1): `https://www.kaggle.com/datasets/heeraldedhia/groceries-dataset`
    + Statlog DNA Splice-Junction (Chương 3 — Ứng dụng 2): `https://www.kaggle.com/datasets/muhammetvarl/splicejunction-gene-sequences-dataset`
- Bài báo gốc tham chiếu:
    + Zaki, M. J., Parthasarathy, S., Ogihara, M., & Li, W. (1997). *New Algorithms for Fast Discovery of Association Rules*. KDD-97.
    + Zaki, M. J. (2000). *Scalable Algorithms for Association Mining*. IEEE Transactions on Knowledge and Data Engineering (TKDE), 12(3), 372–390.

## 3. Cấu trúc thư mục dự án

Group_08/
├── README.md                         # Tài liệu hướng dẫn, tài nguyên và log kiểm thử
├── Project.toml                      # Khai báo môi trường và gói phụ thuộc Julia (>= 1.9)
├── requirements.txt                  # Thư viện Python hỗ trợ trực quan hóa trong Notebook
├── src/
│   ├── structures.jl                 # Định nghĩa cấu trúc EclatNode, BitEclatNode, FrequentItemset, AssociationRule
│   ├── utils.jl                      # Đọc/ghi định dạng giao dịch chuẩn SPMF
│   ├── algorithm/
│   │   ├── baseline.jl               # Eclat cơ bản (tidset dùng Vector{Int}, giao 2 con trỏ)
│   │   ├── optimized.jl              # Eclat tối ưu (tidset dùng BitVector, giao từ máy UInt64 với @simd)
│   │   └── rules.jl                  # Tự cài đặt sinh luật kết hợp (Support, Confidence, Lift)
│   └── applications/
│       ├── market_basket.jl          # Ứng dụng 1: Phân tích giỏ hàng (Market Basket Analysis)
│       └── bio_mining.jl             # Ứng dụng 2: Khai thác mẫu trình tự gen Splice-Junction (DNA)
├── tests/
│   ├── test_correctness.jl           # Kiểm thử tự động đối chiếu 1-1 với SPMF trên 5 CSDL
│   └── test_benchmark.jl             # Bộ 6 thực nghiệm đánh giá hiệu năng, bộ nhớ và khả năng mở rộng
├── data/
│   ├── toy/                          # 5 CSDL nhỏ và kết quả chuẩn SPMF phục vụ unit test
│   ├── apps/                         # Dữ liệu cho Chương 3 (Groceries_dataset.csv, dna.csv)
│   └── benchmark/                    # Thư mục chứa 4 bộ benchmark lớn (tải từ link ở Mục 2)
├── notebooks/
│   └── demo.ipynb                    # Notebook tổng hợp thực nghiệm và trực quan hóa trên Google Colab
└── docs/
    └── Report.pdf                    # Báo cáo đồ án theo chuẩn IEEE Conference (10–15 trang)

## 4. Hướng dẫn cài đặt môi trường

### Yêu cầu hệ thống

- Julia: Phiên bản 1.9 trở lên (Tải tại julialang.org).
- Python (tùy chọn, dùng cho Notebook cục bộ): Phiên bản 3.9 trở lên.
- Java Runtime Environment (JRE): Chỉ cần thiết nếu muốn chạy lại file đối chiếu spmf.jar.

### Các bước cài đặt

#### a. Clone repository và di chuyển vào thư mục gốc:

- Clone repository và di chuyển vào thư mục gốc và chạy:
    + `git clone https://github.com/QBBs24/Group_08`
    + `cd Group_08`

#### b. Khởi tạo và cài đặt các gói phụ thuộc cho Julia:

- Chạy `julia --project=. -e 'using Pkg; Pkg.instantiate()'`

#### c. Cài đặt thư viện Python phục vụ vẽ biểu đồ (nếu chạy Jupyter Notebook trên máy cá nhân):

- Chạy `pip install -r requirements.txt`

## 5. Hướng dẫn chạy và Ví dụ sử dụng

### a. Chương 1: Chạy bộ kiểm thử tự động (Unit Tests)

- Chạy `julia --project=. tests/test_correctness.jl`

### b. Chương 2: Chạy thực nghiệm Benchmark

- Đặt 4 file dữ liệu benchmark (chess.txt, mushrooms.txt, retail.txt, T10I4D100K.txt) vào data/benchmark/
- Chạy `julia --project tests/test_benchmark.jl`
- Kết quả thực nghiệm được xuất tự động ra 4 tệp CSV trong thư mục results/ (exp1_2_3_main.csv, exp4_memory.csv, exp5_scalability.csv, exp6_tx_length.csv).

### c. Chương 3: Ứng dụng

#### Chạy Ứng dụng 1 — Phân tích giỏ hàng (Market Basket Analysis)

- Cú pháp: *julia --project=. src/applications/market_basket.jl <đường_dẫn_csv> <minsup> <minconf>*
- Ví dụ: `julia --project=. src/applications/market_basket.jl data/apps/Groceries_dataset.csv 0.002 0.07`
- Ví dụ kết quả đầu ra: Từ 14,963 giỏ hàng với 167 mặt hàng, hệ thống khai thác được 330 tập phổ biến và xuất bảng Top luật kết hợp theo chỉ số Lift (cao nhất là {frankfurter} => {other vegetables} với Lift = 1.1161, Confidence = 13.63%) ra results/app1_top10_rules.csv.

#### Chạy Ứng dụng 2 — Khai thác mẫu trình tự DNA Splice-Junction

- Cú pháp: *julia --project=. src/applications/bio_mining.jl <đường_dẫn_dna_csv>*
- Ví dụ: `julia --project=. src/applications/bio_mining.jl data/apps/dna.csv`
- Ví dụ kết quả đầu ra: Giải mã 3,186 chuỗi DNA 60 vị trí thành 240 đặc trưng (Vị_trí, Nucleotide) và khai thác các motif bảo thủ đặc trưng cho ranh giới Exon–Intron ({Pos31=G, Pos32=T} đạt 99.0% support) và Intron–Exon ({Pos29=A, Pos30=G} đạt 99.5% support).

### e. Mở Demo Notebook
- Chạy `jupyter notebook notebooks/demo.ipynb`

## 6. Kết quả chạy kiểm thử (Unit Test Output)
- Kết quả chạy lệnh julia --project=. tests/test_correctness.jl lần cuối trước khi nộp bài:
    Test Summary:                                   | Pass  Total  Time
    Eclat Baseline & Optimized vs SPMF (5 Datasets) |   20     20  1.5s

## 7. 
julia --project=. demo.jl

## 8. 
julia --project=. tests/runtests.jl