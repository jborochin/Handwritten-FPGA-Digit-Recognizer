#!/usr/bin/env python3
"""
FIXED weight generator - handles transposed weight matrices
"""

import numpy as np
import os
import glob

print("Looking for trained model weights...")
output_folders = glob.glob("mnist_training_output_*")
if not output_folders:
    output_folders = [d for d in os.listdir('.') if d.startswith('mnist_training_output_') and os.path.isdir(d)]

if not output_folders:
    print("ERROR: No training output folders found!")
    exit(1)

latest_folder = max(output_folders, key=os.path.getctime)
print(f"Using model from: {latest_folder}")

fpga_folder = os.path.join(latest_folder, "fpga_files_FIXED")
os.makedirs(fpga_folder, exist_ok=True)
print(f"FPGA files will be saved to: {fpga_folder}")

# Load layers
layer_files = sorted([f for f in os.listdir(latest_folder) if f.startswith('layer_') and f.endswith('_weights_quantized.npy')])
num_layers = len(layer_files)

print(f"\nFound {num_layers} layers")

layers_info = []
for i in range(num_layers):
    w_quant = np.load(os.path.join(latest_folder, f'layer_{i}_weights_quantized.npy'))
    b_quant = np.load(os.path.join(latest_folder, f'layer_{i}_biases_quantized.npy'))
    
    # Load scales
    with open(os.path.join(latest_folder, f'layer_{i}_scales.txt'), 'r') as f:
        lines = f.readlines()
        w_scale = float(lines[0].split('=')[1])
        b_scale = float(lines[1].split('=')[1])
    
    # Convert to int16 if needed
    if w_quant.dtype != np.int16:
        print(f"  Layer {i}: Converting from {w_quant.dtype} to int16...")
        w_quant = np.clip(w_quant, -32767, 32767).astype(np.int16)
        b_quant = np.clip(b_quant, -32767, 32767).astype(np.int16)
    
    print(f"  Layer {i}: Original shape: {w_quant.shape}")
    
    # CRITICAL FIX: Transpose if needed
    if i == 0:
        # Layer 0: Input (784) -> Hidden (128)
        # HDL expects: [128 neurons, 784 inputs each]
        if w_quant.shape == (784, 128):
            print(f"    → Transposing to {(128, 784)} to match HDL expectations")
            w_quant = w_quant.T
        elif w_quant.shape == (128, 784):
            print(f"    → Shape is correct for HDL")
        else:
            print(f"    → WARNING: Unexpected shape!")
    elif i == 1:
        # Layer 1: Hidden (128) -> Output (10)
        # HDL expects: [10 neurons, 128 inputs each]
        if w_quant.shape == (128, 10):
            print(f"    → Transposing to {(10, 128)} to match HDL expectations")
            w_quant = w_quant.T
        elif w_quant.shape == (10, 128):
            print(f"    → Shape is correct for HDL")
        else:
            print(f"    → WARNING: Unexpected shape!")
    
    layers_info.append({
        'w_quant': w_quant,
        'b_quant': b_quant,
        'w_scale': w_scale,
        'b_scale': b_scale
    })
    
    print(f"    Final shape: {w_quant.shape}")
    print(f"    Weight range: [{w_quant.min()}, {w_quant.max()}]")

def write_hex_file(data, filename):
    """Write data as hexadecimal values (for $readmemh)"""
    with open(filename, 'w') as f:
        # IMPORTANT: Use 'C' order (row-major) to match HDL indexing
        for value in data.flatten('C'):
            value = int(value)
            if value < 0:
                hex_val = 65536 + value
            else:
                hex_val = value
            f.write(f"{hex_val:04X}\n")

print("\nGenerating FIXED FPGA memory files...")

# Generate files for each layer
for i, info in enumerate(layers_info):
    print(f"\nLayer {i}:")
    
    # Weights
    weights = info['w_quant']
    print(f"  Writing weights... (shape: {weights.shape}, {weights.size} values)")
    write_hex_file(weights, os.path.join(fpga_folder, f"weights_layer{i}.hex"))
    
    # Biases
    biases = info['b_quant']
    print(f"  Writing biases... ({biases.size} values)")
    write_hex_file(biases, os.path.join(fpga_folder, f"biases_layer{i}.hex"))

# Copy test images (these are correct)
print("\nCopying test image files...")
for img_idx in range(10):
    for label in range(10):
        old_file = os.path.join(latest_folder, "fpga_files", f"test_image_{img_idx}_label_{label}.hex")
        if os.path.exists(old_file):
            new_file = os.path.join(fpga_folder, f"test_image_{img_idx}_label_{label}.hex")
            import shutil
            shutil.copy(old_file, new_file)
            print(f"  Copied test_image_{img_idx}_label_{label}.hex")
            break

print("\n" + "="*70)
print("FIXED FPGA FILE GENERATION COMPLETE!")
print("="*70)
print(f"\nAll files saved to: {fpga_folder}/")
print("\nNext steps:")
print("  1. Replace your weights_layer*.hex files with the FIXED versions")
print("  2. Re-run your simulation")
print("  3. Should now get correct predictions!")
print("="*70)
