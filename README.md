# Group_08

## 1. Thành viên
- 24127278 - Hoàng Minh Huy
- 24127329 - Lê Nguyễn Quốc Bảo

## 2. Tài nguyên & Liên kết công khai

- Demo notebook (Google Colab): `https://colab.research.google.com/drive/1SmBrYj9_PNzfWb3edH-lgbGdXEz52YLF?usp=sharing`
- Báo cáo kỹ thuật (IEEE Format): `docs/Report.pdf`
- Nguồn dữ liệu:
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
├── Manifest.toml                     # File chứa các gói dependencies của project
├── requirements.txt                  # Thư viện Python hỗ trợ trực quan hóa trong Notebook
├── demo.jl                           # Chương trình chạy demo cả project
├── .gitignore                        # File cấu hình bỏ các file, thư mục không commit lên GitHub
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
├── results/
│   ├── app1/                         # Kết quả chạy của ứng dụng 1: Phân tích giỏ hàng (Market Basket Analysis)
│   ├── app2/                         # Kết quả chạy của ứng dụng 2: Khai thác mẫu trình tự gen Splice-Junction (DNA)
│   ├── benchmark/                    # Kết quả chạy của test_benchmark.jl, gồm 6 thực nghiệm
│   └── figures/                      # Các biểu đồ vẽ thể hiện kết quả chạy của dữ liệu, gồm biểu đồ của: ứng dụng 1, ứng dụng 2 và 6
│                                     # thực nghiệm benchmark
├── tests/
│   ├── runtests.jl                   # Kiểm thử tự động cho toàn bộ project
│   ├── test_correctness.jl           # Kiểm thử tự động đối chiếu 1-1 với SPMF trên 5 CSDL
│   └── test_benchmark.jl             # Bộ 6 thực nghiệm đánh giá hiệu năng, bộ nhớ và khả năng mở rộng
├── data/
│   ├── toy/                          # 5 CSDL nhỏ và kết quả chuẩn SPMF phục vụ unit test
│   ├── apps/                         # Dữ liệu cho Chương 3 (Groceries_dataset.csv, dna.csv)
│   └── benchmark/                    # Thư mục chứa 4 bộ benchmark lớn (tải từ link ở Mục 2)
├── notebooks/
│   ├── demo_GoogleColab.ipynb        # Notebook tổng hợp thực nghiệm và trực quan hóa chạy trên Google Colab
│   └── demo_local.ipynb              # Notebook tổng hợp thực nghiệm và trực quan hóa chạy trên local
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

### a1. Chương 1: Chạy bộ kiểm thử tự động (Unit Tests)

- Chạy `julia --project=. tests/runtests.jl`

### a2. Chạy sự chuẩn xác của thuật toán nhóm tự implement và thuật toán của spmf.jar (có nằm trong bộ kiểm thử tự động)

- Chạy `julia --project=. tests/test_correctness.jl`

### b. Chương 2: Chạy thực nghiệm Benchmark

- Đặt 4 file dữ liệu benchmark (chess.txt, mushrooms.txt, retail.txt, T10I4D100K.txt) vào data/benchmark/ (mặc định 4 file này đã có sẵn trong repo)
- Cần java nếu muốn chạy lại so sánh với SPMF. Mặc định kết quả của SPMF đã lưu trong data/benchmark/spmf_reference.
- Chạy `julia --project tests/test_benchmark.jl`
- Kết quả thực nghiệm được xuất tự động ra 4 tệp CSV trong thư mục results/benchmark/ (exp1_2_3_main.csv, exp4_memory.csv, exp5_scalability.csv, exp6_tx_length.csv).

### c. Chương 3: Ứng dụng

#### Chạy Ứng dụng 1 — Phân tích giỏ hàng (Market Basket Analysis)

- Cú pháp: *julia --project=. src/applications/market_basket.jl <đường_dẫn_csv> <minsup> <minconf>*
- Ví dụ nhóm đã chạy: `julia --project=. src/applications/market_basket.jl data/apps/Groceries_dataset.csv 0.002 0.07`
- Ví dụ kết quả đầu ra: Từ 14,963 giỏ hàng với 167 mặt hàng, hệ thống khai thác được 330 tập phổ biến và xuất bảng Top luật kết hợp theo chỉ số Lift (cao nhất là {curd} => {sausage} với Lift = 1.4466, Confidence = 8.73%) ra results/app1_top10_rules.csv.

#### Chạy Ứng dụng 2 — Khai thác mẫu trình tự DNA Splice-Junction

- Cú pháp: *julia --project=. src/applications/bio_mining.jl <đường_dẫn_dna_csv>*
- Ví dụ nhóm đã chạy: `julia --project=. src/applications/bio_mining.jl data/apps/dna.csv`
- Ví dụ kết quả đầu ra: Giải mã 3,186 chuỗi DNA 60 vị trí thành 240 đặc trưng (Vị_trí, Nucleotide) và khai thác các motif bảo thủ đặc trưng cho ranh giới Exon–Intron ({Pos31=G, Pos32=T} đạt 99.0% support) và Intron–Exon ({Pos29=A, Pos30=G} đạt 99.5% support).

### d. Mở Demo Notebook (local, chọn kernel Python 3)
- Chạy `jupyter notebook notebooks/demo_local.ipynb`

## 6. Kết quả chạy kiểm thử (Unit Test Output)

- Kết quả chạy lệnh `julia --project=. tests/runtests.jl` lần cuối trước khi nộp bài (Hàm runtests.jl gọi hàm cấp cao của ứng dụng 2 để test độ chính xác nên trong output có phần output của ứng dụng 2):
```
=== ỨNG DỤNG 2: KHAI THÁC MẪU TRÌNH TỰ GEN SPLICE-JUNCTION (DNA) ===
• Dữ liệu đầu vào : C:\Users\QUOCBA~1\AppData\Local\Temp\jl_hK1zWZ\synthetic_dna.csv (Tổng: 30 trình tự, 60 vị trí -> 240 items)

------------------------------------------------------------------------------------------
Class 1 - EI (Exon-Intron / Donor) | N = 10 | minsup = 0.8
• Tổng Frequent Itemsets: 3 (trong 0.0s) | Tổ hợp k >= 2: 1
Top  | Size   | Biological Position Pattern                          | Sup.Count  | Support 
------------------------------------------------------------------------------------------
1    | 2      | {Pos31=G, Pos32=T}                                   | 9          | 90.00%

------------------------------------------------------------------------------------------
Class 2 - IE (Intron-Exon / Acceptor) | N = 10 | minsup = 0.75
• Tổng Frequent Itemsets: 3 (trong 0.0s) | Tổ hợp k >= 2: 1
Top  | Size   | Biological Position Pattern                          | Sup.Count  | Support 
------------------------------------------------------------------------------------------
1    | 2      | {Pos29=A, Pos30=G}                                   | 8          | 80.00%

------------------------------------------------------------------------------------------
Class 3 - N (Neither / Control Group) | N = 10 | minsup = 0.5
• Tổng Frequent Itemsets: 0 (trong 0.0s) | Tổ hợp k >= 2: 0
  -> Không có tổ hợp vị trí nào vượt ngưỡng minsup = 0.5 (phân bố nền ngẫu nhiên ~25%).

Đã xuất toàn bộ dữ liệu giao dịch và bảng pattern sinh học vào: C:\Users\QUOCBA~1\AppData\Local\Temp\jl_hK1zWZ\results_app2
Test Summary:                                             | Pass  Total  Time
Group_08 — Toàn bộ Unit Test (Core Eclat + App 1 + App 2) |   52     52  5.1s
```

## 7. Chạy demo project

## a. Chạy demo cho cả project
- Chạy `julia --project=. demo.jl`

## b. Chạy demo cho các app riêng lẻ
- Cú pháp chung: *julia --project=. demo.jl --app <tên_app> --minsup <min_sup> <đường_dẫn_đến_file_data>*
- Ví dụ 1: `julia --project=. demo.jl --app core --minsup 0.75 data/benchmark/chess.txt`
- Ví dụ 2: `julia --project=. demo.jl --app app1`
- Ví dụ 3: `julia --project=. demo.jl --app app2`