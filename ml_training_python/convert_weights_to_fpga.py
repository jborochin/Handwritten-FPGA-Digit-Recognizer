import numpy as np
import os
import glob

"""
Convert quantized neural network weights to FPGA memory initialization formats
FIXED: Handles int32, float, and properly converts to int16
"""

# Find the most recent training output folder
print("Looking for trained model weights...")
output_folders = glob.glob("mnist_training_output_*")
if not output_folders:
    output_folders = [d for d in os.listdir('.') if d.startswith('mnist_training_output_') and os.path.isdir(d)]

if not output_folders:
    print("ERROR: No training output folders found!")
    exit(1)

latest_folder = max(output_folders, key=os.path.getctime)
print(f"Using model from: {latest_folder}")

# Create FPGA output folder
fpga_folder = os.path.join(latest_folder, "fpga_files")
os.makedirs(fpga_folder, exist_ok=True)
print(f"FPGA files will be saved to: {fpga_folder}")

# Load all layers
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
    
    # Convert to int16 if needed, with clipping
    if w_quant.dtype != np.int16:
        print(f"  Layer {i}: Converting from {w_quant.dtype} to int16...")
        w_quant = np.clip(w_quant, -32767, 32767).astype(np.int16)
        b_quant = np.clip(b_quant, -32767, 32767).astype(np.int16)
    
    layers_info.append({
        'w_quant': w_quant,
        'b_quant': b_quant,
        'w_scale': w_scale,
        'b_scale': b_scale
    })
    
    print(f"  Layer {i}: {w_quant.shape[0]} x {w_quant.shape[1]} + {len(b_quant)} biases")
    print(f"    Weight range: [{w_quant.min()}, {w_quant.max()}]")
    print(f"    Scale: {w_scale}")

print("\nGenerating FPGA memory files...")

def write_hex_file(data, filename):
    """Write data as hexadecimal values (for $readmemh)"""
    with open(filename, 'w') as f:
        for value in data.flatten():
            # Ensure value is int16
            value = int(value)
            # Convert signed integer to unsigned hex (16-bit two's complement)
            if value < 0:
                hex_val = 65536 + value  # 2^16 + negative value
            else:
                hex_val = value
            f.write(f"{hex_val:04X}\n")

def write_coe_file(data, filename):
    """Write Xilinx .coe file for Block RAM initialization"""
    with open(filename, 'w') as f:
        f.write("; Coefficient file for Xilinx Block RAM\n")
        f.write("; Generated from quantized neural network weights\n\n")
        f.write("memory_initialization_radix=16;\n")
        f.write("memory_initialization_vector=\n")
        
        flat_data = data.flatten()
        for i, value in enumerate(flat_data):
            value = int(value)
            if value < 0:
                hex_val = 65536 + value
            else:
                hex_val = value
            
            if i < len(flat_data) - 1:
                f.write(f"{hex_val:04X},\n")
            else:
                f.write(f"{hex_val:04X};\n")

def write_mem_file(data, filename):
    """Write .mem file (alternative format)"""
    with open(filename, 'w') as f:
        f.write(f"// Memory initialization file\n")
        f.write(f"// {len(data.flatten())} values, 16-bit signed\n\n")
        
        for addr, value in enumerate(data.flatten()):
            value = int(value)
            if value < 0:
                hex_val = 65536 + value
            else:
                hex_val = value
            f.write(f"@{addr:08X} {hex_val:04X}\n")

# Generate files for each layer
for i, info in enumerate(layers_info):
    print(f"\nLayer {i}:")
    
    # Weights
    weights = info['w_quant']
    print(f"  Generating weight files... ({weights.size} values)")
    write_hex_file(weights, os.path.join(fpga_folder, f"weights_layer{i}.hex"))
    write_coe_file(weights, os.path.join(fpga_folder, f"weights_layer{i}.coe"))
    write_mem_file(weights, os.path.join(fpga_folder, f"weights_layer{i}.mem"))
    
    # Biases
    biases = info['b_quant']
    print(f"  Generating bias files... ({biases.size} values)")
    write_hex_file(biases, os.path.join(fpga_folder, f"biases_layer{i}.hex"))
    write_coe_file(biases, os.path.join(fpga_folder, f"biases_layer{i}.coe"))
    write_mem_file(biases, os.path.join(fpga_folder, f"biases_layer{i}.mem"))

# Generate test images
print("\nGenerating test image files...") 
import numpy as np
import os
import glob

"""
Convert quantized neural network weights to FPGA memory initialization formats
FIXED: Handles int32, float, and properly converts to int16
"""

# Find the most recent training output folder
print("Looking for trained model weights...")
output_folders = glob.glob("mnist_training_output_*")
if not output_folders:
    output_folders = [d for d in os.listdir('.') if d.startswith('mnist_training_output_') and os.path.isdir(d)]

if not output_folders:
    print("ERROR: No training output folders found!")
    exit(1)

latest_folder = max(output_folders, key=os.path.getctime)
print(f"Using model from: {latest_folder}")

# Create FPGA output folder
fpga_folder = os.path.join(latest_folder, "fpga_files")
os.makedirs(fpga_folder, exist_ok=True)
print(f"FPGA files will be saved to: {fpga_folder}")

# Load all layers
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
    
    # Convert to int16 if needed, with clipping
    if w_quant.dtype != np.int16:
        print(f"  Layer {i}: Converting from {w_quant.dtype} to int16...")
        w_quant = np.clip(w_quant, -32767, 32767).astype(np.int16)
        b_quant = np.clip(b_quant, -32767, 32767).astype(np.int16)
    
    layers_info.append({
        'w_quant': w_quant,
        'b_quant': b_quant,
        'w_scale': w_scale,
        'b_scale': b_scale
    })
    
    print(f"  Layer {i}: {w_quant.shape[0]} x {w_quant.shape[1]} + {len(b_quant)} biases")
    print(f"    Weight range: [{w_quant.min()}, {w_quant.max()}]")
    print(f"    Scale: {w_scale}")

print("\nGenerating FPGA memory files...")

def write_hex_file(data, filename):
    """Write data as hexadecimal values (for $readmemh)"""
    with open(filename, 'w') as f:
        for value in data.flatten():
            # Ensure value is int16
            value = int(value)
            # Convert signed integer to unsigned hex (16-bit two's complement)
            if value < 0:
                hex_val = 65536 + value  # 2^16 + negative value
            else:
                hex_val = value
            f.write(f"{hex_val:04X}\n")

def write_coe_file(data, filename):
    """Write Xilinx .coe file for Block RAM initialization"""
    with open(filename, 'w') as f:
        f.write("; Coefficient file for Xilinx Block RAM\n")
        f.write("; Generated from quantized neural network weights\n\n")
        f.write("memory_initialization_radix=16;\n")
        f.write("memory_initialization_vector=\n")
        
        flat_data = data.flatten()
        for i, value in enumerate(flat_data):
            value = int(value)
            if value < 0:
                hex_val = 65536 + value
            else:
                hex_val = value
            
            if i < len(flat_data) - 1:
                f.write(f"{hex_val:04X},\n")
            else:
                f.write(f"{hex_val:04X};\n")

def write_mem_file(data, filename):
    """Write .mem file (alternative format)"""
    with open(filename, 'w') as f:
        f.write(f"// Memory initialization file\n")
        f.write(f"// {len(data.flatten())} values, 16-bit signed\n\n")
        
        for addr, value in enumerate(data.flatten()):
            value = int(value)
            if value < 0:
                hex_val = 65536 + value
            else:
                hex_val = value
            f.write(f"@{addr:08X} {hex_val:04X}\n")

# Generate files for each layer
for i, info in enumerate(layers_info):
    print(f"\nLayer {i}:")
    
    # Weights
    weights = info['w_quant']
    print(f"  Generating weight files... ({weights.size} values)")
    write_hex_file(weights, os.path.join(fpga_folder, f"weights_layer{i}.hex"))
    write_coe_file(weights, os.path.join(fpga_folder, f"weights_layer{i}.coe"))
    write_mem_file(weights, os.path.join(fpga_folder, f"weights_layer{i}.mem"))
    
    # Biases
    biases = info['b_quant']
    print(f"  Generating bias files... ({biases.size} values)")
    write_hex_file(biases, os.path.join(fpga_folder, f"biases_layer{i}.hex"))
    write_coe_file(biases, os.path.join(fpga_folder, f"biases_layer{i}.coe"))
    write_mem_file(biases, os.path.join(fpga_folder, f"biases_layer{i}.mem"))

# Generate test images
print("\nGenerating test image files...")
from tensorflow import keras
(_, _), (x_test, y_test) = keras.datasets.mnist.load_data()
x_test_norm = x_test.astype("float32") / 255.0

for img_idx in range(10):
    img_flat = x_test_norm[img_idx].flatten()
    # Scale to [0-256] and keep as UNSIGNED values
    img_quantized = np.round(img_flat * 256).astype(np.uint16)
    img_quantized = np.clip(img_quantized, 0, 256)  # Ensure in valid range
    
    # Write as unsigned hex
    filename = os.path.join(fpga_folder, f"test_image_{img_idx}_label_{y_test[img_idx]}.hex")
    with open(filename, 'w') as f:
        for value in img_quantized:
            f.write(f"{int(value):04X}\n")
    print(f"  test_image_{img_idx}_label_{y_test[img_idx]}.hex")

# Generate memory map documentation
print("\nGenerating memory map documentation...")
with open(os.path.join(fpga_folder, "MEMORY_MAP.txt"), 'w') as f:
    f.write("="*70 + "\n")
    f.write("FPGA Memory Map for Neural Network Inference\n")
    f.write("="*70 + "\n\n")
    
    f.write("ARCHITECTURE:\n")
    arch_str = str(layers_info[0]['w_quant'].shape[0])
    for layer in layers_info:
        arch_str += f" -> {layer['w_quant'].shape[1]}"
    f.write(f"  {arch_str}\n\n")
    
    f.write("QUANTIZATION:\n")
    for i, info in enumerate(layers_info):
        f.write(f"  Layer {i} scale: {info['w_scale']}\n")
    f.write("\n")
    
    f.write("MEMORY REQUIREMENTS:\n")
    total_params = 0
    total_memory = 0
    
    for i, info in enumerate(layers_info):
        num_weights = info['w_quant'].size
        num_biases = info['b_quant'].size
        layer_params = num_weights + num_biases
        layer_memory = layer_params * 2  # 16-bit = 2 bytes
        
        total_params += layer_params
        total_memory += layer_memory
        
        f.write(f"\n  Layer {i}:\n")
        f.write(f"    Weights: {num_weights:,} x 16-bit = {num_weights*2:,} bytes\n")
        f.write(f"    Biases:  {num_biases:,} x 16-bit = {num_biases*2:,} bytes\n")
        f.write(f"    Subtotal: {layer_memory:,} bytes ({layer_memory/1024:.2f} KB)\n")
    
    f.write(f"\n  TOTAL PARAMETERS: {total_params:,}\n")
    f.write(f"  TOTAL MEMORY: {total_memory:,} bytes ({total_memory/1024:.2f} KB)\n\n")
    
    f.write("HARDWARE IMPLEMENTATION:\n")
    if layers_info[0]['w_scale'] == 256.0:
        f.write("  Scale is 256 (power of 2) - HARDWARE FRIENDLY!\n")
        f.write("  Use >> 8 to divide by scale in hardware\n")
        f.write("  All values fit in 32-bit accumulators\n")
    else:
        f.write(f"  Scale is {layers_info[0]['w_scale']} - requires careful scaling\n")
        f.write("  May need 48+ bit accumulators\n")
    f.write("\n")
    
    f.write("FILE FORMATS:\n")
    f.write("  .hex - Use with $readmemh() in Verilog/SystemVerilog\n")
    f.write("  .coe - Use with Xilinx Block Memory Generator IP\n")
    f.write("  .mem - Alternative format with addresses\n\n")
    
    f.write("TEST IMAGES:\n")
    f.write("  10 test images provided (test_image_0.hex to test_image_9.hex)\n")
    f.write("  Each image: 784 values x 16-bit\n")
    f.write("  Format: [0-256] matching quantization scale\n\n")

print("\n" + "="*70)
print("FPGA FILE GENERATION COMPLETE!")
print("="*70)
print(f"\nAll files saved to: {fpga_folder}/")
print("\nGenerated files:")
print("  - weights_layer*.hex/coe/mem (for each layer)")
print("  - biases_layer*.hex/coe/mem (for each layer)")
print("  - test_image_*.hex (10 test images)")
print("  - MEMORY_MAP.txt (documentation)")

# Show quantization info
print("\nQUANTIZATION INFO:")
for i, info in enumerate(layers_info):
    if info['w_scale'] == 256.0:
        print(f"  Layer {i}: Scale=256 ✓ (Hardware-friendly!)")
    else:
        print(f"  Layer {i}: Scale={info['w_scale']} ⚠ (May need adjustment)")

print("\n" + "="*70)

from tensorflow import keras
(_, _), (x_test, y_test) = keras.datasets.mnist.load_data()
x_test_norm = x_test.astype("float32") / 255.0

for img_idx in range(10):
    img_flat = x_test_norm[img_idx].flatten()
    img_quantized = np.clip((img_flat * 256), 0, 255).astype(np.int16)  # Scale to [0-256]
    
    write_hex_file(img_quantized, os.path.join(fpga_folder, f"test_image_{img_idx}_label_{y_test[img_idx]}.hex"))
    print(f"  test_image_{img_idx}_label_{y_test[img_idx]}.hex")

# Generate memory map documentation
print("\nGenerating memory map documentation...")
with open(os.path.join(fpga_folder, "MEMORY_MAP.txt"), 'w') as f:
    f.write("="*70 + "\n")
    f.write("FPGA Memory Map for Neural Network Inference\n")
    f.write("="*70 + "\n\n")
    
    f.write("ARCHITECTURE:\n")
    arch_str = str(layers_info[0]['w_quant'].shape[0])
    for layer in layers_info:
        arch_str += f" -> {layer['w_quant'].shape[1]}"
    f.write(f"  {arch_str}\n\n")
    
    f.write("QUANTIZATION:\n")
    for i, info in enumerate(layers_info):
        f.write(f"  Layer {i} scale: {info['w_scale']}\n")
    f.write("\n")
    
    f.write("MEMORY REQUIREMENTS:\n")
    total_params = 0
    total_memory = 0
    
    for i, info in enumerate(layers_info):
        num_weights = info['w_quant'].size
        num_biases = info['b_quant'].size
        layer_params = num_weights + num_biases
        layer_memory = layer_params * 2  # 16-bit = 2 bytes
        
        total_params += layer_params
        total_memory += layer_memory
        
        f.write(f"\n  Layer {i}:\n")
        f.write(f"    Weights: {num_weights:,} x 16-bit = {num_weights*2:,} bytes\n")
        f.write(f"    Biases:  {num_biases:,} x 16-bit = {num_biases*2:,} bytes\n")
        f.write(f"    Subtotal: {layer_memory:,} bytes ({layer_memory/1024:.2f} KB)\n")
    
    f.write(f"\n  TOTAL PARAMETERS: {total_params:,}\n")
    f.write(f"  TOTAL MEMORY: {total_memory:,} bytes ({total_memory/1024:.2f} KB)\n\n")
    
    f.write("HARDWARE IMPLEMENTATION:\n")
    if layers_info[0]['w_scale'] == 256.0:
        f.write("  Scale is 256 (power of 2) - HARDWARE FRIENDLY!\n")
        f.write("  Use >> 8 to divide by scale in hardware\n")
        f.write("  All values fit in 32-bit accumulators\n")
    else:
        f.write(f"  Scale is {layers_info[0]['w_scale']} - requires careful scaling\n")
        f.write("  May need 48+ bit accumulators\n")
    f.write("\n")
    
    f.write("FILE FORMATS:\n")
    f.write("  .hex - Use with $readmemh() in Verilog/SystemVerilog\n")
    f.write("  .coe - Use with Xilinx Block Memory Generator IP\n")
    f.write("  .mem - Alternative format with addresses\n\n")
    
    f.write("TEST IMAGES:\n")
    f.write("  10 test images provided (test_image_0.hex to test_image_9.hex)\n")
    f.write("  Each image: 784 values x 16-bit\n")
    f.write("  Format: [0-256] matching quantization scale\n\n")

print("\n" + "="*70)
print("FPGA FILE GENERATION COMPLETE!")
print("="*70)
print(f"\nAll files saved to: {fpga_folder}/")
print("\nGenerated files:")
print("  - weights_layer*.hex/coe/mem (for each layer)")
print("  - biases_layer*.hex/coe/mem (for each layer)")
print("  - test_image_*.hex (10 test images)")
print("  - MEMORY_MAP.txt (documentation)")

# Show quantization info
print("\nQUANTIZATION INFO:")
for i, info in enumerate(layers_info):
    if info['w_scale'] == 256.0:
        print(f"  Layer {i}: Scale=256 ✓ (Hardware-friendly!)")
    else:
        print(f"  Layer {i}: Scale={info['w_scale']} ⚠ (May need adjustment)")

print("\n" + "="*70)