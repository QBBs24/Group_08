# Group_08

# Test correctness
julia --project=. tests/test_correctness.jl

# Test benchmarks
julia --project tests/test_benchmark.jl

# Run jupyter notebook
jupyter notebook notebooks/demo.ipynb