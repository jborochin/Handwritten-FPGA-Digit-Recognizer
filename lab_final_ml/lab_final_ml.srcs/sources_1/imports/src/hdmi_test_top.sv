`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// HDMI Test Pattern Top Module for Urbana Board
// 
// Generates test patterns and outputs via HDMI.
// Uses RealDigital's VGA-to-HDMI IP core for TMDS encoding.
//////////////////////////////////////////////////////////////////////////////////

module hdmi_test_top (
    // Clock and Reset
    input  logic        clk_100mhz,     // 100 MHz system clock
    input  logic        reset_btn,       // Reset button (active high)
    
    // User Interface
    input  logic [15:0] SW,             // Slide switches
    output logic [7:0]  LED,            // LEDs (only 8 to avoid bad pins)
    
    // HDMI Output
    output logic        hdmi_clk_p,     // TMDS Clock positive
    output logic        hdmi_clk_n,     // TMDS Clock negative
    output logic [2:0]  hdmi_tx_p,      // TMDS Data positive
    output logic [2:0]  hdmi_tx_n       // TMDS Data negative
);

    //=========================================================================
    // Internal Signals
    //=========================================================================
    
    // Clock signals from Clocking Wizard
    logic clk_25mhz;        // 25 MHz pixel clock
    logic clk_125mhz;       // 125 MHz (5x pixel clock) for TMDS
    logic pll_locked;       // PLL lock indicator
    
    // Reset synchronization
    logic rst_sync;
    logic [2:0] rst_pipe;
    
    // VGA signals
    logic        hsync, vsync, vde;
    logic [9:0]  px, py;
    logic [7:0]  red, green, blue;
    
    // Heartbeat counter
    logic [24:0] heartbeat_cnt;

    //=========================================================================
    // Reset Synchronization
    //=========================================================================
    always_ff @(posedge clk_25mhz or posedge reset_btn) begin
        if (reset_btn) begin
            rst_pipe <= 3'b111;
        end else begin
            rst_pipe <= {rst_pipe[1:0], ~pll_locked};
        end
    end
    assign rst_sync = rst_pipe[2];

    //=========================================================================
    // Clocking Wizard
    // Input: 100 MHz, Output1: 25 MHz, Output2: 125 MHz
    //=========================================================================
    clk_wiz_0 clk_wizard_inst (
        .clk_in1    (clk_100mhz),
        .clk_out1   (clk_25mhz),
        .clk_out2   (clk_125mhz),
        .reset      (reset_btn),
        .locked     (pll_locked)
    );

    //=========================================================================
    // VGA Sync Generator
    //=========================================================================
    vga_sync vga_sync_inst (
        .clk    (clk_25mhz),
        .rst    (rst_sync),
        .hsync  (hsync),
        .vsync  (vsync),
        .vde    (vde),
        .px     (px),
        .py     (py)
    );

    //=========================================================================
    // Test Pattern Generator
    //=========================================================================
    test_pattern test_pattern_inst (
        .clk        (clk_25mhz),
        .rst        (rst_sync),
        .pattern    (SW[1:0]),
        .vde        (vde),
        .px         (px),
        .py         (py),
        .red        (red),
        .green      (green),
        .blue       (blue)
    );

    //=========================================================================
    // HDMI TX IP Core (RealDigital VGA-to-HDMI converter)
    //=========================================================================
    hdmi_tx_0 hdmi_tx_inst (
        // Clocking
        .pix_clk        (clk_25mhz),
        .pix_clkx5      (clk_125mhz),
        .pix_clk_locked (pll_locked),
        
        // Reset (active HIGH)
        .rst            (rst_sync),
        
        // Video Input
        .red            (red),
        .green          (green),
        .blue           (blue),
        .hsync          (hsync),
        .vsync          (vsync),
        .vde            (vde),
        
        // Auxiliary Data (unused)
        .aux0_din       (4'b0),
        .aux1_din       (4'b0),
        .aux2_din       (4'b0),
        .ade            (1'b0),
        
        // TMDS Outputs
        .TMDS_CLK_P     (hdmi_clk_p),
        .TMDS_CLK_N     (hdmi_clk_n),
        .TMDS_DATA_P    (hdmi_tx_p),
        .TMDS_DATA_N    (hdmi_tx_n)
    );

    //=========================================================================
    // LED Indicators
    //=========================================================================
    
    // Heartbeat
    always_ff @(posedge clk_25mhz) begin
        if (rst_sync)
            heartbeat_cnt <= 0;
        else
            heartbeat_cnt <= heartbeat_cnt + 1;
    end
    
    // LED assignments
    assign LED[0] = heartbeat_cnt[24];      // Heartbeat (~0.75 Hz blink)
    assign LED[1] = pll_locked;             // PLL locked
    assign LED[2] = vde;                    // VDE (will flicker fast)
    assign LED[3] = hsync;                  // HSYNC 
    assign LED[4] = vsync;                  // VSYNC  
    assign LED[7:5] = SW[7:5];              // Echo some switches

endmodule