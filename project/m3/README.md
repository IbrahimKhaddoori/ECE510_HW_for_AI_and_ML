# Milestone 3 — Autoencoder Anomaly Detection Accelerator

## File catalog

| Path | Description |
|------|-------------|
| `rtl/top.v` | Integrated top module: instantiates ae_interface (which contains compute_core). All host communication goes through the interface — no direct compute_core access. |
| `rtl/interface.v` | AXI4-Stream/Lite interface module from M2. Handles sensor input streaming, config register access, and result output. |
| `rtl/compute_core.v` | 8-MAC INT8 compute core from M2. 4-layer autoencoder forward pass, MSE, threshold compare. |
| `tb/tb_top.v` | End-to-end co-simulation testbench. Drives the top module through host-side AXI4-Stream/Lite ports only. Loads weights, sets threshold, streams sensor data, reads result, verifies against independent software reference. |
| `sim/cosim_run.log` | Co-simulation transcript from Icarus Verilog 12.0. Shows all 5 checks passing with PASS verdict. |
| `sim/cosim_waveform.png` | Annotated waveform showing: (1) host-side weight loading via config port, (2) AXI4-Stream sensor input, (3) internal compute activity (213 cycles), (4) host-side result read. |
| `synth/config.json` | OpenLane 2 configuration: top module, 12 ns clock (83 MHz), sky130A PDK, 1400×1400 µm die area. |
| `synth/openlane_run.log` | OpenLane 2 run log. Documents the Verilator/Yosys version failure on Google Colab. |
| `synth/timing_report.txt` | Timing analysis estimate: critical path ~10.1-12.0 ns through MAC datapath, meets timing at 83 MHz. |
| `synth/area_report.txt` | Cell statistics from Yosys synthesis: 95,027 total cells, 11,902 flip-flops, 56,428 MUX cells. |
| `synth/critical_path.md` | Critical path identification: acc register → weight mux tree → 8×8 multiplier → 32-bit adder → acc register. Includes explanation of why it is critical and what would shorten it. |
| `synth/power_report.txt` | Power estimation attempt: documents Colab tool failure, provides rough estimate (5-15 mW dynamic), and plan for M4. |
| `synthesis_notes.md` | Narrative document (≥500 words): what synthesized, what failed, critical path analysis, co-sim results, scope confirmation. |

## How to reproduce the co-simulation

**Simulator:** Icarus Verilog 12.0 (`iverilog` 12.0-2build2 on Ubuntu 24.04)

**Command:**
```bash
cd project/m3
iverilog -o cosim_test rtl/top.v rtl/interface.v rtl/compute_core.v tb/tb_top.v
vvp cosim_test
```

**Expected output:** 5 passed, 0 failed, PASS verdict. Co-simulation completes in ~86.6 ms simulated time.

**Dependencies:** None beyond Icarus Verilog. No preprocessing required.

## How to reproduce the synthesis

**OpenLane 2 version:** pip install openlane (2024.x), requires Yosys ≥ 0.23 and Verilator ≥ 5.0.

**Standalone Yosys synthesis (used for this submission due to Colab tool constraints):**
```bash
yosys -p "
  read_verilog rtl/top.v rtl/interface.v rtl/compute_core.v;
  synth -top top;
  stat;
  write_verilog gate_netlist.v
"
```

**Full OpenLane flow (requires Docker or correct Nix environment):**
```bash
cd project/m3/synth
openlane config.json
```

**Environment:** Google Colab (Ubuntu, Yosys 0.9 via apt). Full OpenLane flow requires Docker-based installation with bundled Yosys/Verilator for complete STA and power analysis.
