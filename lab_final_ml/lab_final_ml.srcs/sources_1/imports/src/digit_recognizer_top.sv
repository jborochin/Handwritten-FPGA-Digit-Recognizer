// Digit Recognizer with USB Mouse Support
// Uses lab 6.2 mb_usb block design for USB functionality
// 
// Controls:
//   Mouse left click  = Draw on canvas
//   Mouse right click = Clear canvas
//   Mouse middle click = Predict digit
//   BTN0: Reset

`timescale 1ns / 1ps

module digit_recognizer_top (
    // Clock and Reset
    input  logic        clk_100mhz,
    input  logic        reset_btn,          // Active high reset (directly to mb_usb)
    
    // USB Signals (directly controlled by MicroBlaze)
    input  logic [0:0]  gpio_usb_int_tri_i,
    output logic        gpio_usb_rst_tri_o,
    input  logic        usb_spi_miso,
    output logic        usb_spi_mosi,
    output logic        usb_spi_sclk,
    output logic        usb_spi_ss,
    
    // UART (directly to MicroBlaze)
    input  logic        uart_rtl_0_rxd,
    output logic        uart_rtl_0_txd,
    
    // HDMI Output
    output logic        hdmi_clk_p,
    output logic        hdmi_clk_n,
    output logic [2:0]  hdmi_data_p,
    output logic [2:0]  hdmi_data_n,
    
    // Debug LEDs
    output logic [7:0]  led,
    
    // HEX Displays (optional, for debug)
    output logic [7:0]  hex_segA,
    output logic [3:0]  hex_gridA,
    output logic [7:0]  hex_segB,
    output logic [3:0]  hex_gridB
);

    // ========================================
    // MicroBlaze USB System (from lab 6.2)
    // ========================================
    logic [31:0] keycode0_gpio, keycode1_gpio;
    
    mb_usb mb_block_i (
        .clk_100MHz(clk_100mhz),
        .gpio_usb_int_tri_i(gpio_usb_int_tri_i),
        .gpio_usb_keycode_0_tri_o(keycode0_gpio),
        .gpio_usb_keycode_1_tri_o(keycode1_gpio),
        .gpio_usb_rst_tri_o(gpio_usb_rst_tri_o),
        .reset_rtl_0(~reset_btn),  // mb_usb expects active LOW reset
        .uart_rtl_0_rxd(uart_rtl_0_rxd),
        .uart_rtl_0_txd(uart_rtl_0_txd),
        .usb_spi_miso(usb_spi_miso),
        .usb_spi_mosi(usb_spi_mosi),
        .usb_spi_sclk(usb_spi_sclk),
        .usb_spi_ss(usb_spi_ss)
    );
    
    // ========================================
    // Parse Mouse Data from GPIO
    // Format from C code:
    //   [9:0]   = X position
    //   [19:10] = Y position
    //   [20]    = Left button (draw)
    //   [21]    = Right button (clear)
    //   [22]    = Middle button (predict)
    // ========================================
    logic [9:0] mouse_x, mouse_y;
    logic mouse_left, mouse_right, mouse_middle;
    
    assign mouse_x     = keycode0_gpio[9:0];
    assign mouse_y     = keycode0_gpio[19:10];
    assign mouse_left  = keycode0_gpio[20];
    assign mouse_right = keycode0_gpio[21];
    assign mouse_middle = keycode0_gpio[22];
    
    // ========================================
    // Clock Generation (HDMI needs 25MHz and 125MHz)
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
    localparam CANVAS_X = 40;
    localparam CANVAS_Y = 100;
    localparam CANVAS_W = 280;
    localparam CANVAS_H = 280;
    localparam BORDER_W = 3;
    
    localparam RESULT_X = 400;
    localparam RESULT_Y = 150;
    
    // ========================================
    // Cursor Position (from mouse)
    // ========================================
    logic [9:0] cursor_x, cursor_y;
    
    // Synchronize mouse position to pixel clock domain
    logic [9:0] mouse_x_sync, mouse_y_sync;
    logic mouse_left_sync, mouse_right_sync, mouse_middle_sync;
    
    // Double-flop synchronizer for clock domain crossing
    logic [9:0] mouse_x_meta, mouse_y_meta;
    logic mouse_left_meta, mouse_right_meta, mouse_middle_meta;
    
    always_ff @(posedge clk_25mhz) begin
        // First stage
        mouse_x_meta <= mouse_x;
        mouse_y_meta <= mouse_y;
        mouse_left_meta <= mouse_left;
        mouse_right_meta <= mouse_right;
        mouse_middle_meta <= mouse_middle;
        // Second stage
        mouse_x_sync <= mouse_x_meta;
        mouse_y_sync <= mouse_y_meta;
        mouse_left_sync <= mouse_left_meta;
        mouse_right_sync <= mouse_right_meta;
        mouse_middle_sync <= mouse_middle_meta;
    end
    
    assign cursor_x = mouse_x_sync;
    assign cursor_y = mouse_y_sync;
    
    // ========================================
    // Button Edge Detection
    // ========================================
    logic mouse_right_prev, mouse_middle_prev;
    logic clear_pulse, predict_pulse;
    
    always_ff @(posedge clk_25mhz or posedge reset_sync) begin
        if (reset_sync) begin
            mouse_right_prev <= 0;
            mouse_middle_prev <= 0;
        end else begin
            mouse_right_prev <= mouse_right_sync;
            mouse_middle_prev <= mouse_middle_sync;
        end
    end
    
    // Rising edge detection
    assign clear_pulse = mouse_right_sync && !mouse_right_prev;
    assign predict_pulse = mouse_middle_sync && !mouse_middle_prev;
    
    // Draw enable is level-sensitive (draw while holding)
    logic draw_enable;
    assign draw_enable = mouse_left_sync;
    
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
    drawing_engine_cursor #(
        .CANVAS_X(CANVAS_X),
        .CANVAS_Y(CANVAS_Y),
        .CANVAS_W(CANVAS_W),
        .CANVAS_H(CANVAS_H),
        .BRUSH_SIZE(10)
    ) drawer (
        .clk(clk_25mhz),
        .reset(reset_sync),
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
    logic [15:0] confidence;
    logic show_result;
    
    always_ff @(posedge clk_25mhz or posedge reset_sync) begin
        if (reset_sync) begin
            state <= S_IDLE;
            show_result <= 0;
        end else begin
            state <= next_state;
            if (state == S_DONE)
                show_result <= 1;
            if (clear_pulse)
                show_result <= 0;
        end
    end
    
    always_comb begin
        next_state = state;
        ds_start = 0;
        nn_start = 0;
        
        case (state)
            S_IDLE: begin
                if (predict_pulse) begin
                    next_state = S_DOWNSAMPLE;
                    ds_start = 1;
                end
            end
            
            S_DOWNSAMPLE: begin
                if (ds_done) begin
                    next_state = S_INFERENCE;
                    nn_start = 1;
                end
            end
            
            S_INFERENCE: begin
                if (nn_done)
                    next_state = S_DONE;
            end
            
            S_DONE: begin
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
        .load_data({8'b0, ds_output_pixel})
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
    logic in_result_area;
    
    always_comb begin
        in_canvas = (vga_x >= CANVAS_X) && (vga_x < CANVAS_X + CANVAS_W) &&
                    (vga_y >= CANVAS_Y) && (vga_y < CANVAS_Y + CANVAS_H);
        
        in_border = ((vga_x >= CANVAS_X - BORDER_W) && (vga_x < CANVAS_X + CANVAS_W + BORDER_W) &&
                     (vga_y >= CANVAS_Y - BORDER_W) && (vga_y < CANVAS_Y + CANVAS_H + BORDER_W)) &&
                    !in_canvas;
        
        // Crosshair cursor
        in_cursor = ((vga_x == cursor_x || vga_x == cursor_x-1 || vga_x == cursor_x+1) && 
                     (vga_y >= cursor_y-6 && vga_y <= cursor_y+6)) ||
                    ((vga_y == cursor_y || vga_y == cursor_y-1 || vga_y == cursor_y+1) && 
                     (vga_x >= cursor_x-6 && vga_x <= cursor_x+6));
        
        in_result_area = (vga_x >= RESULT_X - 20) && (vga_x < RESULT_X + 120) &&
                         (vga_y >= RESULT_Y - 20) && (vga_y < RESULT_Y + 160);
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
            red = 8'h20;
            green = 8'h20;
            blue = 8'h20;
            
            // Border color based on state
            if (vga_x == RESULT_X - 20 || vga_x == RESULT_X + 119 ||
                vga_y == RESULT_Y - 20 || vga_y == RESULT_Y + 159) begin
                if (show_result) begin
                    red = 8'h00; green = 8'hFF; blue = 8'h00;
                end else begin
                    red = 8'h80; green = 8'h80; blue = 8'h80;
                end
            end
            
            // Digit
            if (digit_pixel) begin
                red = 8'h00;
                green = 8'hFF;
                blue = 8'h00;
            end
        end
        
        // Cursor overlay (green when drawing, red otherwise)
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
    // HEX Display (Debug - shows mouse X/Y and prediction)
    // ========================================
    // HexA shows: Y position (hex)
    // HexB shows: X position and prediction
    hex_driver HexA (
        .clk(clk_100mhz),
        .reset(reset_btn),
        .in('{mouse_y[3:0], mouse_y[7:4], mouse_x[3:0], mouse_x[7:4]}),
        .hex_seg(hex_segA),
        .hex_grid(hex_gridA)
    );
    
    hex_driver HexB (
        .clk(clk_100mhz),
        .reset(reset_btn),
        .in('{prediction, 4'h0, mouse_left_sync ? 4'hA : 4'h0, mouse_right_sync ? 4'hB : 4'h0}),
        .hex_seg(hex_segB),
        .hex_grid(hex_gridB)
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
    
    assign led[0] = heartbeat_counter[23];  // Heartbeat
    assign led[1] = pll_locked;             // PLL locked
    assign led[2] = draw_enable;            // Drawing
    assign led[3] = (state != S_IDLE);      // Processing
    assign led[4] = show_result;            // Result ready
    assign led[5] = mouse_left_sync;        // Left click
    assign led[6] = mouse_right_sync;       // Right click
    assign led[7] = mouse_middle_sync;      // Middle click

endmodule