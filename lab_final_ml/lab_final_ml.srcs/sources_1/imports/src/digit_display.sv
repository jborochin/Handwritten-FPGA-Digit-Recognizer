// Digit Display Module
// Renders a large digit (0-9) using simple block patterns
// Each digit is 80x120 pixels

`timescale 1ns / 1ps

module digit_display (
    input  logic [9:0] pixel_x,      // Current VGA X position
    input  logic [9:0] pixel_y,      // Current VGA Y position
    input  logic [9:0] digit_x,      // Top-left X of digit display area
    input  logic [9:0] digit_y,      // Top-left Y of digit display area
    input  logic [3:0] digit,        // Digit to display (0-9)
    input  logic       show,         // Enable display
    output logic       pixel_on      // High if this pixel is part of the digit
);

    // Digit dimensions
    localparam WIDTH = 80;
    localparam HEIGHT = 120;
    localparam SEGMENT_W = 16;  // Segment thickness
    
    // Relative position within digit area
    logic signed [10:0] rel_x, rel_y;
    logic in_area;
    
    always_comb begin
        rel_x = pixel_x - digit_x;
        rel_y = pixel_y - digit_y;
        in_area = show && (rel_x >= 0) && (rel_x < WIDTH) && 
                  (rel_y >= 0) && (rel_y < HEIGHT);
    end
    
    // 7-segment layout:
    //   AAA
    //  F   B
    //   GGG
    //  E   C
    //   DDD
    
    logic seg_a, seg_b, seg_c, seg_d, seg_e, seg_f, seg_g;
    logic in_seg_a, in_seg_b, in_seg_c, in_seg_d, in_seg_e, in_seg_f, in_seg_g;
    
    // Segment positions (relative coordinates)
    always_comb begin
        // Horizontal segments
        in_seg_a = (rel_y < SEGMENT_W) && (rel_x >= SEGMENT_W) && (rel_x < WIDTH - SEGMENT_W);
        in_seg_g = (rel_y >= HEIGHT/2 - SEGMENT_W/2) && (rel_y < HEIGHT/2 + SEGMENT_W/2) && 
                   (rel_x >= SEGMENT_W) && (rel_x < WIDTH - SEGMENT_W);
        in_seg_d = (rel_y >= HEIGHT - SEGMENT_W) && (rel_x >= SEGMENT_W) && (rel_x < WIDTH - SEGMENT_W);
        
        // Vertical segments (left side)
        in_seg_f = (rel_x < SEGMENT_W) && (rel_y >= SEGMENT_W) && (rel_y < HEIGHT/2);
        in_seg_e = (rel_x < SEGMENT_W) && (rel_y >= HEIGHT/2) && (rel_y < HEIGHT - SEGMENT_W);
        
        // Vertical segments (right side)
        in_seg_b = (rel_x >= WIDTH - SEGMENT_W) && (rel_y >= SEGMENT_W) && (rel_y < HEIGHT/2);
        in_seg_c = (rel_x >= WIDTH - SEGMENT_W) && (rel_y >= HEIGHT/2) && (rel_y < HEIGHT - SEGMENT_W);
    end
    
    // Segment patterns for each digit
    //         ABCDEFG
    // 0 = 1111110 = segments A,B,C,D,E,F on
    // 1 = 0110000 = segments B,C on
    // 2 = 1101101 = segments A,B,D,E,G on
    // 3 = 1111001 = segments A,B,C,D,G on
    // 4 = 0110011 = segments B,C,F,G on
    // 5 = 1011011 = segments A,C,D,F,G on
    // 6 = 1011111 = segments A,C,D,E,F,G on
    // 7 = 1110000 = segments A,B,C on
    // 8 = 1111111 = all segments on
    // 9 = 1111011 = segments A,B,C,D,F,G on
    
    always_comb begin
        case (digit)
            4'd0: begin seg_a=1; seg_b=1; seg_c=1; seg_d=1; seg_e=1; seg_f=1; seg_g=0; end
            4'd1: begin seg_a=0; seg_b=1; seg_c=1; seg_d=0; seg_e=0; seg_f=0; seg_g=0; end
            4'd2: begin seg_a=1; seg_b=1; seg_c=0; seg_d=1; seg_e=1; seg_f=0; seg_g=1; end
            4'd3: begin seg_a=1; seg_b=1; seg_c=1; seg_d=1; seg_e=0; seg_f=0; seg_g=1; end
            4'd4: begin seg_a=0; seg_b=1; seg_c=1; seg_d=0; seg_e=0; seg_f=1; seg_g=1; end
            4'd5: begin seg_a=1; seg_b=0; seg_c=1; seg_d=1; seg_e=0; seg_f=1; seg_g=1; end
            4'd6: begin seg_a=1; seg_b=0; seg_c=1; seg_d=1; seg_e=1; seg_f=1; seg_g=1; end
            4'd7: begin seg_a=1; seg_b=1; seg_c=1; seg_d=0; seg_e=0; seg_f=0; seg_g=0; end
            4'd8: begin seg_a=1; seg_b=1; seg_c=1; seg_d=1; seg_e=1; seg_f=1; seg_g=1; end
            4'd9: begin seg_a=1; seg_b=1; seg_c=1; seg_d=1; seg_e=0; seg_f=1; seg_g=1; end
            default: begin seg_a=0; seg_b=0; seg_c=0; seg_d=0; seg_e=0; seg_f=0; seg_g=0; end
        endcase
    end
    
    // Combine segments
    always_comb begin
        pixel_on = in_area && (
            (in_seg_a && seg_a) ||
            (in_seg_b && seg_b) ||
            (in_seg_c && seg_c) ||
            (in_seg_d && seg_d) ||
            (in_seg_e && seg_e) ||
            (in_seg_f && seg_f) ||
            (in_seg_g && seg_g)
        );
    end

endmodule
