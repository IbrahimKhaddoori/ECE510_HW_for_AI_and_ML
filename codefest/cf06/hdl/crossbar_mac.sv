// =============================================================================
// crossbar_mac.sv
// 4x4 Binary-Weight Crossbar MAC Unit
//
// Each clock cycle computes: out[j] = sum_i weight[i][j] * in[i]
// Weights are +1 or -1, stored as 1-bit (0 = +1, 1 = -1).
// Inputs are 8-bit signed. Outputs are 11-bit signed accumulators.
// =============================================================================

module crossbar_mac (
    input  wire        clk,
    input  wire        rst_n,

    // Weight programming interface
    input  wire        wr_en,
    input  wire [1:0]  wr_row,
    input  wire [1:0]  wr_col,
    input  wire        wr_weight,      // 0 = +1, 1 = -1

    // Data path
    input  wire signed [7:0]  in0, in1, in2, in3,
    input  wire               valid_in,
    output reg  signed [10:0] out0, out1, out2, out3,
    output reg                valid_out
);

    // Weight storage: 4x4 array, 0 = +1, 1 = -1
    reg w [0:3][0:3];

    // Sign-extended inputs (11-bit)
    wire signed [10:0] sin0 = {{3{in0[7]}}, in0};
    wire signed [10:0] sin1 = {{3{in1[7]}}, in1};
    wire signed [10:0] sin2 = {{3{in2[7]}}, in2};
    wire signed [10:0] sin3 = {{3{in3[7]}}, in3};

    // Weighted products for each column
    wire signed [10:0] p0_0 = w[0][0] ? -sin0 : sin0;
    wire signed [10:0] p1_0 = w[1][0] ? -sin1 : sin1;
    wire signed [10:0] p2_0 = w[2][0] ? -sin2 : sin2;
    wire signed [10:0] p3_0 = w[3][0] ? -sin3 : sin3;

    wire signed [10:0] p0_1 = w[0][1] ? -sin0 : sin0;
    wire signed [10:0] p1_1 = w[1][1] ? -sin1 : sin1;
    wire signed [10:0] p2_1 = w[2][1] ? -sin2 : sin2;
    wire signed [10:0] p3_1 = w[3][1] ? -sin3 : sin3;

    wire signed [10:0] p0_2 = w[0][2] ? -sin0 : sin0;
    wire signed [10:0] p1_2 = w[1][2] ? -sin1 : sin1;
    wire signed [10:0] p2_2 = w[2][2] ? -sin2 : sin2;
    wire signed [10:0] p3_2 = w[3][2] ? -sin3 : sin3;

    wire signed [10:0] p0_3 = w[0][3] ? -sin0 : sin0;
    wire signed [10:0] p1_3 = w[1][3] ? -sin1 : sin1;
    wire signed [10:0] p2_3 = w[2][3] ? -sin2 : sin2;
    wire signed [10:0] p3_3 = w[3][3] ? -sin3 : sin3;

    integer i, j;

    // Weight programming
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 4; i = i + 1)
                for (j = 0; j < 4; j = j + 1)
                    w[i][j] <= 1'b0;
        end else if (wr_en) begin
            w[wr_row][wr_col] <= wr_weight;
        end
    end

    // MAC computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out0      <= 11'sd0;
            out1      <= 11'sd0;
            out2      <= 11'sd0;
            out3      <= 11'sd0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                out0 <= p0_0 + p1_0 + p2_0 + p3_0;
                out1 <= p0_1 + p1_1 + p2_1 + p3_1;
                out2 <= p0_2 + p1_2 + p2_2 + p3_2;
                out3 <= p0_3 + p1_3 + p2_3 + p3_3;
            end
        end
    end

endmodule
