// Button Debounce Module
// Generates clean button output and one-cycle pulse on press

`timescale 1ns / 1ps

module button_debounce #(
    parameter COUNTER_WIDTH = 20  // ~40ms at 25MHz
)(
    input  logic clk,
    input  logic reset,
    input  logic btn_in,          // Raw button input (active high)
    output logic btn_out,         // Debounced button state
    output logic btn_pulse        // One-cycle pulse on button press
);

    logic [COUNTER_WIDTH-1:0] counter;
    logic btn_sync1, btn_sync2;   // Synchronizer
    logic btn_stable;
    logic btn_prev;
    
    // Two-stage synchronizer for metastability
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            btn_sync1 <= 1'b0;
            btn_sync2 <= 1'b0;
        end else begin
            btn_sync1 <= btn_in;
            btn_sync2 <= btn_sync1;
        end
    end
    
    // Debounce counter
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            btn_stable <= 1'b0;
        end else begin
            if (btn_sync2 != btn_stable) begin
                // Input changed, start counting
                if (counter == {COUNTER_WIDTH{1'b1}}) begin
                    // Counter saturated, accept new state
                    btn_stable <= btn_sync2;
                    counter <= 0;
                end else begin
                    counter <= counter + 1;
                end
            end else begin
                // Input matches stable state, reset counter
                counter <= 0;
            end
        end
    end
    
    // Edge detection for pulse output
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            btn_prev <= 1'b0;
        else
            btn_prev <= btn_stable;
    end
    
    assign btn_out = btn_stable;
    assign btn_pulse = btn_stable && !btn_prev;  // Rising edge

endmodule
