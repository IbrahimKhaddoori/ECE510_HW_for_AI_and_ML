// ============================================================================
// tb_interface.sv — Testbench for AXI4-Stream Interface Module
// ============================================================================
// Verification strategy:
//   1. Write threshold via config register port
//   2. Read back threshold via config register port → verify match
//   3. Send 32 warm-up samples via AXI4-Stream slave (TVALID/TREADY handshake)
//   4. Send a normal sample → read flag via AXI4-Stream master → expect 0
//   5. Send an anomaly sample → read flag via AXI4-Stream master → expect 1
// ============================================================================

`timescale 1ns / 1ps

module tb_interface;

    // ── Clock and reset ─────────────────────────────────────────────────
    reg         clk;
    reg         rst_n;

    // ── AXI4-Stream Slave (sensor input) ────────────────────────────────
    reg  [15:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;

    // ── AXI4-Stream Master (flag output) ────────────────────────────────
    wire [7:0]  m_axis_tdata;
    wire        m_axis_tvalid;
    reg         m_axis_tready;

    // ── Config register port ────────────────────────────────────────────
    reg  [3:0]  cfg_addr;
    reg  [31:0] cfg_wdata;
    reg         cfg_wr_en;
    wire [31:0] cfg_rdata;
    reg         cfg_rd_en;

    // ── Test bookkeeping ────────────────────────────────────────────────
    integer pass_count;
    integer fail_count;
    integer i;

    // ── Constants ───────────────────────────────────────────────────────
    localparam [15:0] VAL_10_0 = 16'd2560;   // 10.0 in Q8.8
    localparam [15:0] VAL_10_5 = 16'd2688;   // 10.5 in Q8.8
    localparam [15:0] VAL_25_0 = 16'd6400;   // 25.0 in Q8.8
    localparam [31:0] T_SQ_9   = 32'd589824; // 9.0 in Q16.16

    // ── DUT instantiation ───────────────────────────────────────────────
    zscore_interface dut (
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

    // ── Clock generation: 10 ns period (100 MHz) ────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Task: AXI4-Stream write (send one sample) ───────────────────────
    task axis_send(input [15:0] sample);
        begin
            @(posedge clk);
            s_axis_tdata  <= sample;
            s_axis_tvalid <= 1'b1;
            // Wait for handshake (TVALID && TREADY both high)
            @(posedge clk);
            while (!s_axis_tready) @(posedge clk);
            s_axis_tvalid <= 1'b0;
            @(posedge clk);
        end
    endtask

    // ── Task: AXI4-Stream read (receive flag) ───────────────────────────
    task axis_recv(output [7:0] flag_data);
        begin
            m_axis_tready <= 1'b1;
            // Wait for TVALID from master
            while (!m_axis_tvalid) @(posedge clk);
            flag_data = m_axis_tdata;
            @(posedge clk);
            m_axis_tready <= 1'b0;
        end
    endtask

    // ── Task: Config register write ─────────────────────────────────────
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

    // ── Task: Config register read ──────────────────────────────────────
    task cfg_read(input [3:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            cfg_addr  <= addr;
            cfg_rd_en <= 1'b1;
            @(posedge clk);
            data = cfg_rdata;
            cfg_rd_en <= 1'b0;
        end
    endtask

    // ── Main test sequence ──────────────────────────────────────────────
    reg [31:0] read_data;
    reg [7:0]  flag_out;

    initial begin
        // Initialise
        pass_count    = 0;
        fail_count    = 0;
        s_axis_tdata  = 16'd0;
        s_axis_tvalid = 1'b0;
        m_axis_tready = 1'b0;
        cfg_addr      = 4'd0;
        cfg_wdata     = 32'd0;
        cfg_wr_en     = 1'b0;
        cfg_rd_en     = 1'b0;

        // ── Reset ───────────────────────────────────────────────────────
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("============================================");
        $display("  tb_interface — AXI4-Stream Interface Test");
        $display("============================================");

        // ── Test 1: Config write transaction (threshold) ────────────────
        $display("\n--- Test 1: Config write (THRESHOLD_SQ = %0d) ---", T_SQ_9);
        cfg_write(4'h0, T_SQ_9);

        // ── Test 2: Config read transaction (verify write) ──────────────
        $display("--- Test 2: Config read (verify THRESHOLD_SQ) ---");
        cfg_read(4'h0, read_data);

        if (read_data == T_SQ_9) begin
            $display("  PASS: Read back %0d, expected %0d", read_data, T_SQ_9);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Read back %0d, expected %0d", read_data, T_SQ_9);
            fail_count = fail_count + 1;
        end

        // ── Warm-up: 32 samples via AXI4-Stream ────────────────────────
        $display("\n--- Warm-up: 32 AXI4-Stream write transactions ---");
        for (i = 0; i < 32; i = i + 1) begin
            if (i % 2 == 0)
                axis_send(VAL_10_0);
            else
                axis_send(VAL_10_5);
        end
        $display("Warm-up complete (32 handshakes verified).");
        pass_count = pass_count + 1;

        // ── Test 3: Normal sample → read flag ───────────────────────────
        $display("\n--- Test 3: AXI4-Stream write normal sample (10.0) ---");
        axis_send(VAL_10_0);
        axis_recv(flag_out);

        if (flag_out[0] == 1'b0) begin
            $display("  PASS: Normal sample → flag=0 (no anomaly)");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Normal sample → flag=1 (unexpected anomaly)");
            fail_count = fail_count + 1;
        end

        // ── Test 4: Anomaly sample → read flag ──────────────────────────
        $display("\n--- Test 4: AXI4-Stream write anomaly sample (25.0) ---");
        axis_send(VAL_25_0);
        axis_recv(flag_out);

        if (flag_out[0] == 1'b1) begin
            $display("  PASS: Anomaly sample → flag=1 (detected)");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Anomaly sample → flag=0 (missed)");
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

    // ── Waveform dump ───────────────────────────────────────────────────
    initial begin
        $dumpfile("interface.vcd");
        $dumpvars(0, tb_interface);
    end

endmodule
