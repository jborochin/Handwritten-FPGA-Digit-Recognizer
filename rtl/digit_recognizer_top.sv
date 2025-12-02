// Top-Level Module for Interactive Digit Recognition
// ECE 385 - Spartan 7 Urbana Board
// 
// Features:
// - VGA display with drawing canvas
// - PS/2 mouse input for drawing
// - Neural network digit recognition
// - Interactive buttons (Predict, Clear)

`timescale 1ns / 1ps

module digit_recognizer_top (
    // Clock and Reset
    input  logic        clk_100mhz,
    input  logic        reset_btn,
    
    // VGA Outputs
    output logic [3:0]  vga_r,
    output logic [3:0]  vga_g,
    output logic [3:0]  vga_b,
    output logic        vga_hs,
    output logic        vga_vs,
    
    // PS/2 Mouse
    inout  wire         ps2_clk,
    inout  wire         ps2_data,
    
    // Debug LEDs (optional)
    output logic [15:0] led
);

    // ========================================
    // Clock Generation
    // ========================================
    logic clk_25mhz;  // VGA pixel clock
    logic locked;
    
    clk_wiz_0 clk_gen (
        .clk_in1(clk_100mhz),
        .clk_out1(clk_25mhz),   // 25 MHz for VGA
        .reset(reset_btn),
        .locked(locked)
    );
    
    logic reset;
    assign reset = reset_btn || !locked;
    
    // ========================================
    // VGA Signals
    // ========================================
    logic [9:0] vga_x, vga_y;
    logic video_on, pixel_tick;
    logic [11:0] rgb_out;
    
    vga_controller vga_ctrl (
        .clk(clk_25mhz),
        .reset(reset),
        .hsync(vga_hs),
        .vsync(vga_vs),
        .video_on(video_on),
        .pixel_x(vga_x),
        .pixel_y(vga_y),
        .pixel_tick(pixel_tick)
    );
    
    // RGB output
    assign vga_r = video_on ? rgb_out[11:8] : 4'b0;
    assign vga_g = video_on ? rgb_out[7:4]  : 4'b0;
    assign vga_b = video_on ? rgb_out[3:0]  : 4'b0;
    
    // ========================================
    // Mouse Input
    // ========================================
    logic [9:0] mouse_x, mouse_y;
    logic mouse_left, mouse_right;
    logic mouse_valid;
    
    mouse_controller mouse (
        .clk(clk_100mhz),
        .reset(reset),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .mouse_x(mouse_x),
        .mouse_y(mouse_y),
        .left_button(mouse_left),
        .right_button(mouse_right),
        .valid(mouse_valid)
    );
    
    // ========================================
    // Frame Buffer (Drawing Canvas)
    // ========================================
    
    // Drawing area: 280×280 pixels starting at (20, 60)
    localparam CANVAS_X = 20;
    localparam CANVAS_Y = 60;
    localparam CANVAS_W = 280;
    localparam CANVAS_H = 280;
    
    logic [9:0] canvas_addr_x, canvas_addr_y;
    logic canvas_we;
    logic canvas_pixel_in, canvas_pixel_out;
    
    frame_buffer #(
        .WIDTH(CANVAS_W),
        .HEIGHT(CANVAS_H)
    ) canvas (
        .clk(clk_25mhz),
        
        // Write port (drawing)
        .we(canvas_we),
        .addr_x_w(canvas_addr_x),
        .addr_y_w(canvas_addr_y),
        .pixel_in(canvas_pixel_in),
        
        // Read port (VGA display)
        .addr_x_r(vga_x - CANVAS_X),
        .addr_y_r(vga_y - CANVAS_Y),
        .pixel_out(canvas_pixel_out)
    );
    
    // ========================================
    // Drawing Engine
    // ========================================
    logic drawing_active;
    
    drawing_engine drawer (
        .clk(clk_100mhz),
        .reset(reset),
        .mouse_x(mouse_x),
        .mouse_y(mouse_y),
        .mouse_btn(mouse_left),
        .drawing_enabled(state == DRAWING),
        .clear_canvas(clear_trigger),
        .canvas_x(canvas_addr_x),
        .canvas_y(canvas_addr_y),
        .canvas_we(canvas_we),
        .canvas_pixel(canvas_pixel_in),
        .is_drawing(drawing_active)
    );
    
    // ========================================
    // UI Elements
    // ========================================
    
    // Button definitions
    localparam BTN_X = 320;
    localparam PREDICT_BTN_Y = 80;
    localparam CLEAR_BTN_Y = 180;
    localparam BTN_W = 280;
    localparam BTN_H = 60;
    
    logic predict_clicked, clear_clicked;
    
    button_detector predict_btn (
        .clk(clk_100mhz),
        .reset(reset),
        .mouse_x(mouse_x),
        .mouse_y(mouse_y),
        .mouse_click(mouse_left && mouse_valid),
        .btn_x(BTN_X),
        .btn_y(PREDICT_BTN_Y),
        .btn_w(BTN_W),
        .btn_h(BTN_H),
        .clicked(predict_clicked)
    );
    
    button_detector clear_btn (
        .clk(clk_100mhz),
        .reset(reset),
        .mouse_x(mouse_x),
        .mouse_y(mouse_y),
        .mouse_click(mouse_left && mouse_valid),
        .btn_x(BTN_X),
        .btn_y(CLEAR_BTN_Y),
        .btn_w(BTN_W),
        .btn_h(BTN_H),
        .clicked(clear_clicked)
    );
    
    // ========================================
    // State Machine
    // ========================================
    
    typedef enum logic [2:0] {
        DRAWING,
        PREDICT_START,
        PREDICT_DOWNSAMPLE,
        PREDICT_NN,
        DISPLAY_RESULT
    } state_t;
    
    state_t state, next_state;
    
    logic predict_trigger, clear_trigger;
    logic [3:0] prediction;
    logic [31:0] confidence;
    logic nn_start, nn_done;
    
    always_ff @(posedge clk_100mhz or posedge reset) begin
        if (reset)
            state <= DRAWING;
        else
            state <= next_state;
    end
    
    always_comb begin
        next_state = state;
        predict_trigger = 0;
        clear_trigger = 0;
        nn_start = 0;
        
        case (state)
            DRAWING: begin
                if (predict_clicked)
                    next_state = PREDICT_START;
                else if (clear_clicked)
                    clear_trigger = 1;
            end
            
            PREDICT_START: begin
                predict_trigger = 1;
                next_state = PREDICT_DOWNSAMPLE;
            end
            
            PREDICT_DOWNSAMPLE: begin
                // Wait for downsampling to complete
                if (downsample_done)
                    next_state = PREDICT_NN;
            end
            
            PREDICT_NN: begin
                nn_start = 1;
                if (nn_done)
                    next_state = DISPLAY_RESULT;
            end
            
            DISPLAY_RESULT: begin
                // Stay here, can draw more or clear
                if (clear_clicked) begin
                    clear_trigger = 1;
                    next_state = DRAWING;
                end
            end
        endcase
    end
    
    // ========================================
    // Image Downsampler
    // ========================================
    
    logic downsample_start, downsample_done;
    logic [9:0] downsample_addr;
    logic [7:0] downsample_pixel;
    
    assign downsample_start = (state == PREDICT_DOWNSAMPLE);
    
    image_downsampler downsampler (
        .clk(clk_100mhz),
        .reset(reset),
        .start(downsample_start),
        .done(downsample_done),
        
        // Read from canvas
        .canvas_x_req(/* connected to canvas read */),
        .canvas_y_req(/* connected to canvas read */),
        .canvas_pixel(canvas_pixel_out),
        
        // Output 28×28 image
        .output_addr(downsample_addr),
        .output_pixel(downsample_pixel)
    );
    
    // ========================================
    // Neural Network
    // ========================================
    
    logic nn_load_input;
    logic [9:0] nn_load_addr;
    logic signed [15:0] nn_load_data;
    
    nn_inference_simple #(
        .DATA_WIDTH(16),
        .ACC_WIDTH(48)
    ) neural_network (
        .clk(clk_100mhz),
        .rst_n(~reset),
        .start(nn_start),
        .done(nn_done),
        .prediction(prediction),
        .confidence(confidence),
        .load_input(nn_load_input),
        .load_addr(nn_load_addr),
        .load_data(nn_load_data)
    );
    
    // Connect downsampler output to NN input
    assign nn_load_input = (state == PREDICT_DOWNSAMPLE);
    assign nn_load_addr = downsample_addr;
    assign nn_load_data = $signed({8'b0, downsample_pixel}); // Extend to 16-bit
    
    // ========================================
    // Display Logic
    // ========================================
    
    logic [11:0] ui_rgb;
    
    ui_display display (
        .vga_x(vga_x),
        .vga_y(vga_y),
        .canvas_pixel(canvas_pixel_out),
        .prediction(prediction),
        .confidence(confidence),
        .show_result(state == DISPLAY_RESULT),
        .rgb_out(ui_rgb)
    );
    
    assign rgb_out = ui_rgb;
    
    // ========================================
    // Debug LEDs
    // ========================================
    
    assign led[3:0] = prediction;
    assign led[4] = nn_done;
    assign led[5] = drawing_active;
    assign led[7:6] = state[1:0];
    assign led[15:8] = 8'b0;
    
endmodule
