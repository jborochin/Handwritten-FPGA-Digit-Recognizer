// Frame Buffer for Drawing Canvas
// Dual-port memory: one port for writing (drawing), one for reading (VGA display)

`timescale 1ns / 1ps

module frame_buffer #(
    parameter WIDTH = 280,
    parameter HEIGHT = 280
)(
    input  logic clk,
    
    // Write port (for drawing)
    input  logic we,
    input  logic [$clog2(WIDTH)-1:0]  addr_x_w,
    input  logic [$clog2(HEIGHT)-1:0] addr_y_w,
    input  logic pixel_in,
    
    // Read port (for VGA display)
    input  logic [$clog2(WIDTH)-1:0]  addr_x_r,
    input  logic [$clog2(HEIGHT)-1:0] addr_y_r,
    output logic pixel_out
);

    // Calculate address width
    localparam ADDR_WIDTH = $clog2(WIDTH * HEIGHT);
    localparam MEM_SIZE = WIDTH * HEIGHT;
    
    // Memory array - 1 bit per pixel (binary: drawn or not)
    logic memory [0:MEM_SIZE-1];
    
    // Convert 2D coordinates to 1D address
    logic [ADDR_WIDTH-1:0] write_addr, read_addr;
    
    assign write_addr = addr_y_w * WIDTH + addr_x_w;
    assign read_addr = addr_y_r * WIDTH + addr_x_r;
    
    // Write port
    always_ff @(posedge clk) begin
        if (we && write_addr < MEM_SIZE) begin
            memory[write_addr] <= pixel_in;
        end
    end
    
    // Read port (asynchronous read for VGA)
    always_comb begin
        if (read_addr < MEM_SIZE)
            pixel_out = memory[read_addr];
        else
            pixel_out = 1'b0;
    end
    
    // Initialize memory to all zeros (blank canvas)
    initial begin
        for (int i = 0; i < MEM_SIZE; i++) begin
            memory[i] = 1'b0;
        end
    end

endmodule
