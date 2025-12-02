// Frame Buffer for Drawing Canvas - Dual Read Port Version
// One write port (drawing), two read ports (VGA display + downsampler)

`timescale 1ns / 1ps

module frame_buffer_dual #(
    parameter WIDTH = 280,
    parameter HEIGHT = 280
)(
    input  logic clk,
    
    // Write port (for drawing)
    input  logic we,
    input  logic [$clog2(WIDTH)-1:0]  addr_x_w,
    input  logic [$clog2(HEIGHT)-1:0] addr_y_w,
    input  logic pixel_in,
    
    // Read port A (for VGA display)
    input  logic [$clog2(WIDTH)-1:0]  addr_x_r_a,
    input  logic [$clog2(HEIGHT)-1:0] addr_y_r_a,
    output logic pixel_out_a,
    
    // Read port B (for downsampler)
    input  logic [$clog2(WIDTH)-1:0]  addr_x_r_b,
    input  logic [$clog2(HEIGHT)-1:0] addr_y_r_b,
    output logic pixel_out_b
);

    // Calculate address width
    localparam ADDR_WIDTH = $clog2(WIDTH * HEIGHT);
    localparam MEM_SIZE = WIDTH * HEIGHT;
    
    // Memory array - 1 bit per pixel (binary: drawn or not)
    // Using distributed RAM allows multiple async reads
    logic memory [0:MEM_SIZE-1];
    
    // Convert 2D coordinates to 1D address
    logic [ADDR_WIDTH-1:0] write_addr, read_addr_a, read_addr_b;
    
    assign write_addr = addr_y_w * WIDTH + addr_x_w;
    assign read_addr_a = addr_y_r_a * WIDTH + addr_x_r_a;
    assign read_addr_b = addr_y_r_b * WIDTH + addr_x_r_b;
    
    // Write port
    always_ff @(posedge clk) begin
        if (we && write_addr < MEM_SIZE) begin
            memory[write_addr] <= pixel_in;
        end
    end
    
    // Read port A (asynchronous for VGA - no latency)
    always_comb begin
        if (read_addr_a < MEM_SIZE)
            pixel_out_a = memory[read_addr_a];
        else
            pixel_out_a = 1'b0;
    end
    
    // Read port B (asynchronous for downsampler)
    always_comb begin
        if (read_addr_b < MEM_SIZE)
            pixel_out_b = memory[read_addr_b];
        else
            pixel_out_b = 1'b0;
    end
    
    // Initialize memory to all zeros (blank canvas)
    initial begin
        for (int i = 0; i < MEM_SIZE; i++) begin
            memory[i] = 1'b0;
        end
    end

endmodule
