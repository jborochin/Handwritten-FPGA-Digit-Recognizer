#!/usr/bin/env python3
"""
Hardware vs Software Inference Comparison
Debug script to understand quantization mismatches
"""

import numpy as np
import glob
import os

# Find training output
output_folders = glob.glob("mnist_training_output_*")
if not output_folders:
    print("ERROR: No training folders found!")
    exit(1)

latest_folder = max(output_folders, key=os.path.getctime)
print(f"Using: {latest_folder}\n")

# Load layers
layers_info = []
for i in range(2):  # 2 layers
    w_quant = np.load(os.path.join(latest_folder, f'layer_{i}_weights_quantized.npy'))
    b_quant = np.load(os.path.join(latest_folder, f'layer_{i}_biases_quantized.npy'))
    
    with open(os.path.join(latest_folder, f'layer_{i}_scales.txt'), 'r') as f:
        lines = f.readlines()
        w_scale = float(lines[0].split('=')[1])
        b_scale = float(lines[1].split('=')[1])
    
    layers_info.append({
        'w_quant': w_quant,
        'b_quant': b_quant,
        'w_scale': w_scale,
        'b_scale': b_scale
    })
    
    print(f"Layer {i}:")
    print(f"  Weights: {w_quant.shape}, scale={w_scale:.2f}")
    print(f"  Biases: {b_quant.shape}, scale={b_scale:.2f}")
    print(f"  Weight range: [{w_quant.min()}, {w_quant.max()}]")
    print(f"  Bias range: [{b_quant.min()}, {b_quant.max()}]")
    print()

def python_inference(image_flat, layers_info, debug=False):
    """Python reference implementation - EXACTLY as in training"""
    x = image_flat
    
    for i, info in enumerate(layers_info):
        if debug:
            print(f"\n=== Layer {i} ===")
            print(f"Input range: [{x.min():.3f}, {x.max():.3f}]")
        
        # Scale input to match quantized weights
        if i == 0:
            x_scaled = (x * info['w_scale']).astype(np.int64)
        else:
            x_scaled = x
        
        if debug:
            print(f"Scaled input range: [{x_scaled.min()}, {x_scaled.max()}]")
        
        # Matrix multiply + bias
        output = np.dot(x_scaled, info['w_quant']) + info['b_quant'] * info['w_scale']
        
        if debug:
            print(f"After MAC range: [{output.min()}, {output.max()}]")
            print(f"First 3 outputs: {output[:3]}")
        
        # ReLU (except for last layer)
        if i < len(layers_info) - 1:
            output = np.maximum(0, output)
            if debug:
                print(f"After ReLU range: [{output.min()}, {output.max()}]")
        
        x = output
    
    prediction = np.argmax(output)
    
    if debug:
        print(f"\n=== Final Output ===")
        print("All outputs:")
        for j, val in enumerate(output):
            marker = " <-- PREDICTED" if j == prediction else ""
            print(f"  Digit {j}: {val}{marker}")
    
    return prediction, output

# Load test image 0
print("="*60)
print("TESTING IMAGE 0 (Label should be 7)")
print("="*60)

# Load from FPGA files
fpga_folder = os.path.join(latest_folder, "fpga_files")
test_img_file = os.path.join(fpga_folder, "test_image_0_label_7.hex")

if os.path.exists(test_img_file):
    # Read hex file
    with open(test_img_file, 'r') as f:
        hex_values = [line.strip() for line in f if line.strip()]
    
    # Convert to integers (assuming 16-bit signed)
    img_quantized = np.array([int(h, 16) if int(h, 16) < 32768 else int(h, 16) - 65536 
                              for h in hex_values], dtype=np.int16)
    
    # Scale back to [0, 1] range for Python
    img_float = img_quantized.astype(np.float32) / 256.0
    
    print(f"Loaded image: {len(img_quantized)} pixels")
    print(f"Image range (quantized): [{img_quantized.min()}, {img_quantized.max()}]")
    print(f"Image range (float): [{img_float.min():.3f}, {img_float.max():.3f}]")
    
    # Run inference
    pred, outputs = python_inference(img_float, layers_info, debug=True)
    
    print(f"\n{'='*60}")
    print(f"PYTHON PREDICTION: {pred}")
    print(f"{'='*60}")
    
    # Show what hardware should compute
    print(f"\n{'='*60}")
    print("HARDWARE SHOULD SEE:")
    print(f"{'='*60}")
    
    print("\nLayer 1:")
    print(f"  Input: {img_quantized[:5]} ... (scaled [0-255])")
    print(f"  Weight[0,0]: {layers_info[0]['w_quant'][0,0]}")
    print(f"  Bias[0]: {layers_info[0]['b_quant'][0]}")
    print(f"  w_scale: {layers_info[0]['w_scale']:.2f}")
    
    # Compute first hidden neuron manually
    x_scaled = (img_float * layers_info[0]['w_scale']).astype(np.int64)
    first_neuron = np.dot(x_scaled, layers_info[0]['w_quant'][:,0]) + \
                   layers_info[0]['b_quant'][0] * layers_info[0]['w_scale']
    print(f"  First hidden neuron output: {first_neuron}")
    print(f"  After ReLU: {max(0, first_neuron)}")
    
else:
    print(f"ERROR: Could not find {test_img_file}")
    print("Make sure you ran convert_weights_to_fpga.py")

print("\n" + "="*60)
print("HARDWARE IMPLEMENTATION HINTS:")
print("="*60)
print(f"""
Based on the scales:
  Layer 0 w_scale = {layers_info[0]['w_scale']:.2f}
  Layer 1 w_scale = {layers_info[1]['w_scale']:.2f}

Hardware should do:
1. Layer 1:
   - Input is [0-255] (representing [0-1] * 256)
   - Multiply: input * weight (both are integers)
   - Add: bias * w_scale
   - ReLU: max(0, result)
   - Output range will be large (~millions)

2. Layer 2:
   - Input is large values from Layer 1
   - Need to scale down before multiply
   - Try: (hidden / 256) * weight OR (hidden * weight) / 256
   - Add: bias * w_scale  
   - Output should show clear winner

The key is matching the Python formula EXACTLY:
  output = dot(x_scaled, w_quant) + b_quant * w_scale
""")
