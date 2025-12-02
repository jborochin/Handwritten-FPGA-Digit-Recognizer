// Button Detector
// Detects mouse clicks within button boundaries

`timescale 1ns / 1ps

module button_detector (
    input  logic clk,
    input  logic reset,
    
    // Mouse input
    input  logic [9:0] mouse_x,
    input  logic [9:0] mouse_y,
    input  logic mouse_click,
    
    // Button dimensions
    input  logic [9:0] btn_x,      // Top-left X
    input  logic [9:0] btn_y,      // Top-left Y
    input  logic [9:0] btn_w,      // Width
    input  logic [9:0] btn_h,      // Height
    
    // Output
    output logic clicked,          // One-cycle pulse on click
    output logic hovering          // High when mouse over button
);

    // Check if mouse is within button bounds
    logic in_bounds;
    
    always_comb begin
        in_bounds = (mouse_x >= btn_x) && (mouse_x < btn_x + btn_w) &&
                    (mouse_y >= btn_y) && (mouse_y < btn_y + btn_h);
    end
    
    assign hovering = in_bounds;
    
    // Edge detection for mouse click
    logic mouse_click_prev;
    logic click_edge;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            mouse_click_prev <= 0;
        end else begin
            mouse_click_prev <= mouse_click;
        end
    end
    
    // Detect rising edge of click
    assign click_edge = mouse_click && !mouse_click_prev;
    
    // Generate clicked pulse
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            clicked <= 0;
        end else begin
            clicked <= click_edge && in_bounds;
        end
    end

endmodule
