// Drawing Engine - Cursor Based Version
// Paints pixels when cursor is in canvas and draw is enabled
// Uses a square brush pattern

`timescale 1ns / 1ps

module drawing_engine_cursor #(
    parameter CANVAS_X = 180,
    parameter CANVAS_Y = 100,
    parameter CANVAS_W = 280,
    parameter CANVAS_H = 280,
    parameter BRUSH_SIZE = 8      // Brush size in pixels
)(
    input  logic clk,
    input  logic reset,
    
    // Cursor position (screen coordinates)
    input  logic [9:0] cursor_x,
    input  logic [9:0] cursor_y,
    
    // Control
    input  logic draw_enable,     // Active when drawing
    input  logic clear_canvas,    // Pulse to clear
    
    // Canvas interface
    output logic [$clog2(CANVAS_W)-1:0] canvas_x,
    output logic [$clog2(CANVAS_H)-1:0] canvas_y,
    output logic canvas_we,
    output logic canvas_pixel,
    
    // Status
    output logic is_drawing
);

    // Convert screen coordinates to canvas coordinates
    logic signed [10:0] rel_x, rel_y;
    logic in_canvas;
    
    always_comb begin
        rel_x = cursor_x - CANVAS_X;
        rel_y = cursor_y - CANVAS_Y;
        in_canvas = (rel_x >= 0) && (rel_x < CANVAS_W) && 
                    (rel_y >= 0) && (rel_y < CANVAS_H);
    end
    
    // State machine
    typedef enum logic [1:0] {
        IDLE,
        DRAWING,
        CLEARING
    } state_t;
    
    state_t state, next_state;
    
    // Brush pattern counter
    logic [$clog2(BRUSH_SIZE)-1:0] brush_x_off, brush_y_off;
    logic brush_done;
    assign brush_done = (brush_x_off == BRUSH_SIZE-1) && (brush_y_off == BRUSH_SIZE-1);
    
    // Clear counter
    localparam CLEAR_SIZE = CANVAS_W * CANVAS_H;
    logic [$clog2(CLEAR_SIZE)-1:0] clear_counter;
    logic clear_done;
    assign clear_done = (clear_counter == CLEAR_SIZE - 1);
    
    // Previous cursor position for continuous drawing
    logic [9:0] prev_cursor_x, prev_cursor_y;
    logic cursor_moved;
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            prev_cursor_x <= 0;
            prev_cursor_y <= 0;
        end else begin
            prev_cursor_x <= cursor_x;
            prev_cursor_y <= cursor_y;
        end
    end
    
    assign cursor_moved = (cursor_x != prev_cursor_x) || (cursor_y != prev_cursor_y);
    
    // State register
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            brush_x_off <= 0;
            brush_y_off <= 0;
            clear_counter <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    brush_x_off <= 0;
                    brush_y_off <= 0;
                    clear_counter <= 0;
                end
                
                DRAWING: begin
                    // Cycle through brush pattern
                    if (brush_x_off < BRUSH_SIZE - 1) begin
                        brush_x_off <= brush_x_off + 1;
                    end else begin
                        brush_x_off <= 0;
                        if (brush_y_off < BRUSH_SIZE - 1)
                            brush_y_off <= brush_y_off + 1;
                        else
                            brush_y_off <= 0;
                    end
                end
                
                CLEARING: begin
                    if (!clear_done)
                        clear_counter <= clear_counter + 1;
                end
            endcase
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (clear_canvas)
                    next_state = CLEARING;
                else if (draw_enable && in_canvas)
                    next_state = DRAWING;
            end
            
            DRAWING: begin
                if (clear_canvas)
                    next_state = CLEARING;
                else if (brush_done) begin
                    if (draw_enable && in_canvas && cursor_moved)
                        next_state = DRAWING;  // Continue drawing
                    else
                        next_state = IDLE;
                end
            end
            
            CLEARING: begin
                if (clear_done)
                    next_state = IDLE;
            end
        endcase
    end
    
    // Output logic
    logic [$clog2(CANVAS_W)-1:0] brush_canvas_x;
    logic [$clog2(CANVAS_H)-1:0] brush_canvas_y;
    logic brush_in_bounds;
    
    always_comb begin
        canvas_we = 0;
        canvas_pixel = 0;
        canvas_x = 0;
        canvas_y = 0;
        is_drawing = 0;
        
        // Calculate brush pixel position (centered on cursor)
        brush_canvas_x = rel_x[$clog2(CANVAS_W)-1:0] + brush_x_off - BRUSH_SIZE/2;
        brush_canvas_y = rel_y[$clog2(CANVAS_H)-1:0] + brush_y_off - BRUSH_SIZE/2;
        
        // Check if brush pixel is in bounds (handle unsigned comparison carefully)
        brush_in_bounds = (brush_canvas_x < CANVAS_W) && (brush_canvas_y < CANVAS_H);
        
        case (state)
            DRAWING: begin
                if (brush_in_bounds) begin
                    canvas_x = brush_canvas_x;
                    canvas_y = brush_canvas_y;
                    canvas_we = 1;
                    canvas_pixel = 1;  // Draw black
                end
                is_drawing = 1;
            end
            
            CLEARING: begin
                canvas_x = clear_counter % CANVAS_W;
                canvas_y = clear_counter / CANVAS_W;
                canvas_we = 1;
                canvas_pixel = 0;  // Clear to white
            end
        endcase
    end

endmodule
