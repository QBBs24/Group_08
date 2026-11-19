# Group_08

# Test correctness
julia --project=. tests/test_correctness.jl

# Test benchmarks
julia --project tests/test_benchmark.jl

# Run jupyter notebook
jupyter notebook notebooks/demo.ipynb

# Run application 1
julia --project=. src/applications/market_basket.jl data/apps/Groceries_dataset.csv 0.002 0.10