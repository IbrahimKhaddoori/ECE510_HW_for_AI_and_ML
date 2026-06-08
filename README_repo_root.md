# Hardware for Artificial Intelligence and Machine Learning (HW4AI) — ECE 410/510, Spring 2026

This repository contains a custom co-processor chiplet that accelerates an AI/ML
kernel relative to a software baseline. The chiplet is an **INT8 autoencoder
anomaly-detection accelerator**: it runs the forward pass of a four-layer
autoencoder (32→16→8→16→32) plus an MSE reconstruction-error threshold for
real-time anomaly detection on streaming sensor data. It uses a time-multiplexed
eight-MAC compute core with an AXI4-Stream data path and a configuration port for
weights and threshold, and targets the SkyWater **sky130A** open PDK. The design
was taken through the complete OpenLane 2 RTL-to-GDS flow: the final layout is
DRC- and LVS-clean, closes timing at 40 MHz at the typical and fast corners,
dissipates 0.269 W, and completes one inference in 5.43 µs.

## Final submission (Milestone 4)

The final M4 submission lives in [`project/m4/`](project/m4/) and is cataloged in
[`project/m4/README.md`](project/m4/README.md). The graded design justification
report — the nine-section write-up covering problem/motivation, roofline,
precision, architecture, interface, verification, synthesis, benchmark, and what
did not work — is at
[`project/m4/report/design_justification.pdf`](project/m4/report/design_justification.pdf).

Earlier deliverables remain in place under `project/` (`heilmeier.md`, `m1/`,
`m2/`, `m3/`); `project/m4/` is the authoritative final package and the basis for
the final examination.
