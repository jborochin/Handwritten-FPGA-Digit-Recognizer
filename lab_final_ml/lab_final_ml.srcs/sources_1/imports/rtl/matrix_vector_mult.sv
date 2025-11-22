// Matrix-Vector Multiplication Unit
// Computes: output = weights * input + bias
// Parallelizable for higher throughput

module matrix_vector_mult #(
    parameter INPUT_SIZE = 784,
    parameter OUTPUT_SIZE = 128,
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH = 32,
    parameter NUM_MAC_UNITS = 4  // Parallelism factor
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    start,
    output logic                    done,
    
    // Input vector (from BRAM or previous layer)
    output logic [$clog2(INPUT_SIZE)-1:0] input_addr,
    input  logic signed [DATA_WIDTH-1:0]  input_data,
    
    // Weight memory interface
    output logic [$clog2(INPUT_SIZE*OUTPUT_SIZE)-1:0] weight_addr,
    input  logic signed [DATA_WIDTH-1:0] weight_data,
    
    // Bias memory interface
    output logic [$clog2(OUTPUT_SIZE)-1:0] bias_addr,
    input  logic signed [DATA_WIDTH-1:0]  bias_data,
    
    // Output memory interface
    output logic [$clog2(OUTPUT_SIZE)-1:0] output_addr,
    output logic signed [ACC_WIDTH-1:0]    output_data,
    output logic                           output_valid
);

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        COMPUTE,
        ADD_BIAS,
        WRITE_OUTPUT,
        DONE_STATE
    } state_t;
    
    state_t state, next_state;
    
    // Counters
    logic [$clog2(INPUT_SIZE)-1:0] input_idx;
    logic [$clog2(OUTPUT_SIZE)-1:0] output_idx;
    
    // MAC unit
    logic mac_enable, mac_clear;
    logic signed [ACC_WIDTH-1:0] mac_result;
    
    mac_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) mac (
        .clk(clk),
        .rst_n(rst_n),
        .enable(mac_enable),
        .clear_acc(mac_clear),
        .a(input_data),
        .b(weight_data),
        .acc(mac_result)
    );
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_idx <= '0;
            output_idx <= '0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        input_idx <= '0;
                        output_idx <= '0;
                    end
                end
                
                COMPUTE: begin
                    if (input_idx < INPUT_SIZE - 1) begin
                        input_idx <= input_idx + 1;
                    end else begin
                        input_idx <= '0;
                    end
                end
                
                WRITE_OUTPUT: begin
                    if (output_idx < OUTPUT_SIZE - 1) begin
                        output_idx <= output_idx + 1;
                    end
                end
            endcase
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        mac_enable = 1'b0;
        mac_clear = 1'b0;
        output_valid = 1'b0;
        done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                    mac_clear = 1'b1;
                end
            end
            
            COMPUTE: begin
                mac_enable = 1'b1;
                if (input_idx == INPUT_SIZE - 1) begin
                    next_state = ADD_BIAS;
                end
            end
            
            ADD_BIAS: begin
                next_state = WRITE_OUTPUT;
            end
            
            WRITE_OUTPUT: begin
                output_valid = 1'b1;
                if (output_idx == OUTPUT_SIZE - 1) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = COMPUTE;
                    mac_clear = 1'b1;
                end
            end
            
            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end
        endcase
    end
    
    // Address generation
    assign input_addr = input_idx;
    assign weight_addr = output_idx * INPUT_SIZE + input_idx;
    assign bias_addr = output_idx;
    assign output_addr = output_idx;
    assign output_data = mac_result + (bias_data << 8);  // Scale bias appropriately

endmodule
