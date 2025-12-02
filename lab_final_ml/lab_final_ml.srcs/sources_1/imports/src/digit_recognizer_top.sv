// Digit Recognizer - Phase 1 with Neural Network
// Drawing canvas + NN inference + result display
// Urbana Board - Spartan-7 XC7S50-CSGA324
//
// Controls:
//   BTN0 (J2): Reset
//   BTN1 (J1): Clear canvas
//   BTN2 (G2): Predict digit
//   BTN3 (H2): Toggle draw mode
//   SW[3:0]: Cursor speed
//   SW[4]: Draw enable (hold)
//   SW[5-8]: Cursor direction (L/R/U/D)

`timescale 1ns / 1ps

module digit_recognizer_top (
    // Clock and Reset
    input  logic        clk_100mhz,
    input  logic        reset_btn,
    
    // Buttons
    input  logic        btn_clear,
    input  logic        btn_predict,
    input  logic        btn_draw_toggle,
    
    // Switches
    input  logic [15:0] sw,
    
    // HDMI Output
    output logic        hdmi_clk_p,
    output logic        hdmi_clk_n,
    output logic [2:0]  hdmi_data_p,
    output logic [2:0]  hdmi_data_n,
    
    // Debug LEDs
    output logic [7:0]  led
);

    // ========================================
    // Clock Generation
    // ========================================
    logic clk_25mhz;
    logic clk_125mhz;
    logic pll_locked;
    
    clk_wiz_0 clk_gen (
        .clk_in1(clk_100mhz),
        .clk_out1(clk_25mhz),
        .clk_out2(clk_125mhz),
        .reset(reset_btn),
        .locked(pll_locked)
    );
    
    logic reset_sync;
    assign reset_sync = reset_btn || !pll_locked;
    
    // ========================================
    // VGA Timing Generator
    // ========================================
    logic [9:0] vga_x, vga_y;
    logic hsync, vsync, video_on;
    logic frame_start;
    
    vga_timing vga_ctrl (
        .clk(clk_25mhz),
        .reset(reset_sync),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on),
        .pixel_x(vga_x),
        .pixel_y(vga_y),
        .frame_start(frame_start)
    );
    
    // ========================================
    // Layout Parameters
    // ========================================
    localparam CANVAS_X = 40;       // Left side for canvas
    localparam CANVAS_Y = 100;
    localparam CANVAS_W = 280;
    localparam CANVAS_H = 280;
    localparam BORDER_W = 3;
    
    localparam RESULT_X = 400;      // Right side for result
    localparam RESULT_Y = 150;
    
    // ========================================
    // Button Debouncing
    // ========================================
    logic clear_pulse, predict_pulse, draw_toggle;
    
    button_debounce #(.COUNTER_WIDTH(20)) debounce_clear (
        .clk(clk_25mhz), .reset(reset_sync),
        .btn_in(btn_clear), .btn_out(), .btn_pulse(clear_pulse)
    );
    
    button_debounce #(.COUNTER_WIDTH(20)) debounce_predict (
        .clk(clk_25mhz), .reset(reset_sync),
        .btn_in(btn_predict), .btn_out(), .btn_pulse(predict_pulse)
    );
    
    button_debounce #(.COUNTER_WIDTH(20)) debounce_draw (
        .clk(clk_25mhz), .reset(reset_sync),
        .btn_in(btn_draw_toggle), .btn_out(), .btn_pulse(draw_toggle)
    );
    
    // ========================================
    // Cursor Control
    // ========================================
    logic [9:0] cursor_x, cursor_y;
    logic draw_enable;
    logic draw_mode_latched;
    
    always_ff @(posedge clk_25mhz or posedge reset_sync) begin
        if (reset_sync)
            draw_mode_latched <= 1'b0;
        else if (draw_toggle)
            draw_mode_latched <= ~draw_mode_latched;
    end
    assign draw_enable = sw[4] || draw_mode_latched;
    
    // Cursor movement
    logic [19:0] move_counter;
    logic move_tick;
    assign move_tick = frame_start && (move_counter[3:0] <= sw[3:0]);
    
    always_ff @(posedge clk_25mhz or posedge reset_sync) begin
        if (reset_sync) begin
            cursor_x <= CANVAS_X + CANVAS_W/2;
            cursor_y <= CANVAS_Y + CANVAS_H/2;
            move_counter <= 0;
        end else begin
            if (frame_start)
                move_counter <= move_counter + 1;
            
            if (move_tick) begin
                if (sw[5] && cursor_x > CANVAS_X + 2)
                    cursor_x <= cursor_x - 2;
                if (sw[6] && cursor_x < CANVAS_X + CANVAS_W - 3)
                    cursor_x <= cursor_x + 2;
                if (sw[7] && cursor_y > CANVAS_Y + 2)
                    cursor_y <= cursor_y - 2;
                if (sw[8] && cursor_y < CANVAS_Y + CANVAS_H - 3)
                    cursor_y <= cursor_y + 2;
            end
        end
    end
    
    // ========================================
    // Frame Buffer (Dual Read Port)
    // ========================================
    logic [$clog2(CANVAS_W)-1:0] fb_write_x, fb_read_x_vga, fb_read_x_ds;
    logic [$clog2(CANVAS_H)-1:0] fb_write_y, fb_read_y_vga, fb_read_y_ds;
    logic fb_we;
    logic fb_pixel_in, fb_pixel_vga, fb_pixel_ds;
    
    frame_buffer_dual #(
        .WIDTH(CANVAS_W),
        .HEIGHT(CANVAS_H)
    ) canvas_fb (
        .clk(clk_25mhz),
        .we(fb_we),
        .addr_x_w(fb_write_x),
        .addr_y_w(fb_write_y),
        .pixel_in(fb_pixel_in),
        .addr_x_r_a(fb_read_x_vga),
        .addr_y_r_a(fb_read_y_vga),
        .pixel_out_a(fb_pixel_vga),
        .addr_x_r_b(fb_read_x_ds),
        .addr_y_r_b(fb_read_y_ds),
        .pixel_out_b(fb_pixel_ds)
    );
    
    // ========================================
    // Drawing Engine
    // ========================================
    // Disable drawing during prediction
    logic drawing_allowed;
    
    drawing_engine_cursor #(
        .CANVAS_X(CANVAS_X),
        .CANVAS_Y(CANVAS_Y),
        .CANVAS_W(CANVAS_W),
        .CANVAS_H(CANVAS_H),
        .BRUSH_SIZE(8)
    ) drawer (
        .clk(clk_25mhz),
        .reset(reset_sync),
        .cursor_x(cursor_x),
        .cursor_y(cursor_y),
        .draw_enable(draw_enable && drawing_allowed),
        .clear_canvas(clear_pulse),
        .canvas_x(fb_write_x),
        .canvas_y(fb_write_y),
        .canvas_we(fb_we),
        .canvas_pixel(fb_pixel_in),
        .is_drawing()
    );
    
    // ========================================
    // VGA Read Address
    // ========================================
    logic signed [10:0] rel_x_vga, rel_y_vga;
    assign rel_x_vga = vga_x - CANVAS_X;
    assign rel_y_vga = vga_y - CANVAS_Y;
    
    always_comb begin
        if (rel_x_vga >= 0 && rel_x_vga < CANVAS_W && rel_y_vga >= 0 && rel_y_vga < CANVAS_H) begin
            fb_read_x_vga = rel_x_vga[$clog2(CANVAS_W)-1:0];
            fb_read_y_vga = rel_y_vga[$clog2(CANVAS_H)-1:0];
        end else begin
            fb_read_x_vga = 0;
            fb_read_y_vga = 0;
        end
    end
    
    // ========================================
    // Main State Machine
    // ========================================
    typedef enum logic [2:0] {
        S_IDLE,
        S_DOWNSAMPLE,
        S_INFERENCE,
        S_DONE
    } state_t;
    
    state_t state, next_state;
    
    logic ds_start, ds_done;
    logic nn_start, nn_done;
    logic [3:0] prediction;
    logic [31:0] confidence;
    logic show_result;
    
    always_ff @(posedge clk_25mhz or posedge reset_sync) begin
        if (reset_sync) begin
            state <= S_IDLE;
            show_result <= 1'b0;
        end else begin
            state <= next_state;
            
            // Latch result when done
            if (state == S_INFERENCE && nn_done)
                show_result <= 1'b1;
            
            // Clear result when starting new prediction or clearing canvas
            if (predict_pulse || clear_pulse)
                show_result <= 1'b0;
        end
    end
    
    always_comb begin
        next_state = state;
        ds_start = 1'b0;
        nn_start = 1'b0;
        drawing_allowed = 1'b1;
        
        case (state)
            S_IDLE: begin
                if (predict_pulse) begin
                    next_state = S_DOWNSAMPLE;
                    ds_start = 1'b1;
                end
            end
            
            S_DOWNSAMPLE: begin
                drawing_allowed = 1'b0;
                if (ds_done) begin
                    next_state = S_INFERENCE;
                    nn_start = 1'b1;
                end
            end
            
            S_INFERENCE: begin
                drawing_allowed = 1'b0;
                if (nn_done)
                    next_state = S_DONE;
            end
            
            S_DONE: begin
                // Return to idle after one cycle
                next_state = S_IDLE;
            end
        endcase
    end
    
    // ========================================
    // Image Downsampler
    // ========================================
    logic [9:0] ds_output_addr;
    logic [7:0] ds_output_pixel;
    logic ds_output_valid;
    
    image_downsampler #(
        .CANVAS_W(CANVAS_W),
        .CANVAS_H(CANVAS_H),
        .OUTPUT_W(28),
        .OUTPUT_H(28)
    ) downsampler (
        .clk(clk_25mhz),
        .reset(reset_sync),
        .start(ds_start),
        .done(ds_done),
        .canvas_x_req(fb_read_x_ds),
        .canvas_y_req(fb_read_y_ds),
        .canvas_pixel(fb_pixel_ds),
        .output_addr(ds_output_addr),
        .output_pixel(ds_output_pixel),
        .output_valid(ds_output_valid)
    );
    
    // ========================================
    // Neural Network Inference
    // ========================================
    nn_inference_simple #(
        .DATA_WIDTH(16),
        .ACC_WIDTH(48)
    ) neural_net (
        .clk(clk_25mhz),
        .rst_n(~reset_sync),
        .start(nn_start),
        .done(nn_done),
        .prediction(prediction),
        .confidence(confidence),
        .load_input(ds_output_valid),
        .load_addr(ds_output_addr),
        .load_data({8'b0, ds_output_pixel})  // Zero-extend to 16 bits
    );
    
    // ========================================
    // Digit Display
    // ========================================
    logic digit_pixel;
    
    digit_display digit_disp (
        .pixel_x(vga_x),
        .pixel_y(vga_y),
        .digit_x(RESULT_X),
        .digit_y(RESULT_Y),
        .digit(prediction),
        .show(show_result),
        .pixel_on(digit_pixel)
    );
    
    // ========================================
    // Pixel Color Generation
    // ========================================
    logic [7:0] red, green, blue;
    
    logic in_canvas, in_border, in_cursor;
    logic in_result_area, in_status_bar;
    
    always_comb begin
        in_canvas = (vga_x >= CANVAS_X) && (vga_x < CANVAS_X + CANVAS_W) &&
                    (vga_y >= CANVAS_Y) && (vga_y < CANVAS_Y + CANVAS_H);
        
        in_border = ((vga_x >= CANVAS_X - BORDER_W) && (vga_x < CANVAS_X + CANVAS_W + BORDER_W) &&
                     (vga_y >= CANVAS_Y - BORDER_W) && (vga_y < CANVAS_Y + CANVAS_H + BORDER_W)) &&
                    !in_canvas;
        
        in_cursor = ((vga_x == cursor_x || vga_x == cursor_x-1 || vga_x == cursor_x+1) && 
                     (vga_y >= cursor_y-4 && vga_y <= cursor_y+4)) ||
                    ((vga_y == cursor_y || vga_y == cursor_y-1 || vga_y == cursor_y+1) && 
                     (vga_x >= cursor_x-4 && vga_x <= cursor_x+4));
        
        in_result_area = (vga_x >= RESULT_X - 20) && (vga_x < RESULT_X + 120) &&
                         (vga_y >= RESULT_Y - 20) && (vga_y < RESULT_Y + 160);
        
        in_status_bar = (vga_y >= 420) && (vga_y < 440);
    end
    
    always_comb begin
        // Default background
        red = 8'h30;
        green = 8'h30;
        blue = 8'h40;
        
        // Title area
        if (vga_y < 60) begin
            red = 8'h20;
            green = 8'h40;
            blue = 8'h80;
            // Title text area
            if (vga_y >= 15 && vga_y < 45 && vga_x >= 200 && vga_x < 440) begin
                red = 8'hFF;
                green = 8'hFF;
                blue = 8'hFF;
            end
        end
        
        // Canvas border
        else if (in_border) begin
            red = 8'hFF;
            green = 8'hFF;
            blue = 8'hFF;
        end
        
        // Canvas area
        else if (in_canvas) begin
            if (fb_pixel_vga) begin
                red = 8'h00;
                green = 8'h00;
                blue = 8'h00;
            end else begin
                red = 8'hFF;
                green = 8'hFF;
                blue = 8'hFF;
            end
        end
        
        // Result display area
        else if (in_result_area) begin
            // Background for result
            red = 8'h20;
            green = 8'h20;
            blue = 8'h20;
            
            // Border
            if (vga_x == RESULT_X - 20 || vga_x == RESULT_X + 119 ||
                vga_y == RESULT_Y - 20 || vga_y == RESULT_Y + 159) begin
                if (show_result) begin
                    red = 8'h00;
                    green = 8'hFF;
                    blue = 8'h00;
                end else begin
                    red = 8'h80;
                    green = 8'h80;
                    blue = 8'h80;
                end
            end
            
            // Digit
            if (digit_pixel) begin
                red = 8'h00;
                green = 8'hFF;
                blue = 8'h00;
            end
        end
        
        // Status bar
        else if (in_status_bar) begin
            if (vga_x >= 40 && vga_x < 320) begin
                case (state)
                    S_IDLE: begin
                        if (draw_enable) begin
                            red = 8'h00; green = 8'hC0; blue = 8'h00;  // Green - drawing
                        end else begin
                            red = 8'h80; green = 8'h80; blue = 8'h00;  // Yellow - ready
                        end
                    end
                    S_DOWNSAMPLE, S_INFERENCE: begin
                        red = 8'hFF; green = 8'h80; blue = 8'h00;  // Orange - processing
                    end
                    S_DONE: begin
                        red = 8'h00; green = 8'hFF; blue = 8'h00;  // Bright green - done
                    end
                endcase
            end
        end
        
        // Cursor overlay
        if (in_cursor && in_canvas) begin
            if (draw_enable) begin
                red = 8'h00; green = 8'hFF; blue = 8'h00;
            end else begin
                red = 8'hFF; green = 8'h00; blue = 8'h00;
            end
        end
    end
    
    // ========================================
    // HDMI Transmitter
    // ========================================
    hdmi_tx_0 hdmi_transmitter (
        .pix_clk(clk_25mhz),
        .pix_clkx5(clk_125mhz),
        .pix_clk_locked(pll_locked),
        .rst(reset_sync),
        .red(red),
        .green(green),
        .blue(blue),
        .hsync(hsync),
        .vsync(vsync),
        .vde(video_on),
        .aux0_din(4'b0),
        .aux1_din(4'b0),
        .aux2_din(4'b0),
        .ade(1'b0),
        .TMDS_CLK_P(hdmi_clk_p),
        .TMDS_CLK_N(hdmi_clk_n),
        .TMDS_DATA_P(hdmi_data_p),
        .TMDS_DATA_N(hdmi_data_n)
    );
    
    // ========================================
    // Debug LEDs
    // ========================================
    logic [23:0] heartbeat_counter;
    always_ff @(posedge clk_25mhz or posedge reset_sync) begin
        if (reset_sync)
            heartbeat_counter <= 0;
        else
            heartbeat_counter <= heartbeat_counter + 1;
    end
    
    assign led[0] = heartbeat_counter[23];
    assign led[1] = pll_locked;
    assign led[2] = draw_enable;
    assign led[3] = (state != S_IDLE);      // Processing
    assign led[4] = show_result;            // Result ready
    assign led[7:5] = prediction[2:0];      // Show prediction on LEDs

endmodule
