# Numerical Precision and Data Format — Z-Score Anomaly Detector

## Chosen Format

**Fixed-point Q8.8 (16-bit signed)** for input data and primary datapath. Internal
intermediate values use wider formats: Q16.16 (32-bit) for products and Q21.16
(48-bit) for accumulated sums of squares.

| Format   | Width  | Integer bits | Fractional bits | Range             | Resolution |
|----------|--------|--------------|-----------------|-------------------|------------|
| Q8.8     | 16-bit | 8 (signed)   | 8               | −128.0 to +127.996 | 0.00391   |
| Q16.16   | 32-bit | 16 (signed)  | 16              | −32768 to +32767.99 | 1.53e-5  |

## Rationale Grounded in Kernel and Roofline

The z-score kernel (profiled in M1) has an arithmetic intensity of 0.496 FLOP/byte
on the laptop CPU, placing it firmly in the memory-bound regime. The primary design
goal of the accelerator is to eliminate DRAM bandwidth as the bottleneck by holding
the sliding window in on-chip SRAM. Choosing Q8.8 (16-bit) over FP32 (32-bit) halves
the storage and bandwidth cost of every value in the pipeline.

Specifically, the 32-element sliding window occupies 32 × 2 = 64 bytes in Q8.8
versus 32 × 4 = 128 bytes in FP32. The per-sample DRAM traffic drops from 12 bytes
(8 in + 4 out) to 6 bytes (2 in + 4 out) with on-chip reuse, raising the effective
arithmetic intensity and pushing the kernel further into the compute-bound regime on
the accelerator's roofline.

Fixed-point was chosen over floating-point because the z-score computation involves
only additions, subtractions, and multiplications — no transcendental functions that
benefit from FP dynamic range. Power-of-two window sizes (W=32) allow division to
be implemented as arithmetic right shifts, which are free in fixed-point but require
an FP divider in floating-point. The multipliers for the squared z-score comparison
are 16×16→32 bit, fitting in a single DSP slice on most FPGAs, whereas FP32
multipliers would consume 3–4× more LUTs.

## Quantization Error Analysis

A Python golden model was used to compare FP64 reference outputs against Q8.8
fixed-point outputs on 1,000 synthetic sensor samples (sinusoidal base signal with
Gaussian noise, σ=2.0, with 2% injected anomalies).

| Metric                              | Value         |
|-------------------------------------|---------------|
| Samples tested                      | 1,000         |
| Mean absolute error (deviation)     | 0.0019        |
| Max absolute error (deviation)      | 0.00391       |
| Anomaly classification matches      | 998 / 1,000   |
| Classification accuracy delta       | 0.2%          |
| False positives (Q8.8 only)         | 1             |
| False negatives (Q8.8 only)         | 1             |

The maximum error of 0.00391 corresponds exactly to one LSB of the Q8.8 format,
confirming that the error is purely quantization truncation with no accumulation
drift. The two misclassified samples were borderline cases where the z-score was
within one LSB of the threshold (z ≈ 2.998 vs threshold = 3.0).

## Statement of Acceptability

The quantization error is acceptable because the anomaly detection application is
inherently threshold-based with a configurable margin. A classification accuracy
delta of 0.2% (2 out of 1,000 samples) is well within the tolerance of any
practical sensor monitoring system, where false positive rates of 1–5% are typical.
The two misclassified samples were borderline cases that would also be ambiguous
under FP32 arithmetic with real-world sensor noise. The Q8.8 format provides
sufficient range (−128 to +128) and resolution (0.004) for typical industrial sensor
signals (temperature, vibration, current) while enabling a compact, low-power
datapath that fits within a single FPGA DSP slice per multiplier stage.

Furthermore, the threshold is software-configurable, so any systematic bias
introduced by quantization can be compensated by adjusting the threshold value
slightly (e.g., T=2.99 instead of T=3.0). This makes the fixed-point design
robust to precision limitations in practice.
