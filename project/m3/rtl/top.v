// ============================================================================
// top.v — Integrated Top Module: Autoencoder Anomaly Detection Accelerator
// ============================================================================
// Project : ECE 410/510 HW4AI — Milestone 3
//
// This top module instantiates ae_interface and compute_core, connecting
// them end-to-end. The interface is the ONLY path between the host and
// the compute engine — no direct access to compute_core ports.
//
// Glue logic: None required. ae_interface already instantiates compute_core
// internally and wires all inter-module signals. This top module re-exports
// ae_interface as the system boundary, making the host-facing ports the
// only external interface.
//
// External ports:
//   clk             input   1-bit   System clock (posedge)
//   rst_n           input   1-bit   Active-low async reset
//   s_axis_tdata    input   256-bit AXI4-Stream slave data (32×INT8 sensor)
//   s_axis_tvalid   input   1-bit   AXI4-Stream slave valid
//   s_axis_tready   output  1-bit   AXI4-Stream slave ready (backpressure)
//   m_axis_tdata    output  32-bit  AXI4-Stream master data (MSE + flag)
//   m_axis_tvalid   output  1-bit   AXI4-Stream master valid
//   m_axis_tready   input   1-bit   AXI4-Stream master ready
//   cfg_addr        input   4-bit   Config register address
//   cfg_wdata       input   32-bit  Config register write data
//   cfg_wr_en       input   1-bit   Config register write enable
//   cfg_rdata       output  32-bit  Config register read data
//   cfg_rd_en       input   1-bit   Config register read enable
//
// Data flow:
//   1. Host writes weights via cfg port (addr 0x0-0x2) → SRAM in compute_core
//   2. Host sets threshold via cfg port (addr 0x3)
//   3. Host streams sensor sample via AXI4-Stream slave
//   4. compute_core runs 4-layer forward pass + MSE + threshold compare
//   5. Result (anomaly flag + MSE) appears on AXI4-Stream master
//   6. Host reads status/MSE via cfg port (addr 0x4-0x5) if desired
//
// Architecture:
//   ae_interface contains compute_core as a submodule. The interface handles
//   AXI4-Stream handshaking, config register decoding, and result packaging.
//   No additional glue logic is needed between the two modules.
// ============================================================================

module top (
    input  wire         clk,
    input  wire         rst_n,

    // AXI4-Stream Slave — sensor input (32 bytes packed as 256 bits)
    input  wire [255:0] s_axis_tdata,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,

    // AXI4-Stream Master — result output (anomaly flag + MSE)
    output wire [31:0]  m_axis_tdata,
    output wire         m_axis_tvalid,
    input  wire         m_axis_tready,

    // Config register port (AXI4-Lite simplified)
    input  wire [3:0]   cfg_addr,
    input  wire [31:0]  cfg_wdata,
    input  wire         cfg_wr_en,
    output wire [31:0]  cfg_rdata,
    input  wire         cfg_rd_en
);

    // ── Instantiate ae_interface (which internally instantiates compute_core) ──
    ae_interface u_interface (
        .clk            (clk),
        .rst_n          (rst_n),

        // AXI4-Stream Slave
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),

        // AXI4-Stream Master
        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready),

        // Config
        .cfg_addr       (cfg_addr),
        .cfg_wdata      (cfg_wdata),
        .cfg_wr_en      (cfg_wr_en),
        .cfg_rdata      (cfg_rdata),
        .cfg_rd_en      (cfg_rd_en)
    );

endmodule
