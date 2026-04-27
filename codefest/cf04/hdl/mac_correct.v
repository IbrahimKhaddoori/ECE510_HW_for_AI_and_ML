// mac_correct.v — Corrected INT8 MAC unit
// Fixes applied:
//   - Ports declared with 'signed' keyword (fixes LLM A sign extension bug)
//   - Uses always_ff (fixes LLM B wrong process type)
//   - No initial block (fixes LLM B non-synthesizable construct)

module mac (
    input  logic              clk,
    input  logic              rst,
    input  logic signed [7:0] a,
    input  logic signed [7:0] b,
    output logic signed [31:0] out
);

    always_ff @(posedge clk) begin
        if (rst) begin
            out <= 32'sd0;
        end else begin
            out <= out + (a * b);
        end
    end

endmodule
