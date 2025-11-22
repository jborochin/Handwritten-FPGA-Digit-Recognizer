// Testbench for Neural Network Inference
// Tests a single image classification

`timescale 1ns / 1ps

module tb_nn_inference;

    // Parameters
    localparam CLK_PERIOD = 10;  // 100 MHz
    localparam INPUT_SIZE = 784;
    
    // Signals
    logic clk;
    logic rst_n;
    logic start;
    logic done;
    logic [3:0] prediction;
    logic [31:0] confidence;
    
    // Test image storage
    logic [15:0] test_image [0:INPUT_SIZE-1];
    logic [3:0] expected_label;
    
    // Instantiate DUT (Design Under Test)
    nn_inference_top #(
        .DATA_WIDTH(16),
        .ACC_WIDTH(32)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .prediction(prediction),
        .confidence(confidence),
        // AXI interface tied off for now
        .s_axi_awaddr(32'h0),
        .s_axi_awvalid(1'b0),
        .s_axi_awready(),
        .s_axi_wdata(32'h0),
        .s_axi_wvalid(1'b0),
        .s_axi_wready(),
        .s_axi_bresp(),
        .s_axi_bvalid(),
        .s_axi_bready(1'b0),
        .s_axi_araddr(32'h0),
        .s_axi_arvalid(1'b0),
        .s_axi_arready(),
        .s_axi_rdata(),
        .s_axi_rresp(),
        .s_axi_rvalid(),
        .s_axi_rready(1'b0)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test procedure
    initial begin
        // Initialize
        $display("========================================");
        $display("Neural Network Inference Testbench");
        $display("========================================");
        
        rst_n = 0;
        start = 0;
        
        // Apply reset
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        // Test multiple images
        for (int img_num = 0; img_num < 5; img_num++) begin
            test_single_image(img_num);
        end
        
        $display("\n========================================");
        $display("Test Complete!");
        $display("========================================");
        $finish;
    end
    
    // Task to test a single image
    task test_single_image(input int img_num);
        automatic string filename;
        automatic int num_read;
        automatic real start_time, end_time, latency_ms;
        
        // Construct filename
        filename = $sformatf("test_image_%0d.hex", img_num);
        
        $display("\n----------------------------------------");
        $display("Testing Image %0d", img_num);
        $display("----------------------------------------");
        
        // Load test image
        $display("Loading %s...", filename);
        $readmemh(filename, test_image);
        
        // Get expected label from filename (assumes format: test_image_X_label_Y.hex)
        // For now, we'll just display what we get
        
        // Load image into DUT memory
        for (int i = 0; i < INPUT_SIZE; i++) begin
            dut.input_mem[i] = $signed(test_image[i]);
        end
        
        // Start inference
        $display("Starting inference...");
        start_time = $realtime;
        start = 1;
        #CLK_PERIOD;
        start = 0;
        
        // Wait for completion
        wait(done);
        end_time = $realtime;
        
        // Calculate latency
        latency_ms = (end_time - start_time) / 1_000_000.0;
        
        // Display results
        $display("Inference complete!");
        $display("  Prediction: %0d", prediction);
        $display("  Confidence: %0d", confidence);
        $display("  Latency: %0.3f ms (%0d clock cycles)", 
                 latency_ms, int'((end_time - start_time) / CLK_PERIOD));
        
        // Visual verification - display output layer values
        $display("\nOutput layer values:");
        for (int i = 0; i < 10; i++) begin
            $display("  Digit %0d: %0d %s", i, dut.output_mem[i],
                     (i == prediction) ? "<-- PREDICTED" : "");
        end
        
        // Wait before next test
        #(CLK_PERIOD * 10);
    endtask
    
    // Monitor for debugging
    initial begin
        $display("\nStarting waveform dump...");
        $dumpfile("nn_inference.vcd");
        $dumpvars(0, tb_nn_inference);
    end
    
    // Watchdog timer (prevent infinite simulation)
    initial begin
        #10_000_000;  // 10ms timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end
    
    // Performance monitoring
    integer cycle_count;
    always_ff @(posedge clk) begin
        if (start)
            cycle_count <= 0;
        else if (!done)
            cycle_count <= cycle_count + 1;
    end

endmodule


// Simplified testbench for MAC unit only
module tb_mac_unit;
    
    logic clk, rst_n, enable, clear_acc;
    logic signed [15:0] a, b;
    logic signed [31:0] acc;
    
    mac_unit #(
        .DATA_WIDTH(16),
        .ACC_WIDTH(32)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .clear_acc(clear_acc),
        .a(a),
        .b(b),
        .acc(acc)
    );
    
    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test
    initial begin
        $display("========================================");
        $display("MAC Unit Testbench");
        $display("========================================");
        
        rst_n = 0;
        enable = 0;
        clear_acc = 0;
        a = 0;
        b = 0;
        
        #20 rst_n = 1;
        #10;
        
        // Test 1: Simple accumulation
        $display("\nTest 1: Accumulate 3 products");
        clear_acc = 1;
        #10 clear_acc = 0;
        
        enable = 1;
        a = 16'd10;
        b = 16'd20;
        #10;  // Expect: 200
        
        a = 16'd5;
        b = 16'd30;
        #10;  // Expect: 200 + 150 = 350
        
        a = 16'd2;
        b = 16'd100;
        #10;  // Expect: 350 + 200 = 550
        
        enable = 0;
        #10;
        
        if (acc == 32'd550)
            $display("Test 1 PASSED: acc = %0d", acc);
        else
            $display("Test 1 FAILED: acc = %0d (expected 550)", acc);
        
        // Test 2: Clear and restart
        $display("\nTest 2: Clear accumulator");
        clear_acc = 1;
        #10 clear_acc = 0;
        #10;
        
        if (acc == 0)
            $display("Test 2 PASSED: acc cleared");
        else
            $display("Test 2 FAILED: acc = %0d (expected 0)", acc);
        
        // Test 3: Negative numbers
        $display("\nTest 3: Signed arithmetic");
        enable = 1;
        a = -16'd10;
        b = 16'd20;
        #10;  // Expect: -200
        
        if (acc == -32'd200)
            $display("Test 3 PASSED: acc = %0d", acc);
        else
            $display("Test 3 FAILED: acc = %0d (expected -200)", acc);
        
        $display("\n========================================");
        $display("MAC Unit Tests Complete");
        $display("========================================");
        $finish;
    end
    
    initial begin
        $dumpfile("mac_unit.vcd");
        $dumpvars(0, tb_mac_unit);
    end

endmodule
