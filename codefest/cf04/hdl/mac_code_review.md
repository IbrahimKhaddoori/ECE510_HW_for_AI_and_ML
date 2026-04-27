# MAC Code Review — CLLM Deliverable

## LLM Identification

| File | LLM Model |
|------|-----------|
| `mac_llm_A.v` | Claude Sonnet 4.6 |
| `mac_llm_B.v` | GPT-4o |

---

## Compilation Results

### mac_llm_A.v (Claude Sonnet 4.6)

```
$ iverilog -g2012 -o mac_a.vvp mac_llm_A.v
```

No errors or warnings. Compiles cleanly.

### mac_llm_B.v (GPT-4o)

```
$ iverilog -g2012 -o mac_b.vvp mac_llm_B.v
```

No errors or warnings. Compiles cleanly.

---

## Simulation Results

Testbench sequence per spec: `[a=3, b=4]` for 3 cycles → assert `rst` → `[a=−5, b=2]` for 2 cycles.

### mac_llm_A.v (Claude Sonnet 4.6)

```
Phase 1: Reset
  Cycle 0: out = 0  [PASS]
Phase 2: a=3, b=4 for 3 cycles
  Cycle 1: out = 12  [PASS]
  Cycle 2: out = 24  [PASS]
  Cycle 3: out = 36  [PASS]
Phase 3: Assert reset
  Cycle 4: out = 0  [PASS]
Phase 4: a=-5, b=2 for 2 cycles
  Cycle 5: out = 502, expected -10  [FAIL]
  Cycle 6: out = 1004, expected -20  [FAIL]

=== Results: 5 PASS, 2 FAIL ===
SOME TESTS FAILED
```

**FAILS** on negative signed inputs. Produces 502 instead of −10.

### mac_llm_B.v (GPT-4o)

```
Phase 1: Reset
  Cycle 0: out = 0  [PASS]
Phase 2: a=3, b=4 for 3 cycles
  Cycle 1: out = 12  [PASS]
  Cycle 2: out = 24  [PASS]
  Cycle 3: out = 36  [PASS]
Phase 3: Assert reset
  Cycle 4: out = 0  [PASS]
Phase 4: a=-5, b=2 for 2 cycles
  Cycle 5: out = -10  [PASS]
  Cycle 6: out = -20  [PASS]

=== Results: 7 PASS, 0 FAIL ===
ALL TESTS PASSED
```

**PASSES** functionally, but contains non-synthesizable constructs (see issues below).

---

## Issues Found

### Issue 1: Missing `signed` keyword on ports (mac_llm_A.v) — Sign Extension Error

**(a) Offending lines (mac_llm_A.v, lines 7–9):**

```systemverilog
    input  logic [7:0]  a,
    input  logic [7:0]  b,
    output logic [31:0] out
```

**(b) Explanation:**

The ports `a`, `b`, and `out` are declared without the `signed` keyword. In SystemVerilog, `logic [7:0]` defaults to **unsigned**. When the testbench drives `a = -5`, the module receives the bit pattern `8'b1111_1011` and interprets it as unsigned 251. The multiplication becomes `251 × 2 = 502` instead of the correct `−5 × 2 = −10`. This is the classic **sign extension error** from the assignment's failure mode table: 8-bit signed operands are treated as unsigned, producing a wrong product that is then zero-extended (not sign-extended) into the 32-bit accumulator.

**(c) Corrected version:**

```systemverilog
    input  logic signed [7:0]  a,
    input  logic signed [7:0]  b,
    output logic signed [31:0] out
```

---

### Issue 2: Non-synthesizable `initial` block (mac_llm_B.v)

**(a) Offending lines (mac_llm_B.v, lines 12–14):**

```systemverilog
    initial begin
        out = 32'sd0;
    end
```

**(b) Explanation:**

The `initial` block is a simulation-only construct and is **not synthesizable** in standard ASIC or FPGA flows (except for FPGA register initialization in some vendor tools). The specification explicitly states: *"No initial blocks."* The synchronous reset inside the `always` block already handles initialization to zero, making this `initial` block redundant and non-compliant with the constraints.

**(c) Corrected version:**

Remove the `initial` block entirely:

```systemverilog
    // Delete lines 12–14: the synchronous reset handles initialization
```

---

### Issue 3: Wrong process type — `always` instead of `always_ff` (mac_llm_B.v)

**(a) Offending line (mac_llm_B.v, line 16):**

```systemverilog
    always @(posedge clk) begin
```

**(b) Explanation:**

The specification explicitly requires `always_ff`. The plain `always @(posedge clk)` is Verilog-2001 syntax. While functionally equivalent in simulation, `always_ff` provides compile-time enforcement that the block describes sequential (flip-flop) logic. If a designer accidentally writes combinational logic inside an `always_ff` block, the synthesizer will flag it as an error. This is a best practice for synthesizable RTL and is explicitly required by the spec.

**(c) Corrected version:**

```systemverilog
    always_ff @(posedge clk) begin
```

---

## Corrected Module: mac_correct.v

The corrected module combines fixes for all three issues:

1. Ports declared with `signed` keyword → correct sign extension
2. Uses `always_ff` → proper SystemVerilog sequential block
3. No `initial` block → fully synthesizable

### mac_correct.v simulation log

```
Phase 1: Reset
  Cycle 0: out = 0  [PASS]
Phase 2: a=3, b=4 for 3 cycles
  Cycle 1: out = 12  [PASS]
  Cycle 2: out = 24  [PASS]
  Cycle 3: out = 36  [PASS]
Phase 3: Assert reset
  Cycle 4: out = 0  [PASS]
Phase 4: a=-5, b=2 for 2 cycles
  Cycle 5: out = -10  [PASS]
  Cycle 6: out = -20  [PASS]

=== Results: 7 PASS, 0 FAIL ===
ALL TESTS PASSED
```

Compiles cleanly with `iverilog -g2012`. All outputs match expected values.

**Yosys synthesis:** Not available in this environment (optional per assignment).
