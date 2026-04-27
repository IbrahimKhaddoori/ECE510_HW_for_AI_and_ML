`timescale 1ns / 1ps

module mac_tb;

    reg               clk;
    reg               rst;
    reg  signed [7:0] a;
    reg  signed [7:0] b;
    wire signed [31:0] out;

    // Instantiate DUT
    mac uut (
        .clk(clk),
        .rst(rst),
        .a(a),
        .b(b),
        .out(out)
    );

    // 10 ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    integer pass_count;
    integer fail_count;
    integer cycle;

    task check(input signed [31:0] expected, input integer cyc);
        begin
            if (out === expected) begin
                $display("  Cycle %0d: out = %0d  [PASS]", cyc, out);
                pass_count = pass_count + 1;
            end else begin
                $display("  Cycle %0d: out = %0d, expected %0d  [FAIL]", cyc, out, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("mac_tb.vcd");
        $dumpvars(0, mac_tb);

        pass_count = 0;
        fail_count = 0;

        // ---- Reset ----
        rst = 1; a = 0; b = 0;
        @(posedge clk); #1;
        $display("Phase 1: Reset");
        check(0, 0);

        // ---- Phase 2: a=3, b=4 for 3 cycles ----
        rst = 0;
        a = 8'sd3;
        b = 8'sd4;
        $display("Phase 2: a=3, b=4 for 3 cycles");

        @(posedge clk); #1; check(12, 1);
        @(posedge clk); #1; check(24, 2);
        @(posedge clk); #1; check(36, 3);

        // ---- Phase 3: Assert reset ----
        rst = 1;
        @(posedge clk); #1;
        $display("Phase 3: Assert reset");
        check(0, 4);

        // ---- Phase 4: a=-5, b=2 for 2 cycles ----
        rst = 0;
        a = -8'sd5;
        b = 8'sd2;
        $display("Phase 4: a=-5, b=2 for 2 cycles");

        @(posedge clk); #1; check(-10, 5);
        @(posedge clk); #1; check(-20, 6);

        // ---- Summary ----
        $display("");
        $display("=== Results: %0d PASS, %0d FAIL ===", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
