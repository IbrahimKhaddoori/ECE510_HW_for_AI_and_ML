# Benchmark results — SW baseline vs HW accelerator

## Test configuration

- Workload: Autoencoder forward pass (32→16→8→16→32) + MSE + threshold
- FLOPs per inference: 2,657 (1,280 MACs × 2 + 97 MSE)
- Test samples: 10,000

## Results table

| Metric | SW baseline (CPU) | HW accelerator (ASIC, projected) | Notes |
|--------|-------------------|----------------------------------|-------|
| Platform | Python 3.12 + NumPy, x86-64 CPU | sky130 ASIC (Yosys synthesis) | HW numbers projected from synthesis |
| Data type | FP32 (32-bit float) | INT8 (8-bit integer) | 4× smaller weights in HW |
| Clock | ~3.5 GHz (CPU turbo) | 83 MHz | 42× lower clock |
| Single-sample latency | 12.0 µs | 2.6 µs (projected) | HW is 4.7× faster |
| Batch throughput (10k) | 6,355,000 samples/sec | 389,671 samples/sec (projected) | SW wins via SIMD batching |
| Throughput (MFLOPS) | 16,885 | 1,035 (projected) | SW uses AVX2 vectorization |
| Memory footprint | 1,285,408 B (1.2 MB) | 1,385 B (1.4 KB) | HW uses 928× less memory |
| Weight storage | 5,408 B (FP32) | 1,352 B (INT8) | 4× compression |
| F1 score | 0.661 (FP32) | 0.672 (INT8 + QAT) | QAT improves INT8 accuracy |
| Power (estimated) | ~5–15 W (CPU package) | ~5–15 mW (projected) | ~1000× more efficient |
| Energy/inference (est.) | ~60–180 µJ | ~13–39 nJ (projected) | ~4600× more efficient |

## Speedup summary

| Metric | Speedup (HW / SW) |
|--------|-------------------|
| Single-sample latency | **4.7×** (12.0 µs → 2.6 µs) |
| Batch throughput | 0.06× (SW wins due to NumPy SIMD batching across 10k samples) |
| Memory efficiency | **928×** (1.2 MB → 1.4 KB) |
| Energy efficiency | **~4600×** (projected, based on estimated power) |

## Discussion

The HW accelerator wins decisively on single-sample latency (4.7×), memory footprint (928×), and energy efficiency (~4600×). These are the metrics that matter for edge deployment, where samples arrive one at a time from a sensor and power budget is constrained.

The SW baseline wins on batch throughput because NumPy leverages AVX2/AVX-512 SIMD instructions to process thousands of samples simultaneously through matrix multiplication — effectively a different kernel (batched GEMM) than the single-sample MVM the hardware performs. This comparison is inherently unfair to the HW design: the accelerator processes one sample at a time (matching the real-time sensor use case), while the SW baseline amortizes function-call overhead across 10,000 samples in a single NumPy matrix operation.

For the target application (real-time edge anomaly detection with one sensor sample at a time), the HW accelerator is the correct design choice: 4.7× lower latency, 928× less memory, and ~4600× better energy efficiency, at the cost of batch throughput that is irrelevant for the use case.

## Projection assumptions (HW numbers are PROJECTED, not measured)

All HW numbers are projected from synthesis results, not measured on silicon:
- Clock frequency: 83 MHz, derived from Yosys synthesis critical path analysis (12 ns period meets timing)
- Cycles per inference: 213 cycles, measured from Icarus Verilog co-simulation (tb_top.v)
- MAC utilization: assumed 100% during S_MAC state (no pipeline stalls)
- AXI interface: assumed no stalls (back-to-back sample streaming)
- Power: estimated from cell count and sky130 typical power figures, not from OpenSTA (OpenLane flow failed on Colab)
