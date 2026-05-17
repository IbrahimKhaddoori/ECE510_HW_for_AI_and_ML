# Synthesis Interpretation — compute_core.v

## Clock and Timing

Target clock period: **10.0 ns (100 MHz)**, set in `config.json` via `CLOCK_PERIOD: 10.0`, synthesized against the SkyWater 130nm (`sky130A`) PDK. The design was synthesized using Yosys 0.9 with `SYNTH_STRATEGY: AREA 0`. Given the 95,034 total cells and the combinational depth of the 8×8→16-bit signed multiply plus 32-bit accumulate chain in `S_MAC`, the critical path is tight. The estimated worst-case slack is approximately **−1.5 to −2.0 ns**, meaning the critical path runs roughly 11.5–12.0 ns — exceeding the 10 ns budget. The design would meet timing at approximately **83–87 MHz** with a 12 ns clock period.

## Critical Path

The critical path runs through the **MAC datapath** in state `S_MAC`: from the `acc0..acc7` register outputs through the 8×8 signed multiplier (`a_val × weight_mem[waX]`), into the 32-bit accumulate adder (`acc + product`), and back to the accumulator register input. The dominant cells along this path are `nand2_1` (18,165 instances — used for carry logic in multipliers and adders), `xnor2_1` (1,358 — partial products), `maj3_1` (313 — carry-save adders), and `a21oi_1` (6,509 — adder carry chain). The weight memory address computation (`l_wbase + nbase*l_in + mac_idx`) also contributes combinational depth feeding the multiplier inputs.

## Area

Total cell count: **95,034 instances**, of which **11,901 are flip-flops** (10,816 `dfxtp_1` + 1,085 `dfrtp_1`). Estimated total cell area: **~962,000 μm²**. The configured die area is 600×600 = 360,000 μm², which is undersized — utilization exceeds 100%, indicating the `DIE_AREA` needs to be increased to approximately 1,400×1,400 μm for 50% utilization. Top three area contributors: flip-flops (`dfxtp_1` at 232,220 μm², 24% — dominated by the 1,352-byte weight SRAM mapped to registers), 2:1 muxes (`mux2_1` at 123,117 μm², 13% — weight memory and activation array read muxing), and NAND gates (`nand2_1` at 92,097 μm², 10% — multiplier and adder logic).

## Warnings

The weight memory (`reg [7:0] weight_mem [0:1351]`) synthesized to **10,816 flip-flops** with massive mux trees (10,934 `mux2_1` + 3,543 `mux4_2`) because Yosys maps `reg` arrays to individual registers rather than SRAM macros. This inflates area by roughly 8× compared to a design using a sky130 SRAM macro. The `DIE_AREA` constraint is violated — place-and-route would fail at the current 600×600 μm setting. No hold violations are expected at this stage since clock tree synthesis has not been run.
