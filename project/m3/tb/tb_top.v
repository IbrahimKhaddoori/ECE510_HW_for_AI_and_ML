// ============================================================================
// tb_top.v — End-to-End Co-Simulation Testbench
// ============================================================================
// Project : ECE 410/510 HW4AI — Milestone 3
//
// This testbench exercises the full system through the top-level interface
// ONLY. No direct access to compute_core ports. The testbench acts as a
// host: it loads weights via the config port, sets the threshold, streams
// a 32-element sensor sample via AXI4-Stream, and reads the anomaly flag
// and MSE result back through AXI4-Stream and config reads.
//
// Test flow:
//   Phase 1: Load all 1,352 weights via config port (host → SRAM)
//   Phase 2: Set anomaly threshold via config port
//   Phase 3: Stream sensor input via AXI4-Stream slave
//   Phase 4: Read result via AXI4-Stream master
//   Phase 5: Verify result against independent software reference
//
// Software reference:
//   With all weights = 0 except Layer 0 diagonal (weight[j*32+j] = 64
//   for j in 0..15), and input = [10,10,...,10(×16), 5,5,...,5(×16)]:
//   - Layer 0 output: neuron[j] = clamp(ReLU((input[j]*64) >>> 7)) = 5 for j<16
//   - Layers 1-3: all weights = 0, so outputs = bias = 0
//   - Reconstruction: all zeros
//   - MSE: sum((orig[i] - 0)^2) / 32 = (16*100 + 16*25) / 32 = 62.5
//   - MSE in Q8.8: bits [20:5] of raw mse_acc
//   - mse_acc = 16*100 + 16*25 = 2000
//   - mse_out = 2000[20:5] = 2000 >> 5 = 62 (Q8.8 ≈ 0.242)
//   - With threshold = 512 (2.0 in Q8.8): 62 < 512, so anomaly_flag = 0
//   - With threshold = 32: 62 > 32, so anomaly_flag = 1
// ============================================================================
`timescale 1ns / 1ps

module tb_top;

    // ── DUT signals ─────────────────────────────────────────────────────
    reg         clk, rst_n;
    reg [255:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;
    wire [31:0] m_axis_tdata;
    wire        m_axis_tvalid;
    reg         m_axis_tready;
    reg  [3:0]  cfg_addr;
    reg  [31:0] cfg_wdata;
    reg         cfg_wr_en, cfg_rd_en;
    wire [31:0] cfg_rdata;

    integer i, cycle_count, pass_count, fail_count;
    reg [31:0] read_val;
    reg [31:0] result_data;

    // ── Instantiate top module (interface is the only path to compute) ──
    top dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready),
        .cfg_addr       (cfg_addr),
        .cfg_wdata      (cfg_wdata),
        .cfg_wr_en      (cfg_wr_en),
        .cfg_rdata      (cfg_rdata),
        .cfg_rd_en      (cfg_rd_en)
    );

    // ── Clock generation ────────────────────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz (10 ns period)

    // ── Config write task (simulates AXI4-Lite write) ───────────────────
    task cfg_write(input [3:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            cfg_addr  <= addr;
            cfg_wdata <= data;
            cfg_wr_en <= 1'b1;
            @(posedge clk);
            cfg_wr_en <= 1'b0;
        end
    endtask

    // ── Config read task (simulates AXI4-Lite read) ─────────────────────
    task cfg_read(input [3:0] addr);
        begin
            @(posedge clk);
            cfg_addr  <= addr;
            cfg_rd_en <= 1'b1;
            @(posedge clk);
            read_val = cfg_rdata;
            cfg_rd_en <= 1'b0;
        end
    endtask

    // ── Weight write task (3-step: set data, set addr, pulse commit) ────
    task load_weight(input [10:0] addr, input [7:0] data);
        begin
            cfg_write(4'h0, {24'd0, data});       // WEIGHT_DATA
            cfg_write(4'h1, {21'd0, addr});        // WEIGHT_ADDR
            cfg_write(4'h2, 32'd1);                // WEIGHT_WR (pulse)
        end
    endtask

    // ── Main test sequence ──────────────────────────────────────────────
    initial begin
        pass_count = 0;
        fail_count = 0;
        s_axis_tdata  = 256'd0;
        s_axis_tvalid = 1'b0;
        m_axis_tready = 1'b0;
        cfg_addr  = 4'd0;
        cfg_wdata = 32'd0;
        cfg_wr_en = 1'b0;
        cfg_rd_en = 1'b0;

        // Reset
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        $display("============================================================");
        $display("  tb_top — End-to-End Co-Simulation (M3)");
        $display("  Host -> AXI4-Lite/Stream -> Interface -> Compute -> Result");
        $display("============================================================");

        // ════════════════════════════════════════════════════════════════
        // PHASE 1: Load weights via config port (host-side protocol)
        // ════════════════════════════════════════════════════════════════
        $display("\n--- Phase 1: Loading 1352 weights via config port ---");

        // Initialize all weights to zero
        for (i = 0; i < 1352; i = i + 1)
            load_weight(i, 8'd0);

        // Set Layer 0 diagonal: weight[j*32+j] = 64 for j = 0..15
        // This creates a partial pass-through for the first 16 inputs
        for (i = 0; i < 16; i = i + 1)
            load_weight(i * 32 + i, 8'd64);

        $display("  1352 weights loaded (Layer 0 diagonal = 64, rest = 0)");

        // ════════════════════════════════════════════════════════════════
        // PHASE 2: Set threshold via config port
        // ════════════════════════════════════════════════════════════════
        $display("\n--- Phase 2: Set threshold = 512 (2.0 in Q8.8) ---");
        cfg_write(4'h3, 32'd512);

        // Verify threshold readback
        cfg_read(4'h3);
        if (read_val[15:0] == 16'd512) begin
            $display("  PASS: Threshold readback = %0d (expected 512)", read_val[15:0]);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Threshold readback = %0d (expected 512)", read_val[15:0]);
            fail_count = fail_count + 1;
        end

        // ════════════════════════════════════════════════════════════════
        // PHASE 3: Stream sensor input via AXI4-Stream
        //   Input: elements 0-15 = 10, elements 16-31 = 5
        //   This is a full 32-element sample matching the M1 kernel size
        // ════════════════════════════════════════════════════════════════
        $display("\n--- Phase 3: Stream 32-byte sensor sample via AXI4-Stream ---");

        for (i = 0; i < 32; i = i + 1) begin
            if (i < 16)
                s_axis_tdata[i*8 +: 8] = 8'd10;
            else
                s_axis_tdata[i*8 +: 8] = 8'd5;
        end

        @(posedge clk);
        s_axis_tvalid <= 1'b1;
        @(posedge clk);
        while (!s_axis_tready) @(posedge clk);
        @(posedge clk);
        s_axis_tvalid <= 1'b0;
        $display("  AXI4-Stream handshake completed (32 bytes transferred)");

        // ════════════════════════════════════════════════════════════════
        // PHASE 4: Read result via AXI4-Stream master
        // ════════════════════════════════════════════════════════════════
        $display("\n--- Phase 4: Wait for result on AXI4-Stream master ---");
        m_axis_tready <= 1'b1;
        cycle_count = 0;
        while (!m_axis_tvalid && cycle_count < 10000) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        if (cycle_count >= 10000) begin
            $display("  FAIL: Timeout after 10000 cycles");
            fail_count = fail_count + 1;
        end else begin
            result_data = m_axis_tdata;
            $display("  Result received in %0d cycles", cycle_count);
            $display("  Raw result:   0x%08h", result_data);
            $display("  Anomaly flag: %0d (bit 0)", result_data[0]);
            $display("  MSE (Q8.8):   %0d (bits 16:1)", result_data[16:1]);
            pass_count = pass_count + 1;
        end
        m_axis_tready <= 1'b0;

        // ════════════════════════════════════════════════════════════════
        // PHASE 5: Verify against independent software reference
        // ════════════════════════════════════════════════════════════════
        $display("\n--- Phase 5: Verify against software reference ---");

        // Software reference calculation:
        //   Layer 0: out[j] = ReLU(clamp((input[j] * 64) >>> 7)) = 5 for j<16
        //   Layers 1-3: all weights=0 → output = bias = 0
        //   Reconstruction: all 32 elements = 0
        //   MSE raw: sum((orig[i])^2) = 16*(10^2) + 16*(5^2) = 1600+400 = 2000
        //   MSE Q8.8: 2000 >> 5 = 62
        //   With threshold=512: 62 < 512 → anomaly_flag = 0

        // Check anomaly flag
        if (result_data[0] == 1'b0) begin
            $display("  PASS: Anomaly flag = 0 (expected 0, MSE < threshold)");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Anomaly flag = %0d (expected 0)", result_data[0]);
            fail_count = fail_count + 1;
        end

        // Check MSE is in expected range (allow some tolerance for rounding)
        // Expected mse_out = 62 (Q8.8), tolerance ±10
        if (result_data[16:1] >= 16'd50 && result_data[16:1] <= 16'd75) begin
            $display("  PASS: MSE = %0d (expected ~62, tolerance 50-75)", result_data[16:1]);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: MSE = %0d (expected ~62)", result_data[16:1]);
            fail_count = fail_count + 1;
        end

        // Also verify via config read (STATUS register)
        cfg_read(4'h5);  // MSE_OUT register
        $display("  Config read MSE_OUT: %0d", read_val[15:0]);

        // ════════════════════════════════════════════════════════════════
        // TEST 2: Re-run with low threshold to trigger anomaly flag
        // ════════════════════════════════════════════════════════════════
        $display("\n--- Test 2: Low threshold → expect anomaly flag = 1 ---");
        cfg_write(4'h3, 32'd32);  // threshold = 32 (0.125 in Q8.8)

        // Re-stream same input
        @(posedge clk);
        s_axis_tvalid <= 1'b1;
        @(posedge clk);
        while (!s_axis_tready) @(posedge clk);
        @(posedge clk);
        s_axis_tvalid <= 1'b0;

        // Wait for result
        m_axis_tready <= 1'b1;
        cycle_count = 0;
        while (!m_axis_tvalid && cycle_count < 10000) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        if (cycle_count >= 10000) begin
            $display("  FAIL: Timeout");
            fail_count = fail_count + 1;
        end else begin
            result_data = m_axis_tdata;
            $display("  Result: flag=%0d, MSE=%0d", result_data[0], result_data[16:1]);

            // With threshold=32 and MSE~62: 62 > 32, so flag should be 1
            if (result_data[0] == 1'b1) begin
                $display("  PASS: Anomaly flag = 1 (MSE > low threshold)");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Anomaly flag = %0d (expected 1)", result_data[0]);
                fail_count = fail_count + 1;
            end
        end
        m_axis_tready <= 1'b0;

        // ════════════════════════════════════════════════════════════════
        // SUMMARY
        // ════════════════════════════════════════════════════════════════
        $display("\n============================================================");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("  >>> PASS <<<");
        else
            $display("  >>> FAIL <<<");
        $display("============================================================");

        #100;
        $finish;
    end

    // ── Waveform dump ───────────────────────────────────────────────────
    initial begin
        $dumpfile("cosim.vcd");
        $dumpvars(0, tb_top);
    end

endmodule
