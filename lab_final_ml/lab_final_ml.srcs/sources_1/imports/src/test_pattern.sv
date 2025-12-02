`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Test Pattern Generator
// 
// Generates various test patterns for verifying HDMI output:
// - Color bars (default)
// - Solid colors
// - Grid pattern
// - Moving box (to verify timing)
//
// Select pattern using sw[1:0] input
//////////////////////////////////////////////////////////////////////////////////

module test_pattern (
    input  logic        clk,        // 25 MHz pixel clock
    input  logic        rst,        // Active high reset
    input  logic [1:0]  pattern,    // Pattern select (from switches)
    input  logic        vde,        // Video data enable
    input  logic [9:0]  px,         // Pixel X coordinate
    input  logic [9:0]  py,         // Pixel Y coordinate
    output logic [7:0]  red,        // Red channel (0-255)
    output logic [7:0]  green,      // Green channel (0-255)
    output logic [7:0]  blue        // Blue channel (0-255)
);

    // Frame counter for animation
    logic [23:0] frame_count;
    logic        frame_tick;
    logic [9:0]  box_x, box_y;
    
    // Detect end of frame (when py wraps)
    logic [9:0] py_prev;
    always_ff @(posedge clk) begin
        py_prev <= py;
        frame_tick <= (py == 0) && (py_prev != 0);
    end
    
    // Frame counter and animated box position
    always_ff @(posedge clk) begin
        if (rst) begin
            frame_count <= 0;
            box_x <= 100;
            box_y <= 100;
        end else if (frame_tick) begin
            frame_count <= frame_count + 1;
            // Move box slowly
            box_x <= (box_x >= 540) ? 10'd0 : box_x + 1;
            box_y <= (box_y >= 380) ? 10'd0 : (frame_count[0] ? box_y + 1 : box_y);
        end
    end

    // Pattern generation
    always_ff @(posedge clk) begin
        if (rst || !vde) begin
            red   <= 8'd0;
            green <= 8'd0;
            blue  <= 8'd0;
        end else begin
            case (pattern)
                2'b00: begin
                    // Color bars (8 vertical bars)
                    case (px[9:7])  // Divide 640 into 8 sections (80 pixels each)
                        3'd0: begin red <= 8'hFF; green <= 8'hFF; blue <= 8'hFF; end  // White
                        3'd1: begin red <= 8'hFF; green <= 8'hFF; blue <= 8'h00; end  // Yellow
                        3'd2: begin red <= 8'h00; green <= 8'hFF; blue <= 8'hFF; end  // Cyan
                        3'd3: begin red <= 8'h00; green <= 8'hFF; blue <= 8'h00; end  // Green
                        3'd4: begin red <= 8'hFF; green <= 8'h00; blue <= 8'hFF; end  // Magenta
                        3'd5: begin red <= 8'hFF; green <= 8'h00; blue <= 8'h00; end  // Red
                        3'd6: begin red <= 8'h00; green <= 8'h00; blue <= 8'hFF; end  // Blue
                        3'd7: begin red <= 8'h00; green <= 8'h00; blue <= 8'h00; end  // Black
                    endcase
                end
                
                2'b01: begin
                    // Gradient pattern (R horizontal, G vertical, B diagonal)
                    red   <= px[9:2];      // Red increases left to right
                    green <= py[8:1];      // Green increases top to bottom
                    blue  <= (px[8:1] + py[8:1]);  // Blue diagonal
                end
                
                2'b10: begin
                    // Grid pattern with border
                    if (px < 2 || px >= 638 || py < 2 || py >= 478) begin
                        // White border
                        red <= 8'hFF; green <= 8'hFF; blue <= 8'hFF;
                    end else if ((px[5:0] == 0) || (py[5:0] == 0)) begin
                        // Grid lines every 64 pixels
                        red <= 8'h00; green <= 8'hFF; blue <= 8'h00;
                    end else begin
                        // Dark blue background
                        red <= 8'h10; green <= 8'h10; blue <= 8'h30;
                    end
                end
                
                2'b11: begin
                    // Moving box test (verifies animation timing)
                    if ((px >= box_x) && (px < box_x + 100) &&
                        (py >= box_y) && (py < box_y + 100)) begin
                        // White box
                        red <= 8'hFF; green <= 8'hFF; blue <= 8'hFF;
                    end else begin
                        // Checkered background
                        if (px[4] ^ py[4]) begin
                            red <= 8'h40; green <= 8'h40; blue <= 8'h40;
                        end else begin
                            red <= 8'h20; green <= 8'h20; blue <= 8'h20;
                        end
                    end
                end
            endcase
        end
    end

endmodule
