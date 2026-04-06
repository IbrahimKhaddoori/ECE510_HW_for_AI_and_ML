# ResNet-18 Analysis

## Top 5 Layers by MAC Count

| Rank | Layer Name | MACs | Parameters |
|---|---|---:|---:|
| 1 | Conv2d: 1-1 | 118,013,952 | 9,408 |
| 2 | Conv2d: 3-1 | 115,605,504 | 36,864 |
| 3 | Conv2d: 3-4 | 115,605,504 | 36,864 |
| 4 | Conv2d: 3-7 | 115,605,504 | 36,864 |
| 5 | Conv2d: 3-10 | 115,605,504 | 36,864 |

Note: several convolution layers in ResNet-18 have the same MAC count, so tied layers may appear in a slightly different order depending on the profiling output.

---

## Arithmetic Intensity of the Most MAC-Intensive Layer

The most MAC-intensive layer is **Conv2d: 1-1**.

### Layer Summary

| Item | Value |
|---|---:|
| Layer Name | Conv2d: 1-1 |
| MACs | 118,013,952 |
| Parameters | 9,408 |
| Data Type | FP32 |
| Bytes per Value | 4 |

---

## Weight Memory

| Item | Value |
|---|---:|
| Parameters | 9,408 |
| Bytes per Parameter | 4 |
| **Weight Memory** | **37,632 bytes** |

\[
\text{Weight Memory} = 9{,}408 \times 4 = 37{,}632 \text{ bytes}
\]

---

## Activation Memory

### Unique Activation Sizes

| Tensor | Shape | Elements |
|---|---|---:|
| Input | 3 × 224 × 224 | 150,528 |
| Output | 64 × 112 × 112 | 802,816 |
| **Total** | — | **953,344** |

\[
\text{Activation Memory} = 953{,}344 \times 4 = 3{,}813{,}376 \text{ bytes}
\]

---

## Total Unique Memory Footprint

| Item | Bytes |
|---|---:|
| Weight Memory | 37,632 |
| Activation Memory | 3,813,376 |
| **Total Memory** | **3,851,008 bytes** |

\[
\text{Total Memory} = 37{,}632 + 3{,}813{,}376 = 3{,}851{,}008 \text{ bytes}
\]

---

## Arithmetic Intensity Calculation

The assignment says to assume **all weights and activations are loaded from DRAM with no reuse**.

### FLOPs

Each MAC = 2 FLOPs.

| Item | Value |
|---|---:|
| MACs | 118,013,952 |
| FLOPs per MAC | 2 |
| **Total FLOPs** | **236,027,904** |

\[
\text{Total FLOPs} = 2 \times 118{,}013{,}952 = 236{,}027{,}904
\]

### DRAM Traffic for Weights

With no reuse, each MAC loads one weight from DRAM.

| Item | Value |
|---|---:|
| Weight Loads | 118,013,952 |
| Bytes per Weight | 4 |
| **Weight Bytes** | **472,055,808 bytes** |

\[
\text{Weight Bytes} = 118{,}013{,}952 \times 4 = 472{,}055{,}808 \text{ bytes}
\]

### DRAM Traffic for Activations

With no reuse, each MAC loads one activation from DRAM.

| Item | Value |
|---|---:|
| Activation Loads | 118,013,952 |
| Bytes per Activation | 4 |
| **Activation Bytes** | **472,055,808 bytes** |

\[
\text{Activation Bytes} = 118{,}013{,}952 \times 4 = 472{,}055{,}808 \text{ bytes}
\]

### Total DRAM Traffic

| Item | Bytes |
|---|---:|
| Weight Bytes | 472,055,808 |
| Activation Bytes | 472,055,808 |
| **Total Bytes** | **944,111,616 bytes** |

\[
\text{Total Bytes} = 472{,}055{,}808 + 472{,}055{,}808 = 944{,}111{,}616 \text{ bytes}
\]

### Arithmetic Intensity Formula

\[
AI = \frac{2 \times \text{MACs}}{\text{weight bytes} + \text{activation bytes}}
\]

\[
AI = \frac{2 \times 118{,}013{,}952}{472{,}055{,}808 + 472{,}055{,}808}
\]

\[
AI = \frac{236{,}027{,}904}{944{,}111{,}616} = 0.25
\]

---

## Final Answer

| Result | Value |
|---|---:|
| **Arithmetic Intensity of Conv2d: 1-1** | **0.25 FLOPs/byte** |
