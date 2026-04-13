# Task 8 — HW/SW Partition Proposal

## (a) Which kernel(s) will you accelerate in hardware, and why does the roofline support that choice?

The `zscore_detect` inner loop will be accelerated as a custom streaming dataflow
pipeline in Verilog. Profiling (Task 5) shows this kernel consumes 99.1% of total
runtime, executing 133 FLOPs per sample across the entire sensor stream. On the
laptop CPU the kernel's arithmetic intensity is only 0.496 FLOP/byte — well below
the ridge point of 1.95 — making it deeply memory-bound at 38.1 GFLOP/s
(Task 6–7). The roofline confirms that no amount of additional compute can help; the
bottleneck is DRAM bandwidth from repeatedly loading the 32-element sliding window.

A custom accelerator stores the window in an on-chip SRAM shift register, reducing
per-sample DRAM traffic from 268 bytes to just 12 bytes (8 bytes in for one new
sample, 4 bytes out for one flag). This raises the effective arithmetic intensity from
0.496 to 11.08 FLOP/byte, pushing the kernel past the ridge point into the
compute-bound regime on the accelerator's roofline.

## (b) What will the software baseline continue to handle?

The host CPU running Python will handle data generation, sensor stream I/O, accelerator
configuration (writing window size and threshold to config registers), result collection,
and accuracy reporting. These operations run once or infrequently and do not justify
hardware acceleration.

## (c) What interface bandwidth does your accelerator need?

At the target throughput of 50 GFLOP/s, the accelerator processes approximately
3.76e+08 samples per second (50 × 10⁹ / 133). Each sample needs 12 bytes of
interface traffic (8 in + 4 out), requiring roughly 4.5 GB/s. A PCIe Gen3 ×4
link (3.9 GB/s) would be marginal; PCIe Gen4 ×4 (7.9 GB/s) provides comfortable
headroom to avoid becoming interface-bound.

## (d) Is your kernel compute-bound or memory-bound, and will the accelerator change that?

On the current laptop CPU the kernel is **memory-bound** (AI = 0.496 < ridge =
1.95). The accelerator shifts it to **compute-bound** (AI = 11.08 > HW ridge =
0.10) because on-chip SRAM eliminates redundant DRAM window loads, making
arithmetic throughput the sole limiting factor.
