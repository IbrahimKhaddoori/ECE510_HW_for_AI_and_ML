# Critical path identification

## Critical path

The critical path runs through the MAC datapath inside `compute_core`, specifically during state `S_MAC`. The start point is the `acc0` accumulator register (one of 8 parallel 32-bit `$_DFF_P_` flip-flops). The end point is the same `acc0` register input (feedback loop: accumulate into self).

The logic stages along the critical path are:

1. **acc0 register output** (clk-to-Q): ~0.3 ns. The 32-bit accumulator value exits the flip-flop.
2. **Weight memory read mux tree**: ~3.5 ns. The weight address `wa0 = l_wbase + nbase*l_in + mac_idx` selects one of 1,352 weight bytes from the register-mapped SRAM. This is the deepest mux tree in the design (56,428 `$_MUX_` cells total, approximately 11-12 levels deep for a 1352-entry memory).
3. **8×8 signed multiplier**: ~2.5 ns. The `a_val` (current activation) is multiplied by the selected weight byte. This is an INT8×INT8→16-bit signed multiply, implemented using 2,430 `$_XOR_` cells and 1,143 `$_XNOR_` cells for partial product generation, plus carry-save adder trees.
4. **32-bit accumulator addition**: ~3.0 ns. The 16-bit product is sign-extended to 32 bits and added to the current accumulator value. This uses a 32-bit carry chain (lookahead carry units `$lcu` with `$_NAND_` and `$_NOR_` gates).
5. **State-dependent mux**: ~0.5 ns. A multiplexer selects whether to write the MAC result or other state outputs (bias, MSE) to the accumulator.
6. **DFF setup time**: ~0.3 ns.

Total estimated path delay: **10.1–12.0 ns**.

## Why it is the critical path

The MAC accumulate loop is the tightest feedback path in the design: the accumulator output feeds directly back into the adder input through the weight memory lookup and multiplier, all within a single clock cycle. Every other datapath (MSE computation ~8 ns, bias/scale/clamp ~6 ns, address calculation ~7 ns) is shorter because they involve fewer logic stages.

## What would shorten it

The most effective change would be **pipelining the MAC**: split the multiply and accumulate into two clock cycles by inserting a pipeline register between the multiplier output and the adder input. This would cut the critical path roughly in half (~6 ns), allowing the design to run at 160+ MHz. The cost is one extra cycle of latency per MAC step and slightly more complex control logic in the FSM. An alternative is replacing the register-mapped weight memory with a sky130 SRAM macro, which would eliminate the 3.5 ns mux tree and bring the path down to ~6.5 ns without pipelining.
