// Image Downsampler
// Converts 280×280 drawing canvas to 28×28 grayscale image for neural network
// Uses 10×10 averaging blocks

`timescale 1ns / 1ps

module image_downsampler #(
    parameter CANVAS_W = 280,
    parameter CANVAS_H = 280,
    parameter OUTPUT_W = 28,
    parameter OUTPUT_H = 28
)(
    input  logic clk,
    input  logic reset,
    input  logic start,
    output logic done,
    
    // Read from canvas frame buffer
    output logic [$clog2(CANVAS_W)-1:0] canvas_x_req,
    output logic [$clog2(CANVAS_H)-1:0] canvas_y_req,
    input  logic canvas_pixel,
    
    // Output to neural network (28×28 pixels, 0-255 grayscale)
    output logic [9:0]  output_addr,    // 0-783
    output logic [7:0]  output_pixel,   // 0-255 intensity
    output logic        output_valid
);

    localparam BLOCK_SIZE = CANVAS_W / OUTPUT_W;  // 10×10 pixels per output pixel
    localparam PIXELS_PER_BLOCK = BLOCK_SIZE * BLOCK_SIZE;  // 100
    
    // State machine
    typedef enum logic [2:0] {
        IDLE,
        SCANNING,
        ACCUMULATING,
        OUTPUTTING,
        DONE_STATE
    } state_t;
    
    state_t state, next_state;
    
    // Current output pixel being processed
    logic [4:0] out_x, out_y;  // 0-27
    
    // Block scanning within current output pixel
    logic [3:0] block_x, block_y;  // 0-9
    
    // Accumulator for averaging
    logic [10:0] accumulator;  // Up to 100 pixels
    
    // Pixel counter
    logic [6:0] pixel_count;   // 0-99
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            out_x <= 0;
            out_y <= 0;
            block_x <= 0;
            block_y <= 0;
            accumulator <= 0;
            pixel_count <= 0;
            output_addr <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        out_x <= 0;
                        out_y <= 0;
                        block_x <= 0;
                        block_y <= 0;
                        accumulator <= 0;
                        pixel_count <= 0;
                        output_addr <= 0;
                    end
                end
                
                SCANNING: begin
                    // Wait one cycle for canvas pixel to be valid
                end
                
                ACCUMULATING: begin
                    // Add pixel to accumulator
                    if (canvas_pixel)
                        accumulator <= accumulator + 1;
                    
                    pixel_count <= pixel_count + 1;
                    
                    // Move to next pixel in block
                    if (block_x < BLOCK_SIZE - 1) begin
                        block_x <= block_x + 1;
                    end else begin
                        block_x <= 0;
                        block_y <= block_y + 1;
                    end
                end
                
                OUTPUTTING: begin
                    // Reset for next block
                    accumulator <= 0;
                    pixel_count <= 0;
                    block_x <= 0;
                    block_y <= 0;
                    
                    // Move to next output pixel
                    if (out_x < OUTPUT_W - 1) begin
                        out_x <= out_x + 1;
                    end else begin
                        out_x <= 0;
                        if (out_y < OUTPUT_H - 1) begin
                            out_y <= out_y + 1;
                        end
                    end
                    
                    output_addr <= output_addr + 1;
                end
                
                DONE_STATE: begin
                    // Stay here
                end
            endcase
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = SCANNING;
            end
            
            SCANNING: begin
                next_state = ACCUMULATING;
            end
            
            ACCUMULATING: begin
                if (pixel_count == PIXELS_PER_BLOCK - 1)
                    next_state = OUTPUTTING;
                else
                    next_state = SCANNING;
            end
            
            OUTPUTTING: begin
                if (out_x == OUTPUT_W - 1 && out_y == OUTPUT_H - 1)
                    next_state = DONE_STATE;
                else
                    next_state = SCANNING;
            end
            
            DONE_STATE: begin
                if (!start)
                    next_state = IDLE;
            end
        endcase
    end
    
    // Calculate canvas address
    always_comb begin
        canvas_x_req = out_x * BLOCK_SIZE + block_x;
        canvas_y_req = out_y * BLOCK_SIZE + block_y;
    end
    
    // Output pixel calculation
    // Convert accumulator (0-100) to grayscale (0-255)
    // More black pixels = higher value
    always_comb begin
        output_pixel = (accumulator * 255) / PIXELS_PER_BLOCK;
        output_valid = (state == OUTPUTTING);
    end
    
    assign done = (state == DONE_STATE);

endmodule
