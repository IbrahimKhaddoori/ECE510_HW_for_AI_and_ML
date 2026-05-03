// ============================================================================
// compute_core.sv — Z-Score Streaming Anomaly Detector Compute Core
// ============================================================================
// Project : ECE 410/510 HW4AI — Z-Score Anomaly Detection Accelerator
// Author  : [Your Name]
// Date    : Spring 2026
//
// Description:
//   Streaming z-score anomaly detector using fixed-point Q8.8 arithmetic
//   and a sliding window of W=32 samples. Uses the squared z-score
//   comparison (x-μ)² > T²·σ² to avoid a hardware square-root unit.
//
//   Running mean and variance are maintained incrementally:
//     running_sum   += new_sample - oldest_sample
//     running_sum_sq += new_sample² - oldest_sample²
//     mean     = running_sum    >>> log2(W)
//     variance = running_sum_sq >>> log2(W)  -  mean²
//
// Clock domain : Single clock (clk), all logic synchronous to posedge clk.
// Reset        : Active-low asynchronous reset (rst_n).
//
// Port list:
//   clk            input   1-bit    System clock
//   rst_n          input   1-bit    Active-low async reset
//   data_in        input  16-bit    Signed Q8.8 sensor sample
//   data_valid     input   1-bit    Asserted for one cycle when data_in is valid
//   threshold_sq   input  32-bit    Unsigned Q16.16, pre-computed T² (e.g. 9.0 for T=3)
//   anomaly_flag   output  1-bit    High if current sample is anomalous
//   flag_valid     output  1-bit    High for one cycle when anomaly_flag is valid
//   ready          output  1-bit    High when core can accept a new sample
// ============================================================================

module compute_core (
    input  wire                clk,
    input  wire                rst_n,

    // Data input
    input  wire signed [15:0]  data_in,        // Q8.8 fixed-point sensor sample
    input  wire                data_valid,      // pulse high for one cycle

    // Configuration
    input  wire        [31:0]  threshold_sq,    // Q16.16, unsigned, pre-computed T²

    // Output
    output reg                 anomaly_flag,    // 1 = anomaly detected
    output reg                 flag_valid,      // 1 = anomaly_flag is valid this cycle
    output wire                ready            // 1 = accepting samples
);

    // ── Parameters ──────────────────────────────────────────────────────────
    localparam W     = 32;       // window size (must be power of 2)
    localparam LOG2W = 5;        // log2(32)

    // ── Shift register (sliding window) ─────────────────────────────────────
    reg signed [15:0] window [0:W-1];

    // ── Running statistics ──────────────────────────────────────────────────
    //   running_sum    : sum of all W window values, Q13.8 in 24 bits
    //   running_sum_sq : sum of all W (window[i]²), Q21.16 in 48 bits
    reg signed [23:0]  running_sum;
    reg signed [47:0]  running_sum_sq;

    // ── Warm-up counter ─────────────────────────────────────────────────────
    reg [5:0] sample_count;
    wire      warmed_up = (sample_count >= W);

    // ── Always ready (combinational single-cycle processing) ────────────────
    assign ready = 1'b1;

    // ── Oldest sample being shifted out ─────────────────────────────────────
    wire signed [15:0] oldest = window[W-1];

    // ════════════════════════════════════════════════════════════════════════
    // Combinational datapath — computed from CURRENT state (before update)
    // ════════════════════════════════════════════════════════════════════════

    // Mean: running_sum / W  (arithmetic right shift by LOG2W)
    wire signed [23:0] mean_wide = running_sum >>> LOG2W;
    wire signed [15:0] mean      = mean_wide[15:0];          // Q8.8

    // Deviation of incoming sample from window mean
    wire signed [15:0] deviation = data_in - mean;            // Q8.8
    wire signed [31:0] dev_sq    = deviation * deviation;     // Q16.16

    // Variance = E[X²] - (E[X])²
    //   E[X²]  = running_sum_sq / W
    //   (E[X])² = mean * mean
    wire signed [47:0] e_x2     = running_sum_sq >>> LOG2W;   // Q16.16 in 48b
    wire signed [31:0] mean_sq  = mean * mean;                // Q16.16
    wire signed [47:0] var_wide = e_x2 - {{16{mean_sq[31]}}, mean_sq};
    // Clamp variance to zero if negative (possible from fixed-point rounding)
    wire        [31:0] variance = var_wide[47] ? 32'd0 : var_wide[31:0]; // Q16.16

    // Squared z-score comparison:  (x - μ)² > T² × σ²
    //   dev_sq         : Q16.16  (32 bits)
    //   threshold_sq   : Q16.16  (32 bits)
    //   variance       : Q16.16  (32 bits)
    //   product        : Q32.32  (64 bits)
    //   Align: dev_sq << 16 to Q32.32, then compare
    wire        [63:0] thresh_x_var = threshold_sq * variance;  // Q32.32
    // Compare dev_sq with (thresh_x_var >> 16) — both in Q16.16
    wire        [47:0] thresh_var_shifted = thresh_x_var[63:16]; // >> 16 → Q16.16
    wire               anomaly_comb = (dev_sq > thresh_var_shifted[31:0])
                                    && warmed_up
                                    && (variance > 32'd0);

    // ── Squares of new and oldest samples for incremental update ────────────
    wire signed [31:0] new_sq = data_in * data_in;  // Q16.16
    wire signed [31:0] old_sq = oldest  * oldest;    // Q16.16

    // ════════════════════════════════════════════════════════════════════════
    // Sequential logic — update state on clock edge
    // ════════════════════════════════════════════════════════════════════════
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // ── Reset ────────────────────────────────────────────────────
            running_sum    <= 24'sd0;
            running_sum_sq <= 48'sd0;
            sample_count   <= 6'd0;
            anomaly_flag   <= 1'b0;
            flag_valid     <= 1'b0;
            for (k = 0; k < W; k = k + 1)
                window[k] <= 16'sd0;

        end else if (data_valid) begin
            // ── Shift register update ────────────────────────────────────
            for (k = W-1; k > 0; k = k - 1)
                window[k] <= window[k-1];
            window[0] <= data_in;

            // ── Running statistics update (incremental) ──────────────────
            if (warmed_up) begin
                // Subtract oldest, add newest
                running_sum    <= running_sum
                                + {{8{data_in[15]}}, data_in}
                                - {{8{oldest[15]}},  oldest};
                running_sum_sq <= running_sum_sq
                                + {{16{new_sq[31]}}, new_sq}
                                - {{16{old_sq[31]}}, old_sq};
            end else begin
                // Still filling the window
                running_sum    <= running_sum    + {{8{data_in[15]}}, data_in};
                running_sum_sq <= running_sum_sq + {{16{new_sq[31]}}, new_sq};
                sample_count   <= sample_count + 6'd1;
            end

            // ── Output registration ──────────────────────────────────────
            anomaly_flag <= anomaly_comb;
            flag_valid   <= warmed_up;

        end else begin
            flag_valid <= 1'b0;
        end
    end

endmodule
