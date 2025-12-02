`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// VGA Sync Generator for 640x480 @ 60Hz
// 
// Generates horizontal and vertical sync signals, pixel coordinates,
// and video data enable (vde) signal for VGA/HDMI output.
//
// Timing parameters for 640x480 @ 60Hz (25.175 MHz pixel clock, we use 25 MHz):
//   Horizontal: 640 visible + 16 front porch + 96 sync + 48 back porch = 800 total
//   Vertical:   480 visible + 10 front porch + 2 sync + 33 back porch = 525 total
//////////////////////////////////////////////////////////////////////////////////

module vga_sync (
    input  logic        clk,        // 25 MHz pixel clock
    input  logic        rst,        // Active high reset
    output logic        hsync,      // Horizontal sync (active low)
    output logic        vsync,      // Vertical sync (active low)
    output logic        vde,        // Video data enable (active during visible area)
    output logic [9:0]  px,         // Current pixel X coordinate (0-639 visible)
    output logic [9:0]  py          // Current pixel Y coordinate (0-479 visible)
);

    // 640x480 @ 60Hz timing parameters
    localparam H_VISIBLE    = 640;
    localparam H_FRONT      = 16;
    localparam H_SYNC       = 96;
    localparam H_BACK       = 48;
    localparam H_TOTAL      = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;  // 800
    
    localparam V_VISIBLE    = 480;
    localparam V_FRONT      = 10;
    localparam V_SYNC       = 2;
    localparam V_BACK       = 33;
    localparam V_TOTAL      = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;  // 525

    // Counters
    logic [9:0] h_count;
    logic [9:0] v_count;

    // Horizontal counter
    always_ff @(posedge clk) begin
        if (rst) begin
            h_count <= 10'd0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 10'd0;
            end else begin
                h_count <= h_count + 1'b1;
            end
        end
    end

    // Vertical counter
    always_ff @(posedge clk) begin
        if (rst) begin
            v_count <= 10'd0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                if (v_count == V_TOTAL - 1) begin
                    v_count <= 10'd0;
                end else begin
                    v_count <= v_count + 1'b1;
                end
            end
        end
    end

    // Generate sync signals (active low)
    always_ff @(posedge clk) begin
        if (rst) begin
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else begin
            // HSYNC is low during sync period
            hsync <= ~((h_count >= H_VISIBLE + H_FRONT) && 
                       (h_count < H_VISIBLE + H_FRONT + H_SYNC));
            
            // VSYNC is low during sync period
            vsync <= ~((v_count >= V_VISIBLE + V_FRONT) && 
                       (v_count < V_VISIBLE + V_FRONT + V_SYNC));
        end
    end

    // Video data enable - active only during visible region
    always_ff @(posedge clk) begin
        if (rst) begin
            vde <= 1'b0;
        end else begin
            vde <= (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
        end
    end

    // Pixel coordinates (valid during visible region)
    always_ff @(posedge clk) begin
        if (rst) begin
            px <= 10'd0;
            py <= 10'd0;
        end else begin
            px <= h_count;
            py <= v_count;
        end
    end

endmodule
