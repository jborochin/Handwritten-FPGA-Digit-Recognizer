// Drawing Engine
// Handles mouse-based drawing with brush
// Paints pixels in the canvas when mouse button is pressed

`timescale 1ns / 1ps

module drawing_engine #(
    parameter CANVAS_X = 20,
    parameter CANVAS_Y = 60,
    parameter CANVAS_W = 280,
    parameter CANVAS_H = 280,
    parameter BRUSH_SIZE = 5  // 5×5 pixel brush
)(
    input  logic clk,
    input  logic reset,
    
    // Mouse input
    input  logic [9:0] mouse_x,
    input  logic [9:0] mouse_y,
    input  logic mouse_btn,
    
    // Control
    input  logic drawing_enabled,
    input  logic clear_canvas,
    
    // Canvas interface
    output logic [$clog2(CANVAS_W)-1:0] canvas_x,
    output logic [$clog2(CANVAS_H)-1:0] canvas_y,
    output logic canvas_we,
    output logic canvas_pixel,
    
    // Status
    output logic is_drawing
);

    // Check if mouse is within canvas
    logic in_canvas;
    logic signed [10:0] rel_x, rel_y;  // Relative position in canvas
    
    always_comb begin
        rel_x = mouse_x - CANVAS_X;
        rel_y = mouse_y - CANVAS_Y;
        in_canvas = (rel_x >= 0) && (rel_x < CANVAS_W) && 
                    (rel_y >= 0) && (rel_y < CANVAS_H);
    end
    
    // Drawing state machine
    typedef enum logic [1:0] {
        IDLE,
        DRAWING,
        CLEARING
    } draw_state_t;
    
    draw_state_t state, next_state;
    
    // Brush offset counter (for painting 5×5 area)
    logic [2:0] brush_x_offset, brush_y_offset;
    logic brush_done;
    
    assign brush_done = (brush_x_offset == BRUSH_SIZE-1) && 
                        (brush_y_offset == BRUSH_SIZE-1);
    
    // Clear counter (for clearing entire canvas)
    logic [$clog2(CANVAS_W*CANVAS_H)-1:0] clear_counter;
    logic clear_done;
    
    assign clear_done = (clear_counter == CANVAS_W*CANVAS_H - 1);
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            brush_x_offset <= 0;
            brush_y_offset <= 0;
            clear_counter <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    brush_x_offset <= 0;
                    brush_y_offset <= 0;
                    clear_counter <= 0;
                end
                
                DRAWING: begin
                    // Increment brush offset to paint all pixels in brush
                    if (brush_x_offset < BRUSH_SIZE-1) begin
                        brush_x_offset <= brush_x_offset + 1;
                    end else begin
                        brush_x_offset <= 0;
                        if (brush_y_offset < BRUSH_SIZE-1)
                            brush_y_offset <= brush_y_offset + 1;
                        else
                            brush_y_offset <= 0;
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
                else if (mouse_btn && in_canvas && drawing_enabled)
                    next_state = DRAWING;
            end
            
            DRAWING: begin
                if (brush_done)
                    next_state = IDLE;
            end
            
            CLEARING: begin
                if (clear_done)
                    next_state = IDLE;
            end
        endcase
    end
    
    // Canvas write logic
    always_comb begin
        canvas_we = 0;
        canvas_pixel = 0;
        canvas_x = 0;
        canvas_y = 0;
        is_drawing = 0;
        
        case (state)
            DRAWING: begin
                // Calculate pixel position with brush offset
                // Center the brush on mouse position
                canvas_x = rel_x + brush_x_offset - BRUSH_SIZE/2;
                canvas_y = rel_y + brush_y_offset - BRUSH_SIZE/2;
                
                // Only write if within bounds
                if (canvas_x < CANVAS_W && canvas_y < CANVAS_H) begin
                    canvas_we = 1;
                    canvas_pixel = 1;  // Draw black pixel
                end
                is_drawing = 1;
            end
            
            CLEARING: begin
                // Clear pixels sequentially
                canvas_x = clear_counter % CANVAS_W;
                canvas_y = clear_counter / CANVAS_W;
                canvas_we = 1;
                canvas_pixel = 0;  // Clear to white
            end
        endcase
    end

endmodule
