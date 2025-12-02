// UI Display Controller
// Renders all visual elements: canvas, buttons, text, results

`timescale 1ns / 1ps

module ui_display (
    input  logic [9:0] vga_x,
    input  logic [9:0] vga_y,
    
    // Canvas
    input  logic canvas_pixel,
    
    // Neural network results
    input  logic [3:0]  prediction,
    input  logic [31:0] confidence,
    input  logic show_result,
    
    // Output
    output logic [11:0] rgb_out
);

    // Color definitions (12-bit RGB: 4R 4G 4B)
    localparam COLOR_WHITE      = 12'hFFF;
    localparam COLOR_BLACK      = 12'h000;
    localparam COLOR_GRAY       = 12'h888;
    localparam COLOR_LIGHT_GRAY = 12'hCCC;
    localparam COLOR_BLUE       = 12'h00F;
    localparam COLOR_GREEN      = 12'h0F0;
    localparam COLOR_RED        = 12'hF00;
    
    // Layout parameters
    localparam CANVAS_X = 20;
    localparam CANVAS_Y = 60;
    localparam CANVAS_W = 280;
    localparam CANVAS_H = 280;
    
    localparam BTN_X = 320;
    localparam PREDICT_BTN_Y = 80;
    localparam CLEAR_BTN_Y = 180;
    localparam BTN_W = 280;
    localparam BTN_H = 60;
    
    localparam RESULT_X = 320;
    localparam RESULT_Y = 280;
    localparam RESULT_W = 280;
    localparam RESULT_H = 120;
    
    // Region detection
    logic in_canvas, in_predict_btn, in_clear_btn, in_result;
    logic in_canvas_border, in_btn_border;
    
    always_comb begin
        // Canvas region
        in_canvas = (vga_x >= CANVAS_X) && (vga_x < CANVAS_X + CANVAS_W) &&
                    (vga_y >= CANVAS_Y) && (vga_y < CANVAS_Y + CANVAS_H);
        
        in_canvas_border = ((vga_x >= CANVAS_X - 2) && (vga_x < CANVAS_X + CANVAS_W + 2) &&
                            (vga_y >= CANVAS_Y - 2) && (vga_y < CANVAS_Y + CANVAS_H + 2)) &&
                           !in_canvas;
        
        // Button regions
        in_predict_btn = (vga_x >= BTN_X) && (vga_x < BTN_X + BTN_W) &&
                         (vga_y >= PREDICT_BTN_Y) && (vga_y < PREDICT_BTN_Y + BTN_H);
        
        in_clear_btn = (vga_x >= BTN_X) && (vga_x < BTN_X + BTN_W) &&
                       (vga_y >= CLEAR_BTN_Y) && (vga_y < CLEAR_BTN_Y + BTN_H);
        
        in_btn_border = ((in_predict_btn || in_clear_btn) && 
                        ((vga_x == BTN_X) || (vga_x == BTN_X + BTN_W - 1) ||
                         (vga_y == PREDICT_BTN_Y && in_predict_btn) || 
                         (vga_y == PREDICT_BTN_Y + BTN_H - 1 && in_predict_btn) ||
                         (vga_y == CLEAR_BTN_Y && in_clear_btn) ||
                         (vga_y == CLEAR_BTN_Y + BTN_H - 1 && in_clear_btn)));
        
        // Result region
        in_result = (vga_x >= RESULT_X) && (vga_x < RESULT_X + RESULT_W) &&
                    (vga_y >= RESULT_Y) && (vga_y < RESULT_Y + RESULT_H);
    end
    
    // Text rendering (simple)
    logic is_text_pixel;
    
    text_renderer text (
        .vga_x(vga_x),
        .vga_y(vga_y),
        .prediction(prediction),
        .confidence(confidence),
        .show_result(show_result),
        .pixel_out(is_text_pixel)
    );
    
    // Color muxing
    always_comb begin
        // Default background
        rgb_out = COLOR_LIGHT_GRAY;
        
        // Title area
        if (vga_y < 40) begin
            rgb_out = COLOR_BLUE;
            if (is_text_pixel)  // "DIGIT RECOGNIZER" text
                rgb_out = COLOR_WHITE;
        end
        
        // Canvas area
        else if (in_canvas_border) begin
            rgb_out = COLOR_BLACK;
        end
        else if (in_canvas) begin
            // White background, black drawing
            rgb_out = canvas_pixel ? COLOR_BLACK : COLOR_WHITE;
        end
        
        // Buttons
        else if (in_btn_border) begin
            rgb_out = COLOR_BLACK;
        end
        else if (in_predict_btn) begin
            rgb_out = COLOR_GREEN;
            if (is_text_pixel)  // "PREDICT" text
                rgb_out = COLOR_BLACK;
        end
        else if (in_clear_btn) begin
            rgb_out = COLOR_RED;
            if (is_text_pixel)  // "CLEAR" text
                rgb_out = COLOR_BLACK;
        end
        
        // Result display
        else if (in_result && show_result) begin
            rgb_out = COLOR_WHITE;
            if (is_text_pixel)  // Prediction and confidence
                rgb_out = COLOR_BLACK;
        end
    end

endmodule

// Simple text renderer (placeholder - you'll want to expand this)
module text_renderer (
    input  logic [9:0] vga_x,
    input  logic [9:0] vga_y,
    input  logic [3:0] prediction,
    input  logic [31:0] confidence,
    input  logic show_result,
    output logic pixel_out
);

    // TODO: Implement actual text rendering
    // Options:
    // 1. Use font ROM
    // 2. Hard-code simple 5×7 or 8×8 font
    // 3. Use Xilinx character generator IP
    
    // For now, placeholder
    assign pixel_out = 1'b0;
    
    // In Week 2, replace this with actual text rendering
    // For buttons: "PREDICT", "CLEAR"
    // For results: "Prediction: X", "Confidence: XXXXX"

endmodule
