# Milestone 4 — Autoencoder Anomaly-Detection Accelerator

Custom INT8 co-processor that runs a 4-layer autoencoder (32→16→8→16→32) forward pass plus
MSE + threshold for real-time edge anomaly detection. 8-MAC time-multiplexed compute core,
AXI4-Stream data + config-port control, targeting the sky130A PDK.

**Language note:** RTL is plain Verilog (`.v`), which the instructor accepts in place of
SystemVerilog. Each `.v` file maps to the corresponding `.sv` slot in the M4 checklist
(`top.v`↔`top.sv`, etc.).

## How to reproduce

**Simulation (final_run.log):** Icarus Verilog 12.0.
```
cd project/m4/tb
iverilog -o /tmp/m4sim ../rtl/top.v ../rtl/interface.v ../rtl/compute_core.v tb_top.v
vvp /tmp/m4sim
```
Loads 1,352 trained INT8 weights + 8 sensor samples, streams them through the AXI interface,
compares the anomaly flag to the Python reference. Expected: `8 passed, 0 failed`.
(The `.hex` files live in `tb/` so the testbench is runnable from a clean clone.)

**Synthesis:** OpenLane 2 full RTL-to-GDS flow, sky130A, config in `synth/config.json`
(25 ns / 40 MHz, 1800×1800 µm die, 40% density). The flow completed to a signed-off GDS on a
29 GB environment (the free 13 GB tier was killed at post-route STA by a memory limit). The
`synth/` reports below are the **real signoff numbers** (area/timing/power from `final/metrics.json`).
Result: DRC-clean (Magic + KLayout), LVS-clean, closes timing at 40 MHz at the typical/fast
corners (slow corner needs ~33 MHz). Final layout: `top.gds`.

## File catalog

| File | Description | Supports | Status |
|------|-------------|----------|--------|
| `rtl/top.v` | Integrated top: instantiates interface + compute core | Checklist 2 / report §4 | ✅ verified |
| `rtl/compute_core.v` | 8-MAC core, FSM, bias/ReLU/MSE (signed-fix applied) | Checklist 2 / report §4 | ✅ verified |
| `rtl/interface.v` | AXI4-Stream + config-port interface | Checklist 2 / report §5 | ✅ verified |
| `tb/tb_top.v` | End-to-end test through interface vs Python reference | Checklist 2 / report §6 | ✅ 8/8 PASS |
| `tb/trained_weights.hex` | 1,352 QAT-trained INT8 weights | §3, §6 | ✅ |
| `tb/test_samples.hex` | 8 sensor samples (4 normal, 4 anomaly) | §6 | ✅ |
| `sim/final_run.log` | Sim transcript, 8/8 PASS | Checklist 2 / report §6 | ✅ regenerated |
| `sim/final_run.vcd` | Waveform dump (source for the annotated PNG) | — | ✅ |
| `sim/final_waveform.png` | End-to-end waveform (from VCD) | Checklist 2 | ✅ generated |
| `synth/config.json` | OpenLane 2 configuration (25 ns / 1800 µm / 40%) | Checklist 3 | ✅ real run |
| `synth/openlane_run.log` | OpenLane invocation log | Checklist 3 / report §7 | ⏳ **drop in real Kaggle log** |
| `synth/timing_report.txt` | Multi-corner WNS / slack / closing period | Checklist 3 / report §7 | ✅ real signoff |
| `synth/area_report.txt` | Total area µm² + cell counts | Checklist 3 / report §7 | ✅ real signoff |
| `synth/power_report.txt` | Measured power + energy/inference | Checklist 3 / report §7 | ✅ real signoff |
| `bench/benchmark.md` | HW vs SW summary, speedup vs M1 | Checklist 4 / report §8 | ✅ measured |
| `bench/benchmark_data.csv` | Raw measurements behind every number | Checklist 4 | ✅ measured |
| `bench/roofline_final.png` | Roofline with measured accelerator point | Checklist 4 / report §2 | ✅ measured |
| `report/design_justification_OUTLINE.md` | 9-section skeleton | report | ✅ outline only |
| `report/design_justification.pdf` | Final 9-section report | Checklist 5 | ⏳ **to assemble** |
| `report/figures/roofline_final.png` | Roofline figure (measured) | report §2 | ✅ |
| `report/figures/final_waveform.png` | Waveform figure | report §6 | ✅ |

## Remaining for M4 (in priority order)
1. **Design justification report PDF** — assemble from the outline + the drafted §7/§8/§9; 2,000–5,000 words, 9 distinct sections.
2. **Drop in the real `synth/openlane_run.log`** from the Kaggle run (the GDS/metrics are already captured).
3. **Block + dataflow diagrams** (Fig 1, Fig 2) for the report figures.
4. **Process:** add the top-level README pointer (below), then `git tag m4-submission && git push origin m4-submission`.

Done: real signoff area/timing/power, measured benchmark + roofline, end-to-end waveform, final GDS.

### Top-level README.md — paragraph to add at repo root
> **ECE 410/510 HW4AI Project — Autoencoder Anomaly-Detection Accelerator.**
> The final M4 submission is in [`project/m4/`](project/m4/), cataloged in
> [`project/m4/README.md`](project/m4/README.md). The design justification report is at
> [`project/m4/report/design_justification.pdf`](project/m4/report/design_justification.pdf).
