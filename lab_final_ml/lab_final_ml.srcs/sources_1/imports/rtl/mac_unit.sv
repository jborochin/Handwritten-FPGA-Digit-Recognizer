// MAC Unit for Neural Network Inference
// 16-bit fixed-point multiply-accumulate
// Optimized for Spartan-7 FPGA

module mac_unit #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH = 32  // Wider to prevent overflow
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    enable,
    input  logic                    clear_acc,  // Clear accumulator
    input  logic signed [DATA_WIDTH-1:0] a,     // Input activation
    input  logic signed [DATA_WIDTH-1:0] b,     // Weight
    output logic signed [ACC_WIDTH-1:0]  acc    // Accumulated result
);

    logic signed [ACC_WIDTH-1:0] accumulator;
    logic signed [2*DATA_WIDTH-1:0] product;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= '0;
        end else if (clear_acc) begin
            accumulator <= '0;
        end else if (enable) begin
            product = a * b;
            accumulator <= accumulator + product;
        end
    end

    assign acc = accumulator;

endmodule
