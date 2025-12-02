// VGA Timing Generator
// 640×480 @ 60Hz
// Pixel clock: 25 MHz

`timescale 1ns / 1ps

module vga_timing (
    input  logic clk,              // 25 MHz pixel clock
    input  logic reset,
    output logic hsync,
    output logic vsync,
    output logic video_on,
    output logic [9:0] pixel_x,
    output logic [9:0] pixel_y,
    output logic frame_start       // Pulse at start of each frame
);

    // 640×480 @ 60Hz timing parameters
    localparam H_DISPLAY = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = 800;    // 640+16+96+48
    
    localparam V_DISPLAY = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = 525;    // 480+10+2+33
    
    logic [9:0] h_count, v_count;
    logic h_end, v_end;
    
    assign h_end = (h_count == H_TOTAL - 1);
    assign v_end = (v_count == V_TOTAL - 1);
    
    // Horizontal counter
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            h_count <= 0;
        else if (h_end)
            h_count <= 0;
        else
            h_count <= h_count + 1;
    end
    
    // Vertical counter
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            v_count <= 0;
        else if (h_end) begin
            if (v_end)
                v_count <= 0;
            else
                v_count <= v_count + 1;
        end
    end
    
    // Sync signals (active HIGH for HDMI TX IP)
    // HSYNC active during H_SYNC period after H_DISPLAY + H_FRONT
    assign hsync = (h_count >= H_DISPLAY + H_FRONT) && 
                   (h_count < H_DISPLAY + H_FRONT + H_SYNC);
    
    // VSYNC active during V_SYNC period after V_DISPLAY + V_FRONT
    assign vsync = (v_count >= V_DISPLAY + V_FRONT) && 
                   (v_count < V_DISPLAY + V_FRONT + V_SYNC);
    
    // Video on during display area
    assign video_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
    
    // Pixel coordinates
    assign pixel_x = h_count;
    assign pixel_y = v_count;
    
    // Frame start pulse - active for one clock at start of frame
    assign frame_start = (h_count == 0) && (v_count == 0);

endmodule
