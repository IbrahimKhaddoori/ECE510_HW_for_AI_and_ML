# Interface Selection — Z-Score Streaming Anomaly Detection Accelerator

## Chosen Interface

**PCIe Gen4 ×4**

## Host Platform

The assumed host is a **laptop / desktop-class x86-64 CPU** (e.g., Intel Core
i7-12700H) running Linux. The host executes the Python software baseline,
generates or receives the sensor data stream, writes configuration registers
(window size W, anomaly threshold), and collects the anomaly flags returned by
the accelerator. The chiplet connects to the host via a PCIe Gen4 ×4 endpoint.

## Bandwidth Requirement Calculation

The accelerator's target compute throughput is 50 GFLOP/s (from the roofline
analysis, where the HW design point sits at the compute-bound ceiling). Each
sample requires 133 FLOPs (see `ai_calculation.md`), so the required sample
throughput is:

```
Sample rate = 50 × 10⁹ FLOP/s  ÷  133 FLOP/sample
            = 3.759 × 10⁸ samples/sec
            ≈ 375.9 Msamples/sec
```

Each sample requires the following interface traffic:

| Direction | Data               | Width    | Bytes |
|-----------|--------------------|----------|-------|
| Host → HW | One new sample    | float64  | 8     |
| HW → Host | One anomaly flag  | int32    | 4     |
| **Total** |                    |          | **12**|

Required interface bandwidth:

```
BW_required = 375.9 × 10⁶ samples/sec  ×  12 bytes/sample
            = 4.511 × 10⁹ bytes/sec
            ≈ 4.5 GB/s
```

## Interface Rated Bandwidth Comparison

| Interface     | Rated Bandwidth | Meets Requirement? |
|---------------|----------------:|:------------------:|
| SPI           | ~10 MB/s        | No                 |
| I²C           | ~3.4 MB/s       | No                 |
| AXI4-Lite     | ~1 GB/s (typ)   | No                 |
| AXI4 Stream   | ~4 GB/s (256b@125MHz) | Marginal     |
| PCIe Gen3 ×4  | 3.94 GB/s       | No (marginal)      |
| **PCIe Gen4 ×4** | **7.88 GB/s** | **Yes**           |
| PCIe Gen4 ×8  | 15.75 GB/s      | Yes (overkill)     |
| UCIe          | >40 GB/s        | Yes (overkill)     |

## Bottleneck Analysis

The required bandwidth of **4.5 GB/s** is well below the PCIe Gen4 ×4 rated
bandwidth of **7.88 GB/s**, leaving approximately 43% headroom. This means
the design is **not interface-bound** on the roofline.

On the accelerator's roofline (peak = 50 GFLOP/s, on-chip SRAM BW = 500 GB/s),
the kernel's effective arithmetic intensity with on-chip window storage is
11.08 FLOP/byte, which is well above the HW ridge point of 0.10 FLOP/byte.
The interface does not create a new roofline ceiling because:

```
Interface-imposed ceiling = BW_interface × AI_effective
                          = 7.88 GB/s × 11.08 FLOP/byte
                          = 87.3 GFLOP/s  >>  50 GFLOP/s (HW peak)
```

Therefore, the PCIe Gen4 ×4 interface provides sufficient bandwidth with
comfortable margin. The accelerator remains **compute-bound**, not
interface-bound.

## Why Not Other Interfaces?

**SPI / I²C:** Orders of magnitude too slow for a 375 Msample/sec stream. These
are suitable for configuration registers but not data transport.

**AXI4-Lite:** Designed for register-mapped control, not high-throughput
streaming. Would bottleneck the pipeline severely.

**AXI4 Stream:** Could theoretically meet the requirement at wide bus widths and
high clock rates, but is typically an on-chip fabric protocol (FPGA internal),
not a host-to-accelerator interconnect. Appropriate if targeting an FPGA SoC
with the host soft-core on the same die.

**PCIe Gen3 ×4:** At 3.94 GB/s rated, it falls below the 4.5 GB/s requirement,
making the design interface-bound. Gen4 is the minimum viable generation.

**UCIe:** Provides far more bandwidth than needed and implies a chiplet-to-chiplet
packaging topology that is beyond the scope of this project.

## Summary

| Parameter                     | Value              |
|-------------------------------|--------------------|
| Chosen interface              | PCIe Gen4 ×4       |
| Rated bandwidth               | 7.88 GB/s          |
| Required bandwidth            | 4.5 GB/s           |
| Headroom                      | ~43%               |
| Interface-bound?              | No                 |
| Host platform                 | Laptop x86-64 CPU  |
