# Arithmetic Intensity Calculation — Z-Score Anomaly Detection

## Dominant Kernel

The dominant kernel is `zscore_detect()`, identified via cProfile (Task 5). It accounts
for 99.1% of total runtime (11.062 s out of 11.157 s, 10 runs, 100,000 samples).

## Algorithm (the inner-loop update rule)

For each sample `x[i]` after the warm-up period, the kernel executes:

```
1.  window   = data[i-W : i]                        (extract sliding window)
2.  mean     = sum(window) / W                       (running mean)
3.  diff     = window - mean                         (element-wise subtract)
4.  variance = sum(diff * diff) / W                  (running variance)
5.  std      = sqrt(variance)                        (standard deviation)
6.  dev      = abs(x[i] - mean)                      (absolute deviation)
7.  z        = dev / std                             (z-score)
8.  flag     = 1 if z > threshold else 0             (anomaly decision)
```

Where `W` is the window size and all values are float64.

## FLOP Count — Analytical Derivation

### Formula (general, in terms of W)

| Operation Type   | Source Step          | Formula     | Count        |
|-----------------|----------------------|-------------|--------------|
| Additions        | Step 2: sum          | W − 1       | W − 1        |
| Divisions        | Step 2: divide       | 1           | 1            |
| Subtractions     | Step 3: diff         | W           | W            |
| Multiplications  | Step 4: diff²       | W           | W            |
| Additions        | Step 4: sum          | W − 1       | W − 1        |
| Divisions        | Step 4: divide       | 1           | 1            |
| Square roots     | Step 5: sqrt         | 1           | 1            |
| Subtractions     | Step 6: subtract     | 1           | 1            |
| Absolute values  | Step 6: abs          | 1           | 1            |
| Divisions        | Step 7: divide       | 1           | 1            |
| Comparisons      | Step 8: compare      | 1           | 1            |

Summing by operation type:

```
Additions:       (W − 1) + (W − 1) = 2W − 2
Subtractions:    W + 1              = W + 1
Multiplications: W                  = W
Divisions:       1 + 1 + 1          = 3
Square roots:    1
Absolute values: 1
Comparisons:     1
─────────────────────────────────────────────
Total FLOPs per sample = 2W − 2 + (W + 1) + W + 3 + 1 + 1 + 1
                       = 4W + 5
```

### Substituted values (W = 32)

```
Additions:        2(32) − 2      = 62
Subtractions:     32 + 1         = 33
Multiplications:  32             = 32
Divisions:        3              =  3
Square roots:     1              =  1
Absolute values:  1              =  1
Comparisons:      1              =  1
──────────────────────────────────────
Total FLOPs per sample           = 4(32) + 5 = 133
```

### Total FLOPs over the full run

```
Active samples = N − W = 100,000 − 32 = 99,968

Total FLOPs = active_samples × FLOPs_per_sample
            = 99,968 × 133
            = 13,295,744 FLOPs
            ≈ 13.30 MFLOP
```

## Bytes Transferred — No Reuse Assumption

Assuming every operand is loaded from DRAM and no value is cached or reused
across iterations:

| Data                 | What is loaded/stored                         | Formula             | Bytes    |
|---------------------|-----------------------------------------------|---------------------|----------|
| Load window          | 32 float64 values from the sliding window   | W × 8               | 256      |
| Load current sample  | 1 float64 value x[i]                         | 1 × 8               | 8        |
| Store flag           | 1 int32 anomaly flag                         | 1 × 4               | 4        |

### Full calculation

```
Bytes per sample = (W × 8) + (1 × 8) + (1 × 4)
                 = (32 × 8) + (1 × 8) + (1 × 4)
                 = 256 + 8 + 4
                 = 268 bytes

Total bytes = active_samples × bytes_per_sample
            = 99,968 × 268
            = 26,791,424 bytes
            ≈ 26.79 MB
```

## Arithmetic Intensity

```
AI = Total FLOPs / Total Bytes
   = FLOPs_per_sample / Bytes_per_sample
   = 133 / 268
   ≈ 0.496 FLOP/byte
```

## Summary

| Item                          | Value                |
|-------------------------------|----------------------|
| Dominant kernel               | zscore_detect()      |
| Window size (W)               | 32                   |
| FLOPs per sample              | 133                  |
| Bytes per sample (no reuse)   | 268                  |
| **Arithmetic intensity**      | **0.496 FLOP/byte**  |
