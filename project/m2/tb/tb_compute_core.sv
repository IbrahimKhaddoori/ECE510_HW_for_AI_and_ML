// ============================================================================
// tb_compute_core.sv — Testbench for Z-Score Anomaly Detector Compute Core
// ============================================================================
// Verification strategy:
//   1. Feed 32 warm-up samples (alternating 10.0 and 10.5 in Q8.8)
//   2. After warm-up, feed a normal sample (10.0) → expect NO anomaly
//   3. Feed an anomaly sample (25.0) → expect ANOMALY
//   Expected outputs computed independently from the Python golden model:
//     mean = 10.25 (Q8.8 = 2624), variance = 0.0625 (Q16.16 = 4096)
//     T² = 9.0 (Q16.16 = 589824)
//     Normal 10.0:  dev²=4096,     T²σ²=36864  → 4096 < 36864  → NO
//     Anomaly 25.0: dev²=14258176, T²σ²=36864  → 14258176 > 36864 → YES
// ============================================================================

`timescale 1ns / 1ps

module tb_compute_core;

    // ── Clock and reset ─────────────────────────────────────────────────
    reg         clk;
    reg         rst_n;

    // ── DUT signals ─────────────────────────────────────────────────────
    reg  signed [15:0] data_in;
    reg                data_valid;
    reg         [31:0] threshold_sq;
    wire               anomaly_flag;
    wire               flag_valid;
    wire               ready;

    // ── Test bookkeeping ────────────────────────────────────────────────
    integer pass_count;
    integer fail_count;
    integer i;

    // ── Q8.8 constants ──────────────────────────────────────────────────
    localparam signed [15:0] VAL_10_0 = 16'sd2560;   // 10.0 × 256
    localparam signed [15:0] VAL_10_5 = 16'sd2688;   // 10.5 × 256
    localparam signed [15:0] VAL_25_0 = 16'sd6400;   // 25.0 × 256
    localparam        [31:0] T_SQ_9   = 32'd589824;  // 9.0 × 65536

    // ── DUT instantiation ───────────────────────────────────────────────
    compute_core dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .data_in       (data_in),
        .data_valid    (data_valid),
        .threshold_sq  (threshold_sq),
        .anomaly_flag  (anomaly_flag),
        .flag_valid    (flag_valid),
        .ready         (ready)
    );

    // ── Clock generation: 10 ns period (100 MHz) ────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Helper task: send one sample and wait one cycle ─────────────────
    task send_sample(input signed [15:0] sample);
        begin
            @(posedge clk);
            data_in    <= sample;
            data_valid <= 1'b1;
            @(posedge clk);
            data_valid <= 1'b0;
            @(posedge clk);  // let output register
        end
    endtask

    // ── Main test sequence ──────────────────────────────────────────────
    initial begin
        // Initialise
        pass_count   = 0;
        fail_count   = 0;
        data_in      = 16'sd0;
        data_valid   = 1'b0;
        threshold_sq = T_SQ_9;

        // ── Reset ───────────────────────────────────────────────────────
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("============================================");
        $display("  tb_compute_core — Z-Score Anomaly Detector");
        $display("============================================");
        $display("Threshold T=3.0, T^2=9.0, Q16.16=%0d", T_SQ_9);

        // ── Warm-up: 32 samples alternating 10.0 and 10.5 ──────────────
        $display("\n--- Warm-up phase (32 samples) ---");
        for (i = 0; i < 32; i = i + 1) begin
            if (i % 2 == 0)
                send_sample(VAL_10_0);
            else
                send_sample(VAL_10_5);
        end
        $display("Warm-up complete.");

        // ── Test 1: Normal sample (10.0) → expect NO anomaly ────────────
        $display("\n--- Test 1: Normal sample 10.0 ---");
        send_sample(VAL_10_0);
        @(posedge clk);

        if (flag_valid) begin
            if (anomaly_flag == 1'b0) begin
                $display("  PASS: Normal sample correctly classified (flag=0)");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Normal sample incorrectly flagged (flag=1)");
                fail_count = fail_count + 1;
            end
        end else begin
            // Check registered output from previous cycle
            if (anomaly_flag == 1'b0) begin
                $display("  PASS: Normal sample correctly classified (flag=0)");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Normal sample incorrectly flagged (flag=1)");
                fail_count = fail_count + 1;
            end
        end

        // ── Test 2: Anomaly sample (25.0) → expect ANOMALY ──────────────
        $display("\n--- Test 2: Anomaly sample 25.0 ---");
        send_sample(VAL_25_0);
        @(posedge clk);

        if (anomaly_flag == 1'b1) begin
            $display("  PASS: Anomaly sample correctly detected (flag=1)");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Anomaly sample missed (flag=0)");
            fail_count = fail_count + 1;
        end

        // ── Test 3: Another normal sample (10.5) → expect NO anomaly ────
        $display("\n--- Test 3: Normal sample 10.5 ---");
        send_sample(VAL_10_5);
        @(posedge clk);

        if (anomaly_flag == 1'b0) begin
            $display("  PASS: Normal sample correctly classified (flag=0)");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Normal sample incorrectly flagged (flag=1)");
            fail_count = fail_count + 1;
        end

        // ── Summary ─────────────────────────────────────────────────────
        $display("\n============================================");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("  >>> PASS <<<");
        else
            $display("  >>> FAIL <<<");
        $display("============================================");

        #100;
        $finish;
    end

    // ── Optional: dump waveforms ────────────────────────────────────────
    initial begin
        $dumpfile("compute_core.vcd");
        $dumpvars(0, tb_compute_core);
    end

endmodule
