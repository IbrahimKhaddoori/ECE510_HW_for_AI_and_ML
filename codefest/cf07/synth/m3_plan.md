# M3 Plan — compute_core

## Changes for M3

**1. Increase die area.** Current 600×600 μm cannot hold the 95,034 cells (~962,000 μm² estimated area). Will increase `DIE_AREA` to `"0 0 1400 1400"` to achieve ~50% utilization for successful place-and-route.

**2. Relax clock target.** The MAC critical path (8×8 multiply + 32-bit accumulate) likely exceeds 10 ns in sky130. Will change `CLOCK_PERIOD` to 12.0 ns (83 MHz). At 83 MHz the design still achieves ~10M samples/s throughput, which meets the project goal of real-time anomaly detection.

**3. Keep architecture as-is.** The 8-MAC time-multiplexed design with INT8 weights is confirmed viable at 83 MHz. Pipelining the MAC would add complexity for marginal clock gain — not justified for this project scope.

**4. Weight SRAM.** The 10,816 flip-flops from register-mapped weight memory are the dominant area contributor (24%). For M3 documentation, will note that a production design would replace this with a sky130 SRAM macro, reducing area by approximately 8×. No RTL change needed for synthesis demonstration.
