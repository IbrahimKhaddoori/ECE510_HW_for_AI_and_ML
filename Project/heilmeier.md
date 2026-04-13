# Heilmeier Questions — Z-Score Streaming Anomaly Detection Accelerator

## 1. What are you trying to do?

Design and implement a custom streaming hardware accelerator for real-time anomaly
detection using the z-score statistical method. The accelerator processes a continuous
stream of sensor readings (e.g., temperature, network traffic, industrial telemetry)
and flags samples whose z-score exceeds a configurable threshold, operating on a
sliding window of the most recent 32 samples. The target is a pure dataflow pipeline
in Verilog — no traditional CPU, no GPU, no cache hierarchy, no branch prediction —
that processes one sample per clock cycle at sustained throughput. A Python/NumPy
golden model and cocotb testbench provide HW/SW co-verification.

## 2. What are the limits of the current approach?

Profiling the Python/NumPy software baseline reveals that `zscore_detect`
consumes 99.1% of total runtime (11.062 s cumulative out of 11.157 s across 10
runs on 100,000 samples). The kernel performs 133 FLOPs per sample but transfers
268 bytes from DRAM per sample under no-reuse assumptions, yielding an arithmetic
intensity of only 0.496 FLOP/byte.

On the target laptop CPU (peak 150 GFLOP/s, 76.8 GB/s DRAM bandwidth, ridge
point 1.95 FLOP/byte), this places the kernel firmly in the memory-bound
regime. The attainable performance is approximately 38.1
GFLOP/s with only 25.4% of the CPU's peak compute because DRAM bandwidth is
saturated by the repeated loading of the 32-element sliding window for every sample.
No software optimization (vectorization, multithreading) can overcome this fundamental
bandwidth wall. For high-throughput sensor streams requiring millions of samples per
second, the CPU becomes the bottleneck.

## 3. What is your approach and why is it better?

The accelerator exploits the sliding-window structure to eliminate the DRAM bandwidth
bottleneck. The key insight from roofline analysis is that a 32-element
window (256 bytes in float64) fits trivially in on-chip SRAM. By maintaining the window
in a hardware shift register, each new sample requires only 12 bytes of off-chip
traffic (8 bytes in, 4 bytes out) instead of 268 bytes, raising the effective arithmetic
intensity from 0.496 to 11.08 FLOP/byte. This transforms the kernel from
memory-bound to compute-bound on the accelerator's roofline (HW ridge = 0.10
FLOP/byte).

The dataflow pipeline consists of:

1. A shift register holding the 32-sample window
2. An adder tree computing the running sum (for mean)
3. A multiply-accumulate stage for variance
4. A fixed-point square root approximation
5. A threshold comparator outputting the anomaly flag

Each stage completes in one pipeline stage, achieving one-sample-per-cycle throughput
with deterministic latency. The design uses fixed-point arithmetic and power-of-two
window sizes (W = 32) to replace divisions with bit-shifts, avoiding complex divider
hardware. The entire accelerator is estimated at 150–200 lines of Verilog, well-scoped
for a solo project.

The required interface bandwidth is approximately 4.5 GB/s,
achievable with a PCIe Gen4 ×4 link. Python serves as both the golden reference model
(NumPy) and the verification framework (cocotb testbench), enabling rigorous HW/SW
co-verification against the profiled software baseline.
