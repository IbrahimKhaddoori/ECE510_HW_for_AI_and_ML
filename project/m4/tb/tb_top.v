// ============================================================================
// tb_trained_weights.v — End-to-End Test with Real QAT-Trained Weights
// ============================================================================
// Loads 1,352 trained INT8 weights from hex file, streams 8 real sensor
// samples (4 normal + 4 anomaly), and verifies anomaly flag matches
// the Python reference model. This proves the full pipeline:
//   Train in Python -> export INT8 weights -> load into chip -> correct inference
//
// Expected results (from Python hw_ref):
//   Sample 0 (normal):  MSE_q88 =    68, flag = 0
//   Sample 1 (normal):  MSE_q88 =    86, flag = 0
//   Sample 2 (normal):  MSE_q88 =   101, flag = 0
//   Sample 3 (normal):  MSE_q88 =    98, flag = 0
//   Sample 4 (anomaly): MSE_q88 = 11250, flag = 1
//   Sample 5 (anomaly): MSE_q88 = 11001, flag = 1
//   Sample 6 (anomaly): MSE_q88 = 11784, flag = 1
//   Sample 7 (anomaly): MSE_q88 = 11350, flag = 1
// ============================================================================
`timescale 1ns / 1ps

module tb_trained_weights;

    parameter N_WEIGHTS = 1352;
    parameter N_SAMPLES = 8;
    parameter THRESHOLD = 4836;

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

    reg [7:0] weights [0:N_WEIGHTS-1];
    reg [7:0] samples [0:N_SAMPLES*32-1];
    reg expected_flag [0:N_SAMPLES-1];

    integer i, j, cycle_count, pass_count, fail_count, sample_num;
    reg [31:0] result_data;
    reg got_flag;
    reg [15:0] got_mse;

    top dut (
        .clk(clk), .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .m_axis_tdata(m_axis_tdata), .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .cfg_addr(cfg_addr), .cfg_wdata(cfg_wdata),
        .cfg_wr_en(cfg_wr_en), .cfg_rdata(cfg_rdata), .cfg_rd_en(cfg_rd_en)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task cfg_write(input [3:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            cfg_addr <= addr; cfg_wdata <= data; cfg_wr_en <= 1'b1;
            @(posedge clk);
            cfg_wr_en <= 1'b0;
        end
    endtask

    task load_weight(input [10:0] addr, input [7:0] data);
        begin
            cfg_write(4'h0, {24'd0, data});
            cfg_write(4'h1, {21'd0, addr});
            cfg_write(4'h2, 32'd1);
        end
    endtask

    initial begin
        expected_flag[0] = 0; expected_flag[1] = 0;
        expected_flag[2] = 0; expected_flag[3] = 0;
        expected_flag[4] = 1; expected_flag[5] = 1;
        expected_flag[6] = 1; expected_flag[7] = 1;

        pass_count = 0; fail_count = 0;
        s_axis_tdata = 0; s_axis_tvalid = 0; m_axis_tready = 0;
        cfg_addr = 0; cfg_wdata = 0; cfg_wr_en = 0; cfg_rd_en = 0;

        $readmemh("trained_weights.hex", weights);
        $readmemh("test_samples.hex", samples);

        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        $display("============================================================");
        $display("  Trained Weight Integration Test");
        $display("  1,352 QAT-trained INT8 weights + 8 real sensor samples");
        $display("  Threshold = %0d (Q8.8)", THRESHOLD);
        $display("============================================================");

        $display("\n--- Loading %0d trained weights via config port ---", N_WEIGHTS);
        for (i = 0; i < N_WEIGHTS; i = i + 1)
            load_weight(i, weights[i]);
        $display("  Done.");

        $display("\n--- Setting threshold = %0d ---", THRESHOLD);
        cfg_write(4'h3, THRESHOLD);

        $display("\n--- Running %0d samples ---", N_SAMPLES);
        $display("  Sample | Type    | Flag | MSE(Q8.8) | Result");
        $display("  -------+---------+------+-----------+-------");

        for (sample_num = 0; sample_num < N_SAMPLES; sample_num = sample_num + 1) begin
            for (j = 0; j < 32; j = j + 1)
                s_axis_tdata[j*8 +: 8] = samples[sample_num * 32 + j];

            @(posedge clk);
            s_axis_tvalid <= 1'b1;
            @(posedge clk);
            while (!s_axis_tready) @(posedge clk);
            @(posedge clk);
            s_axis_tvalid <= 1'b0;

            m_axis_tready <= 1'b1;
            cycle_count = 0;
            while (!m_axis_tvalid && cycle_count < 10000) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
            end

            if (cycle_count >= 10000) begin
                $display("  %0d      | TIMEOUT |      |           | FAIL", sample_num);
                fail_count = fail_count + 1;
            end else begin
                result_data = m_axis_tdata;
                got_flag = result_data[0];
                got_mse = result_data[16:1];
                m_axis_tready <= 1'b0;
                @(posedge clk);

                if (got_flag == expected_flag[sample_num]) begin
                    $display("  %0d      | %s |  %0d   | %5d     | PASS",
                        sample_num,
                        (sample_num < 4) ? "NORMAL " : "ANOMALY",
                        got_flag, got_mse);
                    pass_count = pass_count + 1;
                end else begin
                    $display("  %0d      | %s |  %0d   | %5d     | FAIL (expected %0d)",
                        sample_num,
                        (sample_num < 4) ? "NORMAL " : "ANOMALY",
                        got_flag, got_mse, expected_flag[sample_num]);
                    fail_count = fail_count + 1;
                end
            end
        end

        $display("\n============================================================");
        $display("  Results: %0d passed, %0d failed out of %0d", pass_count, fail_count, N_SAMPLES);
        if (fail_count == 0)
            $display("  >>> PASS — Trained weights produce correct anomaly detection <<<");
        else
            $display("  >>> FAIL <<<");
        $display("============================================================");

        #100; $finish;
    end

    initial begin
        $dumpfile("trained_weights.vcd");
        $dumpvars(0, tb_trained_weights);
    end

endmodule
