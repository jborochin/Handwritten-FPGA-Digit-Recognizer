// Neural Network Inference - CORRECT ORDER OF OPERATIONS
// Key fix: Do (hidden >> 8) THEN multiply, matching Python exactly

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
    output logic [31:0] confidence,
    
    input  logic                    load_input,
    input  logic [9:0]              load_addr,
    input  logic signed [DATA_WIDTH-1:0] load_data
);

    localparam INPUT_SIZE = 784;
    localparam HIDDEN_SIZE = 128;
    localparam OUTPUT_SIZE = 10;
    
    logic signed [DATA_WIDTH-1:0] input_mem [0:INPUT_SIZE-1];
    logic signed [ACC_WIDTH-1:0] hidden_mem [0:HIDDEN_SIZE-1];
    logic signed [ACC_WIDTH-1:0] output_mem [0:OUTPUT_SIZE-1];
    logic signed [DATA_WIDTH-1:0] weights_layer1 [0:INPUT_SIZE*HIDDEN_SIZE-1];
    logic signed [DATA_WIDTH-1:0] biases_layer1 [0:HIDDEN_SIZE-1];
    logic signed [DATA_WIDTH-1:0] weights_layer2 [0:HIDDEN_SIZE*OUTPUT_SIZE-1];
    logic signed [DATA_WIDTH-1:0] biases_layer2 [0:OUTPUT_SIZE-1];
    
    always_ff @(posedge clk) begin
        if (load_input && load_addr < INPUT_SIZE) begin
            input_mem[load_addr] <= load_data;
        end
    end
    
    initial begin
        $readmemh("weights_layer0.hex", weights_layer1);
        $readmemh("biases_layer0.hex", biases_layer1);
        $readmemh("weights_layer1.hex", weights_layer2);
        $readmemh("biases_layer1.hex", biases_layer2);
    end
    
    typedef enum logic [3:0] {
        IDLE, L1_INIT, L1_MAC, L1_BIAS, L1_RELU,
        L2_INIT, L2_SCALE, L2_MAC, L2_BIAS, FIND_MAX, DONE_STATE
    } state_t;
    
    state_t state;
    logic [$clog2(INPUT_SIZE)-1:0] input_idx;
    logic [$clog2(HIDDEN_SIZE)-1:0] hidden_idx;
    logic [$clog2(OUTPUT_SIZE)-1:0] output_idx;
    logic signed [ACC_WIDTH-1:0] accumulator;
    logic signed [ACC_WIDTH-1:0] hidden_scaled;  // Store scaled hidden value
    logic [3:0] max_idx;
    logic signed [ACC_WIDTH-1:0] max_value;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            prediction <= '0;
            confidence <= '0;
            input_idx <= '0;
            hidden_idx <= '0;
            output_idx <= '0;
            accumulator <= '0;
            hidden_scaled <= '0;
            max_idx <= '0;
            max_value <= '0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        hidden_idx <= '0;
                        state <= L1_INIT;
                    end
                end
                
                // LAYER 1
                L1_INIT: begin
                    input_idx <= '0;
                    accumulator <= '0;
                    state <= L1_MAC;
                end
                
                L1_MAC: begin
                    accumulator <= accumulator + 
                        ($signed(input_mem[input_idx]) * 
                         $signed(weights_layer1[hidden_idx * INPUT_SIZE + input_idx]));
                    if (input_idx == INPUT_SIZE - 1)
                        state <= L1_BIAS;
                    else
                        input_idx <= input_idx + 1;
                end
                
                L1_BIAS: begin
                    accumulator <= accumulator + ($signed(biases_layer1[hidden_idx]) * 256);
                    state <= L1_RELU;
                end
                
                L1_RELU: begin
                    hidden_mem[hidden_idx] <= (accumulator > 0) ? accumulator : '0;
                    if (hidden_idx == HIDDEN_SIZE - 1) begin
                        output_idx <= '0;
                        state <= L2_INIT;
                    end else begin
                        hidden_idx <= hidden_idx + 1;
                        state <= L1_INIT;
                    end
                end
                
                // LAYER 2 - TWO STAGE: Scale THEN multiply
                L2_INIT: begin
                    hidden_idx <= '0;
                    accumulator <= '0;
                    state <= L2_SCALE;
                end
                
                L2_SCALE: begin
                    // CRITICAL: Do division FIRST (matches Python: hidden // 256)
                    hidden_scaled <= $signed(hidden_mem[hidden_idx]) >>> 8;
                    state <= L2_MAC;
                end
                
                L2_MAC: begin
                    // Now multiply the SCALED hidden value
                    accumulator <= accumulator + 
                        (hidden_scaled * $signed(weights_layer2[output_idx * HIDDEN_SIZE + hidden_idx]));
                    
                    if (hidden_idx == HIDDEN_SIZE - 1)
                        state <= L2_BIAS;
                    else begin
                        hidden_idx <= hidden_idx + 1;
                        state <= L2_SCALE;  // Go back to scale next hidden value
                    end
                end
                
                L2_BIAS: begin
                    accumulator <= accumulator + ($signed(biases_layer2[output_idx]) * 256);
                    output_mem[output_idx] <= accumulator;
                    if (output_idx == OUTPUT_SIZE - 1) begin
                        output_idx <= '0;
                        max_idx <= '0;
                        max_value <= $signed(-48'h7FFF_FFFF_FFFF);
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
                        confidence <= max_value[31:0];
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