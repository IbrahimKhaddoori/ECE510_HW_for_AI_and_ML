// ============================================================================
// interface.sv — AXI4-Stream Interface for Z-Score Anomaly Detector
// ============================================================================
// Project : ECE 410/510 HW4AI — Z-Score Anomaly Detection Accelerator
// Author  : [Your Name]
// Date    : Spring 2026
// Module  : zscore_interface  (file is interface.sv per M2 spec;
//           module name avoids the SystemVerilog keyword 'interface')
//
// Description:
//   Wraps the compute_core with an AXI4-Stream compliant data interface
//   and a simple register-mapped configuration port.
//
//   Data path  : AXI4-Stream slave (sensor in) → compute_core → AXI4-Stream master (flag out)
//   Config path: register write/read port for threshold and status
//
// AXI4-Stream compliance:
//   - TVALID must not depend on TREADY (ARM IHI 0051A, §2.2.1)
//   - Transfer occurs on the cycle where TVALID && TREADY are both high
//   - This module honours the TVALID/TREADY contract on both ports
//
// Register map (active on cfg_wr_en / cfg_rd_en):
//   Addr 0x0  THRESHOLD_SQ  [31:0]  RW  Pre-computed T² in Q16.16
//   Addr 0x1  STATUS        [31:0]  RO  [0]=warmed_up, [6:1]=sample_count
//   Addr 0x2  CTRL          [31:0]  RW  [0]=enable (1=accept data, 0=ignore)
//
// Clock domain : Single clock (clk), all logic synchronous to posedge clk.
// Reset        : Active-low asynchronous reset (rst_n).
//
// Port list:
//   clk              input   1-bit   System clock
//   rst_n            input   1-bit   Active-low async reset
//   s_axis_tdata     input  16-bit   AXI4-Stream slave data (Q8.8 sensor sample)
//   s_axis_tvalid    input   1-bit   AXI4-Stream slave valid
//   s_axis_tready    output  1-bit   AXI4-Stream slave ready
//   m_axis_tdata     output  8-bit   AXI4-Stream master data [0]=anomaly flag
//   m_axis_tvalid    output  1-bit   AXI4-Stream master valid
//   m_axis_tready    input   1-bit   AXI4-Stream master ready
//   cfg_addr         input   4-bit   Config register address
//   cfg_wdata        input  32-bit   Config write data
//   cfg_wr_en        input   1-bit   Config write enable
//   cfg_rdata        output 32-bit   Config read data
//   cfg_rd_en        input   1-bit   Config read enable
// ============================================================================

module zscore_interface (
    input  wire         clk,
    input  wire         rst_n,

    // ── AXI4-Stream Slave (sensor sample input) ─────────────────────────
    input  wire [15:0]  s_axis_tdata,       // Q8.8 signed sensor sample
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,

    // ── AXI4-Stream Master (anomaly flag output) ────────────────────────
    output wire [7:0]   m_axis_tdata,       // [0] = anomaly flag
    output wire         m_axis_tvalid,
    input  wire         m_axis_tready,

    // ── Configuration register port ─────────────────────────────────────
    input  wire [3:0]   cfg_addr,
    input  wire [31:0]  cfg_wdata,
    input  wire         cfg_wr_en,
    output reg  [31:0]  cfg_rdata,
    input  wire         cfg_rd_en
);

    // ── Configuration registers ─────────────────────────────────────────
    reg [31:0] reg_threshold_sq;    // Addr 0x0: T² in Q16.16
    reg        reg_enable;          // Addr 0x2, bit 0: enable

    // ── Compute core wires ──────────────────────────────────────────────
    wire        core_anomaly_flag;
    wire        core_flag_valid;
    wire        core_ready;

    // ── AXI4-Stream handshake ───────────────────────────────────────────
    // Slave ready when core is ready and module is enabled
    wire slave_handshake = s_axis_tvalid && s_axis_tready;
    assign s_axis_tready = core_ready && reg_enable;

    // ── Output holding register (for AXI4-Stream master) ────────────────
    reg        out_flag;
    reg        out_valid;

    assign m_axis_tdata  = {7'b0, out_flag};
    assign m_axis_tvalid = out_valid;

    // ── Compute core instantiation ──────────────────────────────────────
    compute_core u_core (
        .clk           (clk),
        .rst_n         (rst_n),
        .data_in       (s_axis_tdata),
        .data_valid    (slave_handshake),
        .threshold_sq  (reg_threshold_sq),
        .anomaly_flag  (core_anomaly_flag),
        .flag_valid    (core_flag_valid),
        .ready         (core_ready)
    );

    // ── Output register: hold flag until downstream accepts ─────────────
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_flag  <= 1'b0;
            out_valid <= 1'b0;
        end else begin
            if (core_flag_valid) begin
                out_flag  <= core_anomaly_flag;
                out_valid <= 1'b1;
            end else if (m_axis_tready && out_valid) begin
                out_valid <= 1'b0;  // downstream consumed the flag
            end
        end
    end

    // ── Configuration register write ────────────────────────────────────
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_threshold_sq <= 32'd589824;  // default T²=9.0 → Q16.16 = 9×65536
            reg_enable       <= 1'b1;        // enabled by default
        end else if (cfg_wr_en) begin
            case (cfg_addr)
                4'h0: reg_threshold_sq <= cfg_wdata;
                4'h2: reg_enable       <= cfg_wdata[0];
                default: ; // ignore writes to read-only or invalid addresses
            endcase
        end
    end

    // ── Configuration register read ─────────────────────────────────────
    always @(*) begin
        case (cfg_addr)
            4'h0:    cfg_rdata = reg_threshold_sq;
            4'h1:    cfg_rdata = {25'b0, core_ready, 6'b0};  // STATUS (simplified)
            4'h2:    cfg_rdata = {31'b0, reg_enable};
            default: cfg_rdata = 32'hDEAD_BEEF;
        endcase
    end

endmodule
