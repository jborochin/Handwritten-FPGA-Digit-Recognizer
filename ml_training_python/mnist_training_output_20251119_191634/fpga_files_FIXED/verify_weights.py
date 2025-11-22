#!/usr/bin/env python3
"""
Verification script to check if weights are correct
This mimics EXACTLY what the HDL does
"""

import numpy as np
import sys

def load_hex_signed_16bit(filename):
    """Load hex file and convert to signed 16-bit integers"""
    data = []
    try:
        with open(filename, 'r') as f:
            for line in f:
                line = line.strip()
                if line:  # Skip empty lines
                    val = int(line, 16)
                    # Convert to signed 16-bit
                    if val >= 0x8000:
                        val -= 0x10000
                    data.append(val)
    except FileNotFoundError:
        print(f"ERROR: Could not find {filename}")
        print(f"Make sure you run this script in the directory with your .hex files")
        sys.exit(1)
    return np.array(data, dtype=np.int32)

print("="*60)
print("Neural Network Verification Script")
print("="*60)

# Load weights and biases
print("\nLoading weights and biases...")
W1_flat = load_hex_signed_16bit('weights_layer0.hex')
b1 = load_hex_signed_16bit('biases_layer0.hex')
W2_flat = load_hex_signed_16bit('weights_layer1.hex')
b2 = load_hex_signed_16bit('biases_layer1.hex')

print(f"  W1: {len(W1_flat)} values (expected: 100352)")
print(f"  b1: {len(b1)} values (expected: 128)")
print(f"  W2: {len(W2_flat)} values (expected: 1280)")
print(f"  b2: {len(b2)} values (expected: 10)")

if len(W1_flat) != 100352 or len(b1) != 128 or len(W2_flat) != 1280 or len(b2) != 10:
    print("\nERROR: Weight/bias sizes don't match expected values!")
    sys.exit(1)

# Reshape weights to match HDL indexing
# HDL uses: weights_layer1[hidden_idx * INPUT_SIZE + input_idx]
# This means each hidden neuron has its own row of INPUT_SIZE weights
print("\nReshaping weight matrices...")
print("  W1: Interpreting as [hidden_size=128, input_size=784]")
W1 = W1_flat.reshape(128, 784)  # Each row is one hidden neuron's weights
print("  W2: Interpreting as [output_size=10, hidden_size=128]")
W2 = W2_flat.reshape(10, 128)   # Each row is one output neuron's weights

# Load test image
print("\nLoading test image 0 (expected label: 7)...")
img = load_hex_signed_16bit('test_image_0_label_7.hex')
print(f"  Image: {len(img)} pixels")
print(f"  Non-zero pixels: {np.count_nonzero(img)}")

if len(img) != 784:
    print(f"\nERROR: Image should have 784 pixels, got {len(img)}")
    sys.exit(1)

# LAYER 1 - Exactly mimicking HDL
print("\nComputing Layer 1 (hidden layer)...")
hidden = np.zeros(128, dtype=np.int64)

for h in range(128):
    # Accumulator for this hidden neuron
    acc = np.int64(0)
    
    # MAC operation: accumulate input[i] * weight[h, i]
    for i in range(784):
        acc += np.int64(img[i]) * np.int64(W1[h, i])
    
    # Add bias (scaled by 256)
    acc += np.int64(b1[h]) * 256
    
    # ReLU
    if acc > 0:
        hidden[h] = acc
    else:
        hidden[h] = 0

print(f"  First 5 hidden values: {hidden[0:5]}")
print(f"  Non-zero hidden neurons: {np.count_nonzero(hidden)}")

# LAYER 2 - Exactly mimicking HDL
print("\nComputing Layer 2 (output layer)...")
output = np.zeros(10, dtype=np.int64)

for o in range(10):
    # Accumulator for this output neuron
    acc = np.int64(0)
    
    # MAC operation: accumulate (hidden[h] >> 8) * weight[o, h]
    for h in range(128):
        # Scale hidden value by dividing by 256 (>> 8)
        hidden_scaled = hidden[h] >> 8
        acc += hidden_scaled * np.int64(W2[o, h])
    
    # Add bias (scaled by 256)
    acc += np.int64(b2[o]) * 256
    
    output[o] = acc

print("\n" + "="*60)
print("RESULTS")
print("="*60)
print("\nOutput layer values:")
for i in range(10):
    marker = " <-- PREDICTED" if i == np.argmax(output) else ""
    print(f"  Digit {i}: {output[i]:10d}{marker}")

predicted = np.argmax(output)
expected = 7

print(f"\nExpected:   {expected}")
print(f"Prediction: {predicted}")

if predicted == expected:
    print("Result: *** CORRECT! ***")
    print("\n✓ Your weights/biases are working correctly in Python!")
    print("✗ The bug must be in your HDL implementation")
else:
    print("Result: XXX WRONG XXX")
    print("\n✗ Python simulation gives SAME wrong answer as HDL")
    print("→ The bug is in how weights were saved/organized")
    print("→ Check your Python training code that generated the .hex files")
    
print("\n" + "="*60)
print("Diagnosis:")
print("="*60)

if predicted == 4:
    print("Python predicts 4 (same as HDL)")
    print("\nPossible issues:")
    print("1. Weight matrix is transposed in your training code")
    print("2. Weights were flattened in wrong order (use .flatten('C') not 'F')")
    print("3. Wrong quantization/scaling when converting to int16")
    print("\nPlease share your Python code that:")
    print("  - Trains the model")
    print("  - Converts weights to int16")
    print("  - Saves to .hex files")
elif predicted == expected:
    print("Python predicts correctly (7) but HDL predicts wrong (4)")
    print("\nPossible HDL bugs:")
    print("1. Weight indexing: weights_layer1[hidden_idx * INPUT_SIZE + input_idx]")
    print("2. Accumulator overflow (use bigger accumulator width)")
    print("3. Shift operation (>>> 8 for arithmetic right shift)")
    print("4. Signed vs unsigned arithmetic")
else:
    print(f"Python predicts {predicted} (different from HDL's 4)")
    print("This is unexpected! Please share:")
    print("  - Your HDL simulation output")
    print("  - Your weight generation Python code")

print("="*60)
