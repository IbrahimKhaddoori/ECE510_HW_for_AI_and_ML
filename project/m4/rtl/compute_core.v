// ============================================================================
// compute_core.v — Autoencoder Inference Compute Core (Plain Verilog)
// ============================================================================
// Project : ECE 410/510 HW4AI — Autoencoder Anomaly Detection Accelerator
//
// 8-MAC time-multiplexed forward pass for 4-layer autoencoder:
//   Layer 0: Linear(32->16)+ReLU  Layer 1: Linear(16->8)+ReLU
//   Layer 2: Linear(8->16)+ReLU   Layer 3: Linear(16->32)
// Then MSE + threshold comparison.
//
// Format: INT8 signed weights/activations, 32-bit accumulator, Q8.8 MSE.
// Clock:  Single (clk), posedge. Reset: Active-low async (rst_n).
//
// Ports:
//   clk, rst_n, start, input_data[255:0] (32xINT8 packed),
//   weight_wr_en, weight_wr_addr[10:0], weight_wr_data[7:0],
//   threshold[15:0], anomaly_flag, done, mse_out[15:0]
// ============================================================================

module compute_core (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [255:0] input_data,
    input  wire         weight_wr_en,
    input  wire [10:0]  weight_wr_addr,
    input  wire [7:0]   weight_wr_data,
    input  wire [15:0]  threshold,
    output reg          anomaly_flag,
    output reg          done,
    output reg  [15:0]  mse_out
);

    localparam S_IDLE=3'd0, S_LOAD=3'd1, S_MAC=3'd2, S_BIAS=3'd3, S_MSE=3'd4, S_DONE=3'd5, S_COPY=3'd6;

    // Weight SRAM
    reg [7:0] weight_mem [0:1351];
    always @(posedge clk) begin
        if (weight_wr_en) weight_mem[weight_wr_addr] <= weight_wr_data;
    end

    // Activation storage
    reg [7:0] act_in  [0:31];
    reg [7:0] act_out [0:31];
    reg [7:0] orig_in [0:31];

    // 8 accumulators (explicit, no unpacked array)
    reg signed [31:0] acc0, acc1, acc2, acc3, acc4, acc5, acc6, acc7;

    // State
    reg [2:0]  state;
    reg [1:0]  cur_layer;
    reg [2:0]  cur_round;
    reg [5:0]  mac_idx;
    reg [5:0]  mse_idx;
    reg [31:0] mse_acc;

    // Layer config (combinational)
    reg [5:0]  l_in, l_out;
    reg [10:0] l_wbase, l_bbase;
    reg        l_relu;
    reg [2:0]  l_rounds;

    always @(*) begin
        case (cur_layer)
            2'd0: begin l_in=32; l_out=16; l_wbase=0;   l_bbase=512;  l_relu=1; l_rounds=2; end
            2'd1: begin l_in=16; l_out=8;  l_wbase=528; l_bbase=656;  l_relu=1; l_rounds=1; end
            2'd2: begin l_in=8;  l_out=16; l_wbase=664; l_bbase=792;  l_relu=1; l_rounds=2; end
            default: begin l_in=16; l_out=32; l_wbase=808; l_bbase=1320; l_relu=0; l_rounds=4; end
        endcase
    end

    wire [5:0] nbase = {cur_round, 3'b000};
    wire signed [7:0] a_val = act_in[mac_idx];

    // Weight addresses (8 lanes)
    wire [10:0] wa0=l_wbase+(nbase+0)*l_in+mac_idx;
    wire [10:0] wa1=l_wbase+(nbase+1)*l_in+mac_idx;
    wire [10:0] wa2=l_wbase+(nbase+2)*l_in+mac_idx;
    wire [10:0] wa3=l_wbase+(nbase+3)*l_in+mac_idx;
    wire [10:0] wa4=l_wbase+(nbase+4)*l_in+mac_idx;
    wire [10:0] wa5=l_wbase+(nbase+5)*l_in+mac_idx;
    wire [10:0] wa6=l_wbase+(nbase+6)*l_in+mac_idx;
    wire [10:0] wa7=l_wbase+(nbase+7)*l_in+mac_idx;

    // Bias addresses
    wire [10:0] ba0=l_bbase+nbase+0, ba1=l_bbase+nbase+1;
    wire [10:0] ba2=l_bbase+nbase+2, ba3=l_bbase+nbase+3;
    wire [10:0] ba4=l_bbase+nbase+4, ba5=l_bbase+nbase+5;
    wire [10:0] ba6=l_bbase+nbase+6, ba7=l_bbase+nbase+7;

    // Bias+scale+clamp+ReLU for each lane (combinational)
    reg signed [7:0] r0,r1,r2,r3,r4,r5,r6,r7;
    reg signed [31:0] bv;

    `define BIAS_LANE(ACC, BA, RES) \
        bv = $signed(ACC >>> 7) + $signed({{24{weight_mem[BA][7]}}, weight_mem[BA]}); \
        if (bv > 127) RES = 8'sd127; \
        else if (bv < -128) RES = -8'sd128; \
        else RES = bv[7:0]; \
        if (l_relu && RES[7]) RES = 8'sd0;

    always @(*) begin
        `BIAS_LANE(acc0, ba0, r0)
        `BIAS_LANE(acc1, ba1, r1)
        `BIAS_LANE(acc2, ba2, r2)
        `BIAS_LANE(acc3, ba3, r3)
        `BIAS_LANE(acc4, ba4, r4)
        `BIAS_LANE(acc5, ba5, r5)
        `BIAS_LANE(acc6, ba6, r6)
        `BIAS_LANE(acc7, ba7, r7)
    end

    // MSE diff
    wire signed [8:0] mse_diff = $signed({orig_in[mse_idx][7], orig_in[mse_idx]}) - $signed({act_out[mse_idx][7], act_out[mse_idx]});
    wire [17:0] mse_sq = mse_diff * mse_diff;

    // Main FSM
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=S_IDLE; cur_layer<=0; cur_round<=0; mac_idx<=0;
            mse_idx<=0; mse_acc<=0; anomaly_flag<=0; done<=0; mse_out<=0;
            acc0<=0; acc1<=0; acc2<=0; acc3<=0;
            acc4<=0; acc5<=0; acc6<=0; acc7<=0;
            for(k=0;k<32;k=k+1) begin act_in[k]<=0; act_out[k]<=0; orig_in[k]<=0; end
        end else begin
            done <= 1'b0;
            case (state)

            S_IDLE: if (start) begin
                for(k=0;k<32;k=k+1) begin
                    act_in[k]  <= input_data[k*8 +: 8];
                    orig_in[k] <= input_data[k*8 +: 8];
                end
                cur_layer<=0; cur_round<=0; state<=S_LOAD;
            end

            S_LOAD: begin
                acc0<=0; acc1<=0; acc2<=0; acc3<=0;
                acc4<=0; acc5<=0; acc6<=0; acc7<=0;
                mac_idx<=0; state<=S_MAC;
            end

            S_MAC: begin
                acc0<=acc0+$signed(a_val)*$signed(weight_mem[wa0]);
                acc1<=acc1+$signed(a_val)*$signed(weight_mem[wa1]);
                acc2<=acc2+$signed(a_val)*$signed(weight_mem[wa2]);
                acc3<=acc3+$signed(a_val)*$signed(weight_mem[wa3]);
                acc4<=acc4+$signed(a_val)*$signed(weight_mem[wa4]);
                acc5<=acc5+$signed(a_val)*$signed(weight_mem[wa5]);
                acc6<=acc6+$signed(a_val)*$signed(weight_mem[wa6]);
                acc7<=acc7+$signed(a_val)*$signed(weight_mem[wa7]);
                if (mac_idx==l_in-1) state<=S_BIAS;
                else mac_idx<=mac_idx+1;
            end

            S_BIAS: begin
                if(nbase+0<l_out) act_out[nbase+0]<=r0;
                if(nbase+1<l_out) act_out[nbase+1]<=r1;
                if(nbase+2<l_out) act_out[nbase+2]<=r2;
                if(nbase+3<l_out) act_out[nbase+3]<=r3;
                if(nbase+4<l_out) act_out[nbase+4]<=r4;
                if(nbase+5<l_out) act_out[nbase+5]<=r5;
                if(nbase+6<l_out) act_out[nbase+6]<=r6;
                if(nbase+7<l_out) act_out[nbase+7]<=r7;

                if (cur_round==l_rounds-1) begin
                    cur_round<=0;
                    state<=S_COPY;
                end else begin
                    cur_round<=cur_round+1; state<=S_LOAD;
                end
            end

            S_COPY: begin
                for(k=0;k<32;k=k+1) act_in[k]<=act_out[k];
                if (cur_layer==2'd3) begin
                    mse_acc<=0; mse_idx<=0; state<=S_MSE;
                end else begin
                    cur_layer<=cur_layer+1; state<=S_LOAD;
                end
            end

            S_MSE: begin
                mse_acc <= mse_acc + {14'd0, mse_sq};
                if (mse_idx==6'd31) state<=S_DONE;
                else mse_idx<=mse_idx+1;
            end

            S_DONE: begin
                mse_out      <= mse_acc[20:5];
                anomaly_flag <= (mse_acc[20:5] > threshold);
                done         <= 1'b1;
                state        <= S_IDLE;
            end

            default: state <= S_IDLE;
            endcase
        end
    end

endmodule
