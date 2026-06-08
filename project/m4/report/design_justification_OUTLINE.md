# Design Justification Report — OUTLINE (draft → export to design_justification.pdf)

> ECE 410/510 HW4AI · Autoencoder Anomaly-Detection Accelerator
> Target length: 2,000–5,000 words. PDF is the graded artifact. Each figure must be referenced by number.
> The nine sections below are REQUIRED and must stay distinct (the grader counts them).

## 1. Problem and motivation
- Kernel being accelerated: 4-layer autoencoder forward pass (32→16→8→16→32) + MSE + threshold, for real-time edge anomaly detection on streaming sensor data.
- Why custom HW: single-sample, low-latency, low-power edge use case where batched CPU/GPU throughput is irrelevant.
- Cite M1 profiling numbers (dominant kernel = the linear-layer MACs). [pull exact % from M1]

## 2. Roofline analysis
- Arithmetic intensity of the MVM kernel (FLOPs/byte). 2,657 FLOPs/inference.
- Compute-bound vs memory-bound determination; where the bottleneck shifts.
- How it shaped the architecture (8-MAC width, weight-stationary-ish reuse).
- Figure: roofline_final.png (MEASURED accelerator point — 1,016 MFLOPS @ ~AI).

## 3. Precision and data format
- INT8 weights/activations, 32-bit accumulator, Q8.8 MSE.
- QAT quantization-error analysis; F1 0.661 (FP32) → 0.672 (INT8+QAT) shows accuracy preserved.
- Reference M2 precision document.

## 4. Dataflow and architecture
- Dataflow pattern actually implemented (state what the RTL does — time-multiplexed 8-MAC, weight memory, activation ping-pong). Do NOT claim a pattern the code doesn't implement.
- Compute engine (8 parallel MACs), memory hierarchy (weight SRAM 1,352 B, activation regs), datapath, FSM states incl. S_COPY.

## 5. Hardware interface
- AXI4-Stream (data) + AXI4-Lite-style config port (weights/threshold). Why chosen (M1 bandwidth analysis).
- Effective bandwidth at target throughput; whether design is interface-bound (quantify).

## 6. Verification
- Unit tbs (compute_core, interface) + end-to-end co-sim through the interface.
- Trained-weight test: 8/8 correct vs Python reference (4 normal < threshold, 4 anomaly > threshold). Reference sim/final_run.log + bench/benchmark_data.csv.
- Independent reference = Python INT8 model, not a prior DUT run.

## 7. Synthesis results
- Area (µm²), timing (WNS/slack, closing clock period), power estimate — WITH NUMBERS.
- Dominant contributor to each. Reference synth/ reports + critical path.
- [PENDING: needs real OpenLane run; current synth/ files are M3 Yosys estimates.]

## 8. Benchmark results
- Throughput/latency/energy vs M1 SW baseline. Speedup = 12.0 µs / 2.614 µs = 4.6×.
- Memory 928×, energy ~4600× (estimated). Explain measured-vs-theoretical gaps.
- Reference bench/benchmark.md + benchmark_data.csv.

## 9. What did not work
- The signed/unsigned BIAS_LANE bug: ACC >>> 7 silently became a LOGICAL shift because the
  unsigned concatenation operand made the whole expression unsigned; negative pre-activations
  saturated to 127 (neuron-0 inverted, neuron-6 correct). Found by simulation, fixed with $signed().
- The layer-transition race fixed by adding the S_COPY state (+4 cycles/inference, 213→217).
- OpenLane 2 full flow on Colab (Yosys/Verilator version conflict) — what was tried, what's next.
- MSE diff sign-extension fix.

---
### Figures to finalize and reference by number
- Fig 1: block diagram (host / AXI / chiplet boundary / compute engine / on-chip mem) — [TO CREATE]
- Fig 2: dataflow / FSM state diagram — [TO CREATE]
- Fig 3: roofline_final.png (measured point) — bench/roofline_final.png
- Fig 4: annotated end-to-end waveform — [capture from sim/final_run.vcd]
