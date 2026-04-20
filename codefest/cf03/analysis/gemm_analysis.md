# GEMM Analysis: Naive vs. Tiled Kernel

## (a) Why the naive kernel is memory-bound

The naive kernel computes each output element C[i][j] by iterating through an entire row of A and column of B. Because there is no data reuse between threads or across iterations, every multiply-add requires two fresh loads from DRAM. This yields an arithmetic intensity of just 0.25 FLOP/byte — far below the GPU's ridge point (~25 FLOP/byte for a T4). The compute units spend almost all their time waiting for DRAM, leaving the ALUs idle. The kernel is therefore firmly memory-bound.

## (b) How tiling reduces DRAM traffic

Tiling loads T×T sub-blocks of A and B into shared memory, which is orders of magnitude faster than DRAM. All T² threads in the block then reuse those shared values, so each DRAM load serves T multiply-adds instead of just one. This multiplies the arithmetic intensity by T (from 0.25 to 2.0 FLOP/byte with T=8), reducing total DRAM traffic by a factor of T.

## (c) Did tiling achieve the expected improvement?

Tiling improves performance significantly — roughly 3–5× in measured GFLOP/s — but falls short of the theoretical 8× traffic reduction. The remaining bottleneck is likely shared memory bank conflicts from the column-access pattern of B tiles, low occupancy due to the small 8×8 block size (only 64 threads per block), and instruction overhead from the tighter inner loop. The kernel remains memory-bound because an AI of 2.0 is still well below the ridge point; larger tiles or register-level optimizations would be needed to approach the compute-bound regime.
