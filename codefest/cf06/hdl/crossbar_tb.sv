`timescale 1ns / 1ps

module crossbar_tb;

    reg         clk;
    reg         rst_n;
    reg         wr_en;
    reg  [1:0]  wr_row;
    reg  [1:0]  wr_col;
    reg         wr_weight;
    reg  signed [7:0] in0, in1, in2, in3;
    reg                valid_in;
    wire signed [10:0] out0, out1, out2, out3;
    wire               valid_out;

    crossbar_mac dut (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .wr_row(wr_row), .wr_col(wr_col), .wr_weight(wr_weight),
        .in0(in0), .in1(in1), .in2(in2), .in3(in3),
        .valid_in(valid_in),
        .out0(out0), .out1(out1), .out2(out2), .out3(out3),
        .valid_out(valid_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Weight encoding: 0 = +1, 1 = -1
    // w[row][col]
    // Row 0: [+1, -1, +1, -1] -> [0, 1, 0, 1]
    // Row 1: [+1, +1, -1, -1] -> [0, 0, 1, 1]
    // Row 2: [-1, +1, +1, -1] -> [1, 0, 0, 1]
    // Row 3: [-1, -1, -1, +1] -> [1, 1, 1, 0]
    reg wt [0:3][0:3];
    initial begin
        wt[0][0]=0; wt[0][1]=1; wt[0][2]=0; wt[0][3]=1;
        wt[1][0]=0; wt[1][1]=0; wt[1][2]=1; wt[1][3]=1;
        wt[2][0]=1; wt[2][1]=0; wt[2][2]=0; wt[2][3]=1;
        wt[3][0]=1; wt[3][1]=1; wt[3][2]=1; wt[3][3]=0;
    end

    integer i, j, pass_count;

    initial begin
        $dumpfile("crossbar_mac.vcd");
        $dumpvars(0, crossbar_tb);

        rst_n=0; wr_en=0; wr_row=0; wr_col=0; wr_weight=0;
        valid_in=0; in0=0; in1=0; in2=0; in3=0;

        repeat(3) @(posedge clk); #1; rst_n=1;

        $display("--------------------------------------------");
        $display(" Programming weights");
        $display("--------------------------------------------");
        for (i=0; i<4; i=i+1) begin
            for (j=0; j<4; j=j+1) begin
                @(posedge clk); #1;
                wr_en=1; wr_row=i[1:0]; wr_col=j[1:0]; wr_weight=wt[i][j];
                $display("  weight[%0d][%0d] = %s", i, j, wt[i][j] ? "-1" : "+1");
            end
        end
        @(posedge clk); #1; wr_en=0;

        @(posedge clk); #1;
        in0=8'sd10; in1=8'sd20; in2=8'sd30; in3=8'sd40;
        valid_in=1;
        $display("--------------------------------------------");
        $display(" Applying inputs: [10, 20, 30, 40]");
        $display("--------------------------------------------");

        @(posedge clk); #1; valid_in=0;
        @(posedge clk); #1;

        $display("--------------------------------------------");
        $display(" Results");
        $display("--------------------------------------------");
        pass_count=0;

        $display("  out[0] = %0d  (expected -40) %s", out0, (out0==-40)?"PASS":"FAIL");
        if (out0==-40) pass_count=pass_count+1;
        $display("  out[1] = %0d  (expected 0) %s",   out1, (out1==0)?"PASS":"FAIL");
        if (out1==0)   pass_count=pass_count+1;
        $display("  out[2] = %0d  (expected -20) %s", out2, (out2==-20)?"PASS":"FAIL");
        if (out2==-20) pass_count=pass_count+1;
        $display("  out[3] = %0d  (expected -20) %s", out3, (out3==-20)?"PASS":"FAIL");
        if (out3==-20) pass_count=pass_count+1;

        $display("--------------------------------------------");
        if (pass_count==4)
            $display(" ALL 4 OUTPUTS MATCH - TEST PASSED");
        else
            $display(" %0d/4 OUTPUTS MATCHED - TEST FAILED", pass_count);
        $display("--------------------------------------------");

        repeat(3) @(posedge clk);
        $finish;
    end
endmodule
