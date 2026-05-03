# Milestone 2 — Z-Score Streaming Anomaly Detection Accelerator

## Simulator

All simulations were run with **Icarus Verilog (iverilog)** version 12.0 on
Ubuntu 22.04.4 LTS (x86-64). Waveforms were captured as VCD files and viewed
with GTKWave 3.3.118.

## How to Reproduce

### Prerequisites

```bash
sudo apt install iverilog gtkwave
```

No Python pre/post-processing is required to run the testbenches. The expected
values are embedded in the testbench header comments, computed independently
from the Python/NumPy golden model.

### Compute Core Testbench

```bash
cd project/m2

# Compile and run
iverilog -g2012 -o sim/compute_core_sim rtl/compute_core.sv tb/tb_compute_core.sv
vvp sim/compute_core_sim | tee sim/compute_core_run.log

# View waveform (optional)
gtkwave compute_core.vcd &
```

Expected output: `>>> PASS <<<` (3 passed, 0 failed)

### Interface Testbench

```bash
cd project/m2

# Compile and run (interface instantiates compute_core, so include both RTL files)
iverilog -g2012 -o sim/interface_sim rtl/compute_core.sv rtl/interface.sv tb/tb_interface.sv
vvp sim/interface_sim | tee sim/interface_run.log

# View waveform (optional)
gtkwave interface.vcd &
```

Expected output: `>>> PASS <<<` (4 passed, 0 failed)

## Deviation from M1 Plan

### Interface Change: PCIe Gen4 ×4 → AXI4-Stream

The M1 interface selection (`project/m1/interface_selection.md`) chose **PCIe
Gen4 ×4** based on the host-to-accelerator bandwidth analysis (4.5 GB/s
required, 7.88 GB/s rated). For M2, the RTL implements **AXI4-Stream** as the
data transport protocol instead.

**Rationale:** PCIe is a host-level interconnect protocol with a complex
transaction layer (TLPs, credit-based flow control, configuration space) that
would require thousands of lines of RTL to implement correctly — far beyond
the scope of a solo project milestone. In practice, FPGA-based accelerator
designs use a vendor-supplied PCIe IP core (e.g., Xilinx XDMA) that bridges
PCIe transactions to on-chip AXI4-Stream. The compute pipeline only ever sees
AXI4-Stream data.

Therefore, the M2 RTL implements the **on-chip transport layer** (AXI4-Stream)
that the compute core would use in a real system, while the M1 bandwidth
analysis for the **host interconnect** (PCIe Gen4 ×4) remains valid and
unchanged. The two protocols are complementary, not contradictory:

```
Host CPU ──[PCIe Gen4 ×4]──► FPGA PCIe IP ──[AXI4-Stream]──► compute_core
                                (vendor IP)                   (our RTL)
```

The AXI4-Stream implementation honours the TVALID/TREADY handshake contract
per ARM IHI 0051A §2.2.1, and provides a register-mapped configuration port
for threshold and control registers.

No other deviations from the M1 plan were made. The kernel scope (z-score
streaming anomaly detection), window size (W=32), and numerical precision
(Q8.8 input, Q16.16 internal) are unchanged.

## File Manifest

| Path | Description |
|------|-------------|
| `rtl/compute_core.sv` | Z-score compute core, synthesizable SystemVerilog |
| `rtl/interface.sv` | AXI4-Stream wrapper + config registers |
| `tb/tb_compute_core.sv` | Compute core testbench (3 tests) |
| `tb/tb_interface.sv` | Interface testbench (4 tests, AXI4-Stream + config) |
| `sim/compute_core_run.log` | Compute core simulation transcript (PASS) |
| `sim/interface_run.log` | Interface simulation transcript (PASS) |
| `sim/waveform.png` | Annotated waveform showing warm-up → normal → anomaly |
| `precision.md` | Q8.8 format rationale + quantization error analysis |
| `README.md` | This file |
