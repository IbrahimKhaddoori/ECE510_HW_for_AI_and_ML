// ============================================================================
// interface.v — AXI4-Stream/Lite Interface (Plain Verilog)
// ============================================================================
// Module: ae_interface
//
// Data path:  AXI4-Stream slave (256-bit input) -> compute_core ->
//             AXI4-Stream master (flag + MSE)
// Config:     Register write/read for weights, threshold, control.
//
// AXI4-Stream: TVALID/TREADY contract honored (ARM IHI 0051A s2.2.1).
//
// Register map:
//   0x0  WEIGHT_DATA [7:0]   WO  Weight byte
//   0x1  WEIGHT_ADDR [10:0]  WO  Weight SRAM address
//   0x2  WEIGHT_WR   [0:0]   WO  Pulse to commit write
//   0x3  THRESHOLD   [15:0]  RW  MSE threshold (Q8.8)
//   0x4  STATUS      [31:0]  RO  [0]=done [1]=anomaly
//   0x5  MSE_OUT     [15:0]  RO  Last MSE
//
// Clock: Single (clk), posedge. Reset: Active-low async (rst_n).
// ============================================================================

module ae_interface (
    input  wire         clk,
    input  wire         rst_n,

    // AXI4-Stream Slave (sensor input, 32 bytes packed)
    input  wire [255:0] s_axis_tdata,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,

    // AXI4-Stream Master (result)
    output wire [31:0]  m_axis_tdata,
    output wire         m_axis_tvalid,
    input  wire         m_axis_tready,

    // Config register port
    input  wire [3:0]   cfg_addr,
    input  wire [31:0]  cfg_wdata,
    input  wire         cfg_wr_en,
    output reg  [31:0]  cfg_rdata,
    input  wire         cfg_rd_en
);

    // ── Config registers ────────────────────────────────────────────────
    reg [7:0]  reg_weight_data;
    reg [10:0] reg_weight_addr;
    reg        reg_weight_wr;
    reg [15:0] reg_threshold;

    // ── Core signals ────────────────────────────────────────────────────
    wire        core_done;
    wire        core_anomaly;
    wire [15:0] core_mse;

    // ── Input capture ───────────────────────────────────────────────────
    reg [255:0] captured_input;
    reg         input_ready;
    reg         running;

    assign s_axis_tready = !running;

    // Capture input on AXI4-Stream handshake
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            captured_input <= 256'd0;
            input_ready    <= 1'b0;
            running        <= 1'b0;
        end else begin
            input_ready <= 1'b0;
            if (s_axis_tvalid && s_axis_tready) begin
                captured_input <= s_axis_tdata;
                input_ready    <= 1'b1;
                running        <= 1'b1;
            end
            if (core_done)
                running <= 1'b0;
        end
    end

    // ── Compute core ────────────────────────────────────────────────────
    compute_core u_core (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (input_ready),
        .input_data     (captured_input),
        .weight_wr_en   (reg_weight_wr),
        .weight_wr_addr (reg_weight_addr),
        .weight_wr_data (reg_weight_data),
        .threshold      (reg_threshold),
        .anomaly_flag   (core_anomaly),
        .done           (core_done),
        .mse_out        (core_mse)
    );

    // ── Output holding register ─────────────────────────────────────────
    reg [31:0] out_data;
    reg        out_valid;

    assign m_axis_tdata  = out_data;
    assign m_axis_tvalid = out_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_data  <= 32'd0;
            out_valid <= 1'b0;
        end else begin
            if (core_done) begin
                out_data  <= {15'b0, core_mse, core_anomaly};
                out_valid <= 1'b1;
            end else if (m_axis_tready && out_valid) begin
                out_valid <= 1'b0;
            end
        end
    end

    // ── Config write ────────────────────────────────────────────────────
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_weight_data <= 8'd0;
            reg_weight_addr <= 11'd0;
            reg_weight_wr   <= 1'b0;
            reg_threshold   <= 16'd256;
        end else begin
            reg_weight_wr <= 1'b0;
            if (cfg_wr_en) begin
                case (cfg_addr)
                    4'h0: reg_weight_data <= cfg_wdata[7:0];
                    4'h1: reg_weight_addr <= cfg_wdata[10:0];
                    4'h2: reg_weight_wr   <= cfg_wdata[0];
                    4'h3: reg_threshold   <= cfg_wdata[15:0];
                    default: ;
                endcase
            end
        end
    end

    // ── Config read ─────────────────────────────────────────────────────
    always @(*) begin
        case (cfg_addr)
            4'h3:    cfg_rdata = {16'b0, reg_threshold};
            4'h4:    cfg_rdata = {30'b0, core_anomaly, core_done};
            4'h5:    cfg_rdata = {16'b0, core_mse};
            default: cfg_rdata = 32'hDEADBEEF;
        endcase
    end

endmodule
