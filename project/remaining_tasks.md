# Remaining tasks before M4

## 1. Complete OpenLane place-and-route with sky130 liberty timing

Run the full OpenLane 2 flow using a Docker-based installation (not Colab's apt Yosys) to get actual post-route STA timing with sky130_fd_sc_hd liberty files. The current 83 MHz clock target is based on a pre-route estimate from generic Yosys synthesis; post-route wire delays through the 56,428-MUX weight memory read tree could add 1-3 ns, potentially requiring the clock to be relaxed to 70-75 MHz. The STA report will provide the actual worst negative slack and confirm or revise the clock target.

## 2. Run OpenSTA power estimation on the routed netlist

The M3 power report documents a failed attempt on Colab. For M4, run OpenSTA with the sky130_fd_sc_hd typical-corner liberty file on the post-synthesis netlist, using a SAIF or VCD activity file generated from the co-simulation (cosim.vcd, already produced by tb_top.v). This will replace the current rough estimate of 5-15 mW with a cell-level dynamic + leakage power breakdown, enabling a meaningful energy-per-inference comparison against the CPU baseline.

## 3. Implement double-buffering in ae_interface to overlap I/O with compute

The roofline analysis shows the design is interface-bound at 78% of peak compute. The current ae_interface blocks AXI4-Stream input (s_axis_tready goes low) while the compute core is running. Adding a second 256-bit input capture register would allow the next sample to be loaded via AXI4-Stream while the current sample is being processed, eliminating the I/O stall and pushing MAC utilization from 78% toward 95%+. This requires modifying the `running` flag logic in interface.v and adding a 32-byte ping-pong buffer (256 additional flip-flops).
