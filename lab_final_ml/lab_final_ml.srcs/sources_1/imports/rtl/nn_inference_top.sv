// Neural Network Inference - Using REAL for Python Match
// This version uses floating point to exactly match Python
// Once working, we can convert back to fixed-point

`timescale 1ns / 1ps

module nn_inference_simple #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH = 48
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    output logic        done,
    output logic [3:0]  prediction,
    output logic [31:0] confidence
);

    localparam INPUT_SIZE = 784;
    localparam HIDDEN_SIZE = 128;
    localparam OUTPUT_SIZE = 10;
    
    // Scales from Python
    localparam real LAYER0_SCALE = 30812.18;
    localparam real LAYER1_SCALE = 27109.77;
    
    // Memory arrays - keep as integers for loading
    logic signed [DATA_WIDTH-1:0] input_mem [0:INPUT_SIZE-1];
    logic signed [DATA_WIDTH-1:0] weights_layer1 [0:INPUT_SIZE*HIDDEN_SIZE-1];
    logic signed [DATA_WIDTH-1:0] biases_layer1 [0:HIDDEN_SIZE-1];
    logic signed [DATA_WIDTH-1:0] weights_layer2 [0:HIDDEN_SIZE*OUTPUT_SIZE-1];
    logic signed [DATA_WIDTH-1:0] biases_layer2 [0:OUTPUT_SIZE-1];
    
    // Computation arrays - use REAL for exact Python match
    real hidden_mem [0:HIDDEN_SIZE-1];
    real output_mem [0:OUTPUT_SIZE-1];
    
    initial begin
        $readmemh("weights_layer0.hex", weights_layer1);
        $readmemh("biases_layer0.hex", biases_layer1);
        $readmemh("weights_layer1.hex", weights_layer2);
        $readmemh("biases_layer1.hex", biases_layer2);
    end
    
    // State machine
    typedef enum logic [3:0] {
        IDLE,
        L1_INIT, L1_MAC, L1_BIAS, L1_RELU,
        L2_INIT, L2_MAC, L2_BIAS,
        FIND_MAX, DONE_STATE
    } state_t;
    
    state_t state;
    logic [$clog2(INPUT_SIZE)-1:0] input_idx;
    logic [$clog2(HIDDEN_SIZE)-1:0] hidden_idx;
    logic [$clog2(OUTPUT_SIZE)-1:0] output_idx;
    real accumulator;
    logic [3:0] max_idx;
    real max_value;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            prediction <= '0;
            confidence <= '0;
            input_idx <= '0;
            hidden_idx <= '0;
            output_idx <= '0;
            accumulator <= 0.0;
            max_idx <= '0;
            max_value <= 0.0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        hidden_idx <= '0;
                        state <= L1_INIT;
                    end
                end
                
                // LAYER 1 - EXACTLY as Python does it
                L1_INIT: begin
                    input_idx <= '0;
                    accumulator <= 0.0;
                    state <= L1_MAC;
                end
                
                L1_MAC: begin
                    // Python: x_scaled = x * LAYER0_SCALE
                    //         acc += x_scaled * weight
                    // Which is: acc += (x * LAYER0_SCALE) * weight
                    accumulator <= accumulator + 
                        (($itor(input_mem[input_idx]) * LAYER0_SCALE) * 
                         $itor(weights_layer1[hidden_idx * INPUT_SIZE + input_idx]));
                    
                    if (input_idx == INPUT_SIZE - 1)
                        state <= L1_BIAS;
                    else
                        input_idx <= input_idx + 1;
                end
                
                L1_BIAS: begin
                    // Python: output += bias * LAYER0_SCALE
                    accumulator <= accumulator + 
                        ($itor(biases_layer1[hidden_idx]) * LAYER0_SCALE);
                    state <= L1_RELU;
                end
                
                L1_RELU: begin
                    // ReLU
                    if (accumulator > 0.0)
                        hidden_mem[hidden_idx] <= accumulator;
                    else
                        hidden_mem[hidden_idx] <= 0.0;
                    
                    if (hidden_idx == HIDDEN_SIZE - 1) begin
                        output_idx <= '0;
                        state <= L2_INIT;
                    end else begin
                        hidden_idx <= hidden_idx + 1;
                        state <= L1_INIT;
                    end
                end
                
                // LAYER 2 - EXACTLY as Python does it
                L2_INIT: begin
                    hidden_idx <= '0;
                    accumulator <= 0.0;
                    state <= L2_MAC;
                end
                
                L2_MAC: begin
                    // Python: acc += hidden * weight
                    // (hidden is NOT scaled again, it's used as-is)
                    accumulator <= accumulator + 
                        (hidden_mem[hidden_idx] * 
                         $itor(weights_layer2[output_idx * HIDDEN_SIZE + hidden_idx]));
                    
                    if (hidden_idx == HIDDEN_SIZE - 1)
                        state <= L2_BIAS;
                    else
                        hidden_idx <= hidden_idx + 1;
                end
                
                L2_BIAS: begin
                    // Python: output += bias * LAYER1_SCALE
                    accumulator <= accumulator + 
                        ($itor(biases_layer2[output_idx]) * LAYER1_SCALE);
                    output_mem[output_idx] <= accumulator;
                    
                    if (output_idx == OUTPUT_SIZE - 1) begin
                        output_idx <= '0;
                        max_idx <= '0;
                        max_value <= -1.0e30;  // Very negative
                        state <= FIND_MAX;
                    end else begin
                        output_idx <= output_idx + 1;
                        state <= L2_INIT;
                    end
                end
                
                // ARGMAX
                FIND_MAX: begin
                    if (output_idx < OUTPUT_SIZE) begin
                        if (output_mem[output_idx] > max_value) begin
                            max_value <= output_mem[output_idx];
                            max_idx <= output_idx[3:0];
                        end
                        output_idx <= output_idx + 1;
                    end else begin
                        prediction <= max_idx;
                        // Convert to integer for output
                        if (max_value > 2147483647.0)
                            confidence <= 32'h7FFFFFFF;
                        else if (max_value < -2147483648.0)
                            confidence <= 32'h80000000;
                        else
                            confidence <= $rtoi(max_value);
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule