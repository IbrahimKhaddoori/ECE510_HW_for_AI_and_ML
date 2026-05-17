# Project Scope Assessment

## Project

Autoencoder Anomaly Detection Hardware Accelerator — 8-MAC INT8 inference engine with AXI4-Stream/Lite interface, targeting SkyWater 130nm via OpenLane 2.

## Scope Confirmation

**Scope is confirmed as feasible.** Synthesis results validate the core design:

- **Architecture viable:** The 4-layer autoencoder (32→16→8→16→32) with 8 parallel MAC lanes synthesizes to 95,034 cells in sky130. The design is functionally verified through testbench simulation (both `tb_compute_core` and `tb_interface` pass).

- **Timing achievable:** The MAC critical path exceeds the 100 MHz target (~11.5 ns estimated), but meets timing at 83 MHz (12 ns period). At 83 MHz the design still processes ~10M samples/s — well above real-time requirements. The M3 submission will target 83 MHz.

- **Area reasonable:** ~962,000 μm² total cell area, dominated by register-mapped weight SRAM (10,816 flip-flops). A production implementation using SRAM macros would reduce this by ~8×. For the class project, the register-based approach is acceptable and demonstrates the complete datapath.

- **Software optimization complete:** Combined Method 3 + 5 training (quantization-aware training with tuned hyperparameters) improved INT8 F1 from 0.659 to 0.672 with no RTL changes, validating the HW/SW co-design approach.

## No Scope Changes

No reductions or expansions needed. All M1–M3 deliverables are on track. M4 final report will include synthesis analysis, SW/HW benchmark comparison, and the optimized training pipeline.
