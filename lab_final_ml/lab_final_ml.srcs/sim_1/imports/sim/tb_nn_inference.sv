// Neural Network Inference Testbench - Tests All 10 Images
`timescale 1ns / 1ps

module tb_nn_inference;

    localparam CLK_PERIOD = 10;
    localparam INPUT_SIZE = 784;
    
    logic clk, rst_n, start, done;
    logic [3:0] prediction;
    logic [31:0] confidence;
    logic load_input;
    logic [9:0] load_addr;
    logic signed [15:0] load_data;
    
    // Test image storage
    logic [15:0] test_image [0:INPUT_SIZE-1];
    
    // Test results tracking
    int correct_count = 0;
    int total_count = 0;
    
    nn_inference_simple #(
        .DATA_WIDTH(16),
        .ACC_WIDTH(48)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .prediction(prediction),
        .confidence(confidence),
        .load_input(load_input),
        .load_addr(load_addr),
        .load_data(load_data)
    );
    
    // Clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test procedure
    initial begin
        $display("========================================");
        $display("Neural Network Inference Testbench");
        $display("Testing All 10 MNIST Images");
        $display("========================================");
        
        rst_n = 0;
        start = 0;
        load_input = 0;
        load_addr = 0;
        load_data = 0;
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        // Test all 10 images
        for (int img_num = 0; img_num < 10; img_num++) begin
            if (img_num == 0) begin
                // Detailed diagnostics for first image
                test_single_image_diagnostic(img_num);
            end else begin
                // Brief output for remaining images
                test_single_image_brief(img_num);
            end
            total_count++;
        end
        
        // Print summary
        print_summary();
        
        $display("\n========================================");
        $display("Test Complete!");
        $display("========================================");
        $finish;
    end
    
    // Detailed test for first image (with diagnostics)
    task test_single_image_diagnostic(input int img_num);
        automatic string filename;
        automatic int expected_label;
        automatic real start_time, end_time, latency_ms;
        automatic int non_zero_count;
        automatic int file_handle;
        
        expected_label = get_expected_label(img_num);
        filename = $sformatf("test_image_%0d_label_%0d.hex", img_num, expected_label);
        
        $display("\n========================================");
        $display("DIAGNOSTIC MODE - Testing Image %0d (Expected: %0d)", img_num, expected_label);
        $display("========================================");
        
        // Clear array first
        $display("\n[1] Clearing test_image array...");
        for (int i = 0; i < INPUT_SIZE; i++) begin
            test_image[i] = 16'h0000;
        end
        
        // Check if file exists
        $display("\n[2] Attempting to load: %s", filename);
        file_handle = $fopen(filename, "r");
        if (file_handle == 0) begin
            $display("    ERROR: Cannot open file '%s'", filename);
            $finish;
        end else begin
            $display("    SUCCESS: File exists and is readable");
            $fclose(file_handle);
        end
        
        // Load hex file
        $display("\n[3] Loading hex file with $readmemh...");
        $readmemh(filename, test_image);
        
        // Detailed analysis of what was loaded
        $display("\n[4] Analyzing loaded data:");
        non_zero_count = 0;
        for (int i = 0; i < INPUT_SIZE; i++) begin
            if (test_image[i] != 0) non_zero_count++;
        end
        $display("    Total non-zero pixels: %0d / 784", non_zero_count);
        
        // Show sample pixels from different regions
        $display("\n[5] Sample pixel values from different regions:");
        $display("    Pixels [0-9]:       %h %h %h %h %h %h %h %h %h %h", 
                 test_image[0], test_image[1], test_image[2], test_image[3], test_image[4],
                 test_image[5], test_image[6], test_image[7], test_image[8], test_image[9]);
        $display("    Pixels [200-209]:   %h %h %h %h %h %h %h %h %h %h", 
                 test_image[200], test_image[201], test_image[202], test_image[203], test_image[204],
                 test_image[205], test_image[206], test_image[207], test_image[208], test_image[209]);
        
        // Find where non-zero pixels are
        $display("\n[6] Location of first 10 non-zero pixels:");
        begin
            int count = 0;
            for (int i = 0; i < INPUT_SIZE && count < 10; i++) begin
                if (test_image[i] != 0) begin
                    $display("    Index %3d: %h", i, test_image[i]);
                    count++;
                end
            end
        end
        
        // Load into DUT using proper interface
        $display("\n[7] Loading data into DUT via load_input interface...");
        for (int i = 0; i < INPUT_SIZE; i++) begin
            @(posedge clk);
            load_input = 1'b1;
            load_addr = i[9:0];
            load_data = $signed(test_image[i]);
        end
        @(posedge clk);
        load_input = 1'b0;
        $display("    Loading complete");
        
        // Verify data made it into DUT
        $display("\n[8] Verifying data in DUT.input_mem:");
        non_zero_count = 0;
        for (int i = 0; i < INPUT_SIZE; i++) begin
            if (dut.input_mem[i] != 0) non_zero_count++;
        end
        $display("    DUT has %0d non-zero pixels", non_zero_count);
        
        // Cross-check
        $display("\n[9] Cross-checking test_image vs DUT.input_mem:");
        begin
            int mismatch_count = 0;
            for (int i = 0; i < INPUT_SIZE; i++) begin
                if ($signed(test_image[i]) != dut.input_mem[i]) begin
                    if (mismatch_count < 5) begin
                        $display("    MISMATCH at [%0d]: test_image=%h, dut.input_mem=%h", 
                                i, test_image[i], dut.input_mem[i]);
                    end
                    mismatch_count++;
                end
            end
            if (mismatch_count == 0) begin
                $display("    SUCCESS: All %0d pixels match!", INPUT_SIZE);
            end else begin
                $display("    ERROR: %0d pixels don't match!", mismatch_count);
            end
        end
        
        // Start inference
        $display("\n[10] Starting inference...");
        start_time = $realtime;
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        wait(done);
        end_time = $realtime;
        latency_ms = (end_time - start_time) / 1_000_000.0;
        
        $display("\n[11] Inference Results:");
        $display("    Expected:   %0d", expected_label);
        $display("    Prediction: %0d", prediction);
        if (prediction == expected_label) begin
            $display("    Result: *** CORRECT! ***");
            correct_count++;
        end else begin
            $display("    Result: XXX WRONG XXX");
        end
        $display("    Confidence: %0d", $signed(confidence));
        $display("    Latency: %0.3f ms (%0d clock cycles)", 
                 latency_ms, int'((end_time - start_time) / CLK_PERIOD));
        
        $display("\n[12] Output layer values:");
        for (int i = 0; i < 10; i++) begin
            $display("    Digit %0d: %10d %s", i, $signed(dut.output_mem[i]),
                     (i == prediction) ? "<-- PREDICTED" : "");
        end
        
        #(CLK_PERIOD * 10);
    endtask
    
    // Brief test for remaining images
    task test_single_image_brief(input int img_num);
        automatic string filename;
        automatic int expected_label;
        automatic real start_time, end_time, latency_ms;
        automatic int non_zero_count;
        
        expected_label = get_expected_label(img_num);
        filename = $sformatf("test_image_%0d_label_%0d.hex", img_num, expected_label);
        
        $display("\n----------------------------------------");
        $display("Testing Image %0d (Expected: %0d)", img_num, expected_label);
        $display("----------------------------------------");
        
        // Clear and load image
        for (int i = 0; i < INPUT_SIZE; i++) begin
            test_image[i] = 16'h0000;
        end
        $readmemh(filename, test_image);
        
        // Quick verification
        non_zero_count = 0;
        for (int i = 0; i < INPUT_SIZE; i++) begin
            if (test_image[i] != 0) non_zero_count++;
        end
        $display("Loaded %0d non-zero pixels", non_zero_count);
        
        // Load into DUT
        for (int i = 0; i < INPUT_SIZE; i++) begin
            @(posedge clk);
            load_input = 1'b1;
            load_addr = i[9:0];
            load_data = $signed(test_image[i]);
        end
        @(posedge clk);
        load_input = 1'b0;
        
        // Start inference
        start_time = $realtime;
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        
        wait(done);
        end_time = $realtime;
        latency_ms = (end_time - start_time) / 1_000_000.0;
        
        // Print results
        $display("Expected: %0d | Prediction: %0d | Confidence: %0d", 
                 expected_label, prediction, $signed(confidence));
        if (prediction == expected_label) begin
            $display("Result: ? CORRECT");
            correct_count++;
        end else begin
            $display("Result: ? WRONG");
            $display("Output scores:");
            for (int i = 0; i < 10; i++) begin
                $display("  Digit %0d: %10d %s", i, $signed(dut.output_mem[i]),
                         (i == prediction) ? "<-- PREDICTED" : "");
            end
        end
        $display("Latency: %0.3f ms", latency_ms);
        
        #(CLK_PERIOD * 10);
    endtask
    
    // Helper function to get expected label for each image
    function int get_expected_label(input int img_num);
        case (img_num)
            0: return 7;
            1: return 2;
            2: return 1;
            3: return 0;
            4: return 4;
            5: return 1;
            6: return 4;
            7: return 9;
            8: return 5;
            9: return 9;
            default: return 0;
        endcase
    endfunction
    
    // Print test summary
    task print_summary();
        $display("\n");
        $display("========================================");
        $display("           TEST SUMMARY");
        $display("========================================");
        $display("Total Images Tested: %0d", total_count);
        $display("Correct Predictions: %0d", correct_count);
        $display("Wrong Predictions:   %0d", total_count - correct_count);
        $display("Accuracy:            %0.1f%%", (correct_count * 100.0) / total_count);
        $display("========================================");
        
        if (correct_count == total_count) begin
            $display("? PERFECT SCORE! All predictions correct!");
        end else if (correct_count >= 8) begin
            $display("? Good performance!");
        end else if (correct_count >= 5) begin
            $display("? Moderate performance - consider retraining");
        end else begin
            $display("? Poor performance - check implementation");
        end
    endtask
    
    initial begin
        $dumpfile("nn_inference.vcd");
        $dumpvars(0, tb_nn_inference);
    end
    
    initial begin
        #20_000_000;  // Longer timeout for 10 images
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule