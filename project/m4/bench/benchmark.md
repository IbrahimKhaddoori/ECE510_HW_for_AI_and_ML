# Benchmark Results — SW baseline vs HW accelerator

## Test configuration

- Workload: Autoencoder forward pass (32->16->8->16->32) + MSE + threshold
- FLOPs per inference: 2,657 (1,280 MACs x 2 + 97 MSE)
- Test samples: 10,000 (SW batch); 8 labelled samples in the RTL co-sim
- HW numbers are **measured from the completed OpenLane 2 signoff** (40 MHz typical
  corner) plus the measured 217-cycle count from the Icarus co-simulation.

## Results table

| Metric | SW baseline (CPU) | HW accelerator (sky130 ASIC) | Notes |
|--------|-------------------|------------------------------|-------|
| Platform | Python 3.12 + NumPy, x86-64 | sky130A ASIC, signed-off layout | HW = measured signoff |
| Data type | FP32 | INT8 | 4x smaller weights in HW |
| Clock | ~3.5 GHz | 40 MHz | closes at tt/ff; ss needs ~33 MHz |
| Single-sample latency | 12.0 us | 5.43 us | HW is 2.2x faster |
| Batch throughput (10k) | 6,355,000 samples/s | 184,332 samples/s | SW wins via SIMD batching |
| Throughput (MFLOPS) | 16,885 | 490 | SW uses AVX2 vectorization |
| Memory footprint | 1,285,408 B (1.2 MB) | 1,385 B (1.4 KB) | HW uses 928x less |
| Weight storage | 5,408 B (FP32) | 1,352 B (INT8) | 4x compression |
| F1 score | 0.661 (FP32) | 0.672 (INT8 + QAT) | QAT preserves accuracy |
| Total power | ~5-15 W (est.) | **0.269 W (measured)** | signoff power analysis |
| Energy/inference | ~60-180 uJ (est.) | **1.46 uJ (measured)** | HW = power x latency |
| Energy efficiency | -- | **1.8 GFLOPS/W** | measured signoff |

## Speedup summary

| Metric | HW vs SW |
|--------|----------|
| Single-sample latency | **2.2x** (12.0 us -> 5.43 us) |
| Batch throughput | 0.03x (SW wins via NumPy SIMD batching across 10k samples) |
| Memory efficiency | **928x** (1.2 MB -> 1.4 KB) |
| Energy efficiency | **~80x** (SW power estimated; HW 1.46 uJ measured) |

## Discussion

The accelerator wins on the metrics that matter for edge deployment: single-sample
latency (2.2x), memory footprint (928x), and energy per inference (~80x, with the
HW side now measured rather than estimated). These are the right figures of merit
for a real-time edge use case where one sensor sample arrives at a time and the
power budget is tight.

The SW baseline wins on batch throughput because NumPy uses AVX2/AVX-512 SIMD to
process thousands of samples at once as a batched GEMM — effectively a different
kernel than the single-sample matrix-vector product the hardware performs. This
comparison is inherently unfavourable to the accelerator, which processes one
sample at a time (matching the application), while the SW baseline amortizes
overhead across 10,000 samples in one matrix operation.

Note on power and energy: earlier milestones could only *estimate* HW power
(~5-15 mW) because the back-end flow never reached signoff. The completed signoff
gives a **measured** total of 0.269 W — substantially higher than that estimate,
driven by the large register-file weight memory and its read-mux fabric switching
every cycle. The corrected energy advantage over the SW baseline is therefore
~80x, not the ~4600x quoted in the earlier (estimate-based) draft. This correction
is itself a result of completing the physical flow.

## Roofline

Operational intensity (weights-stationary, weights resident on-chip; only the
32-byte input + 32-byte output stream off-chip per inference): 2,657 / 64
~= 42 FLOP/byte. Measured operating point: 0.49 GFLOPS at 42 FLOP/byte, against a
hardware compute roof of 0.64 GFLOPS (8 MACs x 2 x 40 MHz). The design is firmly
compute-bound and runs at ~77% of its compute roof. See bench/roofline_final.png.

## Operating-point caveat

All HW figures are at the nominal 40 MHz typical-corner operating point, where
power and signoff STA were computed. A conservative rating that holds across all
process corners would use the ~33 MHz slow-corner closing frequency: latency
~6.6 us, throughput ~152,000 samples/s, ~404 MFLOPS, power scaling roughly with
frequency.
