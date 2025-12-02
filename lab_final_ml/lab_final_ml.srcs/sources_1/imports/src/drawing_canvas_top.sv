// Phase 1: Drawing Canvas with HDMI Output
// Button-controlled cursor for testing (USB mouse comes in Phase 2)
// Urbana Board - Spartan-7 XC7S50-CSGA324
//
// Controls:
//   BTN0 (J2): Reset
//   BTN1 (J1): Clear canvas
//   BTN2 (G2): Trigger predict (future)
//   BTN3 (H2): Toggle draw mode
//   SW[3:0]: Cursor speed (0=slow, 15=fast)
//   SW[4]: Draw enable (hold to draw)
//   SW[5]: Cursor left
//   SW[6]: Cursor right  
//   SW[7]: Cursor up
//   SW[8]: Cursor down

`timescale 1ns / 1ps

module drawing_canvas_top (
    // Clock and Reset
    input  logic        clk_100mhz,     // 100 MHz system clock
    input  logic        reset_btn,       // BTN0 - active high reset
    
    // Buttons
    input  logic        btn_clear,       // BTN1 - clear canvas
    input  logic        btn_predict,     // BTN2 - trigger prediction (future)
    input  logic        btn_draw_toggle, // BTN3 - toggle draw mode
    
    // Switches
    input  logic [15:0] sw,
    
    // HDMI Output (directly active, accent active accent accent accent accent accent accent)
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
    logic clk_25mhz;    // Pixel clock
    logic clk_125mhz;   // TMDS serializer clock (5x pixel)
    logic pll_locked;
    
    clk_wiz_0 clk_gen (
        .clk_in1(clk_100mhz),
        .clk_out1(clk_25mhz),
        .clk_out2(clk_125mhz),
        .reset(reset_btn),
        .locked(pll_locked)
    );
    
    logic reset_internal;
    assign reset_internal = reset_btn || !pll_locked;
    
    // ========================================
    // VGA Timing Generator
    // ========================================
    logic [9:0] vga_x, vga_y;
    logic hsync, vsync, video_on;
    logic frame_start;  // Pulse at start of each frame
    
    vga_timing vga_ctrl (
        .clk(clk_25mhz),
        .reset(reset_internal),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on),
        .pixel_x(vga_x),
        .pixel_y(vga_y),
        .frame_start(frame_start)
    );
    
    // ========================================
    // Canvas Parameters
    // ========================================
    localparam CANVAS_X = 180;      // Center horizontally: (640-280)/2 = 180
    localparam CANVAS_Y = 100;      // Leave room at top for title
    localparam CANVAS_W = 280;
    localparam CANVAS_H = 280;
    localparam BORDER_W = 3;
    
    // ========================================
    // Button-Controlled Cursor
    // ========================================
    logic [9:0] cursor_x, cursor_y;
    logic draw_enable;
    logic [3:0] cursor_speed;
    
    // Debounced button inputs
    logic clear_pulse, predict_pulse, draw_toggle;
    
    button_debounce #(.COUNTER_WIDTH(20)) debounce_clear (
        .clk(clk_25mhz),
        .reset(reset_internal),
        .btn_in(btn_clear),
        .btn_out(),
        .btn_pulse(clear_pulse)
    );
    
    button_debounce #(.COUNTER_WIDTH(20)) debounce_predict (
        .clk(clk_25mhz),
        .reset(reset_internal),
        .btn_in(btn_predict),
        .btn_out(),
        .btn_pulse(predict_pulse)
    );
    
    button_debounce #(.COUNTER_WIDTH(20)) debounce_draw (
        .clk(clk_25mhz),
        .reset(reset_internal),
        .btn_in(btn_draw_toggle),
        .btn_out(),
        .btn_pulse(draw_toggle)
    );
    
    // Cursor speed from switches
    assign cursor_speed = sw[3:0];
    
    // Draw mode - either hold SW[4] or toggle with BTN3
    logic draw_mode_latched;
    always_ff @(posedge clk_25mhz or posedge reset_internal) begin
        if (reset_internal)
            draw_mode_latched <= 1'b0;
        else if (draw_toggle)
            draw_mode_latched <= ~draw_mode_latched;
    end
    assign draw_enable = sw[4] || draw_mode_latched;
    
    // Cursor movement (updated once per frame for smooth motion)
    logic [19:0] move_counter;
    logic move_tick;
    
    // Movement speed: lower = faster
    // speed 0 = move every 16 frames, speed 15 = move every frame
    assign move_tick = frame_start && (move_counter[3:0] <= cursor_speed);
    
    always_ff @(posedge clk_25mhz or posedge reset_internal) begin
        if (reset_internal) begin
            cursor_x <= CANVAS_X + CANVAS_W/2;  // Start at center
            cursor_y <= CANVAS_Y + CANVAS_H/2;
            move_counter <= 0;
        end else begin
            if (frame_start)
                move_counter <= move_counter + 1;
            
            if (move_tick) begin
                // Move cursor based on switch positions
                // SW[5]=left, SW[6]=right, SW[7]=up, SW[8]=down
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
    // Frame Buffer
    // ========================================
    logic [$clog2(CANVAS_W)-1:0] fb_write_x, fb_read_x;
    logic [$clog2(CANVAS_H)-1:0] fb_write_y, fb_read_y;
    logic fb_we;
    logic fb_pixel_in, fb_pixel_out;
    
    frame_buffer #(
        .WIDTH(CANVAS_W),
        .HEIGHT(CANVAS_H)
    ) canvas_fb (
        .clk(clk_25mhz),
        .we(fb_we),
        .addr_x_w(fb_write_x),
        .addr_y_w(fb_write_y),
        .pixel_in(fb_pixel_in),
        .addr_x_r(fb_read_x),
        .addr_y_r(fb_read_y),
        .pixel_out(fb_pixel_out)
    );
    
    // ========================================
    // Drawing Engine (modified for cursor input)
    // ========================================
    drawing_engine_cursor #(
        .CANVAS_X(CANVAS_X),
        .CANVAS_Y(CANVAS_Y),
        .CANVAS_W(CANVAS_W),
        .CANVAS_H(CANVAS_H),
        .BRUSH_SIZE(8)  // Larger brush for easier drawing
    ) drawer (
        .clk(clk_25mhz),
        .reset(reset_internal),
        .cursor_x(cursor_x),
        .cursor_y(cursor_y),
        .draw_enable(draw_enable),
        .clear_canvas(clear_pulse),
        .canvas_x(fb_write_x),
        .canvas_y(fb_write_y),
        .canvas_we(fb_we),
        .canvas_pixel(fb_pixel_in),
        .is_drawing()
    );
    
    // ========================================
    // Display Read Address
    // ========================================
    // Convert VGA coordinates to canvas coordinates for reading
    logic signed [10:0] rel_x, rel_y;
    assign rel_x = vga_x - CANVAS_X;
    assign rel_y = vga_y - CANVAS_Y;
    
    always_comb begin
        if (rel_x >= 0 && rel_x < CANVAS_W && rel_y >= 0 && rel_y < CANVAS_H) begin
            fb_read_x = rel_x[$clog2(CANVAS_W)-1:0];
            fb_read_y = rel_y[$clog2(CANVAS_H)-1:0];
        end else begin
            fb_read_x = 0;
            fb_read_y = 0;
        end
    end
    
    // ========================================
    // Pixel Color Generation
    // ========================================
    logic [7:0] red, green, blue;
    
    // Region detection
    logic in_canvas, in_border, in_cursor, in_title_area, in_info_area;
    
    always_comb begin
        in_canvas = (vga_x >= CANVAS_X) && (vga_x < CANVAS_X + CANVAS_W) &&
                    (vga_y >= CANVAS_Y) && (vga_y < CANVAS_Y + CANVAS_H);
        
        in_border = ((vga_x >= CANVAS_X - BORDER_W) && (vga_x < CANVAS_X + CANVAS_W + BORDER_W) &&
                     (vga_y >= CANVAS_Y - BORDER_W) && (vga_y < CANVAS_Y + CANVAS_H + BORDER_W)) &&
                    !in_canvas;
        
        // Cursor crosshair (5x5 cross pattern)
        in_cursor = ((vga_x == cursor_x || vga_x == cursor_x-1 || vga_x == cursor_x+1) && 
                     (vga_y >= cursor_y-4 && vga_y <= cursor_y+4)) ||
                    ((vga_y == cursor_y || vga_y == cursor_y-1 || vga_y == cursor_y+1) && 
                     (vga_x >= cursor_x-4 && vga_x <= cursor_x+4));
        
        in_title_area = (vga_y < 60);
        in_info_area = (vga_y >= CANVAS_Y + CANVAS_H + 20);
    end
    
    // Color muxing
    always_comb begin
        // Default background - dark gray
        red = 8'h30;
        green = 8'h30;
        blue = 8'h40;
        
        // Title area - blue banner
        if (in_title_area) begin
            red = 8'h20;
            green = 8'h40;
            blue = 8'h80;
            
            // Simple "DRAW" text indicator using position
            if (vga_y >= 20 && vga_y < 40) begin
                // Just show a lighter stripe where title would be
                if (vga_x >= 250 && vga_x < 390) begin
                    red = 8'hFF;
                    green = 8'hFF;
                    blue = 8'hFF;
                end
            end
        end
        
        // Canvas border - white
        else if (in_border) begin
            red = 8'hFF;
            green = 8'hFF;
            blue = 8'hFF;
        end
        
        // Canvas area
        else if (in_canvas) begin
            if (fb_pixel_out) begin
                // Drawn pixel - black
                red = 8'h00;
                green = 8'h00;
                blue = 8'h00;
            end else begin
                // Empty pixel - white
                red = 8'hFF;
                green = 8'hFF;
                blue = 8'hFF;
            end
        end
        
        // Info area - show status
        else if (in_info_area) begin
            red = 8'h20;
            green = 8'h20;
            blue = 8'h30;
            
            // Draw mode indicator bar
            if (vga_y >= 420 && vga_y < 430) begin
                if (draw_enable) begin
                    // Green bar when drawing enabled
                    if (vga_x >= 180 && vga_x < 460) begin
                        red = 8'h00;
                        green = 8'hC0;
                        blue = 8'h00;
                    end
                end else begin
                    // Red bar when not drawing
                    if (vga_x >= 180 && vga_x < 460) begin
                        red = 8'hC0;
                        green = 8'h00;
                        blue = 8'h00;
                    end
                end
            end
        end
        
        // Cursor overlay (red/magenta crosshair) - drawn on top
        if (in_cursor && in_canvas) begin
            if (draw_enable) begin
                red = 8'h00;      // Green cursor when drawing
                green = 8'hFF;
                blue = 8'h00;
            end else begin
                red = 8'hFF;      // Red cursor when not drawing
                green = 8'h00;
                blue = 8'h00;
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
        .rst(reset_internal),
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
    always_ff @(posedge clk_25mhz or posedge reset_internal) begin
        if (reset_internal)
            heartbeat_counter <= 0;
        else
            heartbeat_counter <= heartbeat_counter + 1;
    end
    
    assign led[0] = heartbeat_counter[23];  // Heartbeat
    assign led[1] = pll_locked;             // PLL locked
    assign led[2] = draw_enable;            // Draw mode active
    assign led[3] = draw_mode_latched;      // Latched draw mode
    assign led[4] = |sw[8:5];               // Any direction pressed
    assign led[5] = in_canvas && (vga_x == cursor_x) && (vga_y == cursor_y);  // Cursor visible
    assign led[6] = clear_pulse;            // Clear button
    assign led[7] = predict_pulse;          // Predict button

endmodule
