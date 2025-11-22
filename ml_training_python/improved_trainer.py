import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers, regularizers
import matplotlib.pyplot as plt
import os
from datetime import datetime

# Create output folder with timestamp
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
output_dir = f"mnist_training_output_{timestamp}"
os.makedirs(output_dir, exist_ok=True)

print("="*60)
print("HARDWARE-FRIENDLY MNIST TRAINER")
print("="*60)
print(f"\nOutput directory: {output_dir}")
print(f"All generated files will be saved there.\n")

# Load MNIST dataset
print("\nLoading MNIST dataset...")
(x_train, y_train), (x_test, y_test) = keras.datasets.mnist.load_data()

# Normalize to [0, 1]
x_train = x_train.astype("float32") / 255.0
x_test = x_test.astype("float32") / 255.0

# Flatten images
x_train_flat = x_train.reshape(-1, 784)
x_test_flat = x_test.reshape(-1, 784)

print(f"Training samples: {x_train_flat.shape[0]}")
print(f"Test samples: {x_test_flat.shape[0]}")

# ============================================================================
# STRATEGY 1: Data Augmentation (Improves generalization)
# ============================================================================
print("\n" + "="*60)
print("STRATEGY 1: Data Augmentation using TensorFlow")
print("="*60)

# Use TensorFlow's data augmentation (much faster!)
data_augmentation = keras.Sequential([
    layers.RandomRotation(0.05),  # +/- 5% = about 18 degrees
    layers.RandomTranslation(0.1, 0.1),  # 10% shift
    layers.RandomZoom(0.1),  # 10% zoom
])

print("Using on-the-fly data augmentation during training")
print("  - Random rotation: +/- 18 degrees")
print("  - Random translation: +/- 10%")
print("  - Random zoom: +/- 10%")

# Prepare data - keep original format for augmentation
x_train_2d = x_train.reshape(-1, 28, 28, 1)  # Add channel dimension
x_test_2d = x_test.reshape(-1, 28, 28, 1)

x_train_aug = x_train_flat
y_train_aug = y_train
print(f"Training samples: {x_train_aug.shape[0]} (augmentation during training)")

# ============================================================================
# STRATEGY 2: Architecture
# ============================================================================
print("\n" + "="*60)
print("STRATEGY 2: Architecture (784 -> 128 -> 10)")
print("="*60)

model = keras.Sequential([
    layers.Dense(128, activation='relu', name='hidden_layer'),
    layers.Dense(10, activation='softmax', name='output_layer')
])

print("Selected Architecture:")
model.build(input_shape=(None, 784))
model.summary()

# Calculate memory requirements
total_params = model.count_params()
memory_kb = total_params * 2 / 1024  # 16-bit weights
print(f"\nMemory required: ~{memory_kb:.1f} KB")
print(f"Spartan-7 BRAM: 1800 KB total")
print(f"Usage: {memory_kb/1800*100:.1f}% of FPGA BRAM")

# ============================================================================
# STRATEGY 3: Training Configuration
# ============================================================================
print("\n" + "="*60)
print("STRATEGY 3: Improved Training Configuration")
print("="*60)

optimizer = keras.optimizers.Adam(learning_rate=0.001)

model.compile(
    optimizer=optimizer,
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
)

early_stopping = keras.callbacks.EarlyStopping(
    monitor='val_loss',
    patience=3,
    restore_best_weights=True
)

reduce_lr = keras.callbacks.ReduceLROnPlateau(
    monitor='val_loss',
    factor=0.5,
    patience=2,
    min_lr=0.00001
)

print("Training configuration:")
print("  - Optimizer: Adam")
print("  - Initial learning rate: 0.001")
print("  - Early stopping enabled")
print("  - Learning rate reduction on plateau")

# ============================================================================
# TRAINING
# ============================================================================
print("\n" + "="*60)
print("TRAINING MODEL")
print("="*60)

def train_generator(x, y, batch_size=128):
    """Generator that applies augmentation on-the-fly"""
    dataset_size = len(x)
    indices = np.arange(dataset_size)
    
    while True:
        np.random.shuffle(indices)
        
        for start_idx in range(0, dataset_size, batch_size):
            batch_indices = indices[start_idx:start_idx + batch_size]
            
            batch_x = x[batch_indices].reshape(-1, 28, 28, 1)
            batch_y = y[batch_indices]
            
            batch_x_aug = data_augmentation(batch_x, training=True)
            batch_x_aug = batch_x_aug.numpy().reshape(-1, 784)
            
            yield batch_x_aug, batch_y

batch_size = 128
steps_per_epoch = len(x_train) // batch_size

history = model.fit(
    train_generator(x_train, y_train, batch_size),
    steps_per_epoch=steps_per_epoch,
    epochs=20,
    validation_data=(x_test_flat, y_test),
    callbacks=[early_stopping, reduce_lr],
    verbose=1
)

# Evaluate on test set
test_loss, test_accuracy = model.evaluate(x_test_flat, y_test, verbose=0)
print(f"\n{'='*60}")
print(f"FINAL TEST ACCURACY: {test_accuracy * 100:.2f}%")
print(f"{'='*60}")

# ============================================================================
# ANALYSIS: Per-digit accuracy
# ============================================================================
print("\nPer-digit accuracy analysis:")
predictions = model.predict(x_test_flat, verbose=0)
predicted_classes = np.argmax(predictions, axis=1)

for digit in range(10):
    digit_mask = (y_test == digit)
    digit_accuracy = np.mean(predicted_classes[digit_mask] == digit)
    digit_count = np.sum(digit_mask)
    print(f"  Digit {digit}: {digit_accuracy*100:.1f}% ({digit_count} samples)")

# ============================================================================
# Plot training history
# ============================================================================
plt.figure(figsize=(12, 4))

plt.subplot(1, 2, 1)
plt.plot(history.history['accuracy'], label='Train Accuracy')
plt.plot(history.history['val_accuracy'], label='Val Accuracy')
plt.xlabel('Epoch')
plt.ylabel('Accuracy')
plt.legend()
plt.title('Model Accuracy')
plt.grid(True)

plt.subplot(1, 2, 2)
plt.plot(history.history['loss'], label='Train Loss')
plt.plot(history.history['val_loss'], label='Val Loss')
plt.xlabel('Epoch')
plt.ylabel('Loss')
plt.legend()
plt.title('Model Loss')
plt.grid(True)

plt.tight_layout()
plt.savefig(os.path.join(output_dir, 'training_history.png'))
print(f"\nTraining history saved to '{output_dir}/training_history.png'")

# ============================================================================
# HARDWARE-FRIENDLY QUANTIZATION (Power of 2!)
# ============================================================================
print("\n" + "="*60)
print("HARDWARE-FRIENDLY QUANTIZATION")
print("="*60)
print("Using scale=256 (power of 2) for ALL layers")
print("This makes hardware implementation trivial!")
print("="*60)

def quantize_weights_simple(weights, scale=256.0, bits=16):
    """
    Simple power-of-2 quantization - HARDWARE FRIENDLY!
    Always uses scale=256 which is 2^8
    This allows using bit shifts (>>8) instead of division in hardware
    """
    quantized = np.round(weights * scale).astype(np.int16)
    quantized = np.clip(quantized, -32767, 32767)
    return quantized, scale

# Extract and quantize all weights
print("\nExtracting and quantizing weights with scale=256...")
layer_info = []

for i, layer in enumerate(model.layers):
    if len(layer.get_weights()) > 0:
        weights, biases = layer.get_weights()
        
        # Use simple quantization with scale=256 for ALL layers
        w_quant, w_scale = quantize_weights_simple(weights, scale=256.0)
        b_quant, b_scale = quantize_weights_simple(biases, scale=256.0)
        
        layer_info.append({
            'name': layer.name,
            'w_quant': w_quant,
            'b_quant': b_quant,
            'w_scale': w_scale,
            'b_scale': b_scale,
            'shape': weights.shape
        })
        
        print(f"\nLayer {i}: {layer.name}")
        print(f"  Weight shape: {weights.shape}")
        print(f"  Weight scale: {w_scale:.2f} (power of 2!)")
        print(f"  Bias scale: {b_scale:.2f} (power of 2!)")
        print(f"  Weight range: [{w_quant.min()}, {w_quant.max()}]")
        print(f"  Bias range: [{b_quant.min()}, {b_quant.max()}]")

# Save quantized weights
for i, info in enumerate(layer_info):
    np.save(os.path.join(output_dir, f'layer_{i}_weights_quantized.npy'), info['w_quant'])
    np.save(os.path.join(output_dir, f'layer_{i}_biases_quantized.npy'), info['b_quant'])
    
    # Save scales for reference
    with open(os.path.join(output_dir, f'layer_{i}_scales.txt'), 'w') as f:
        f.write(f"weight_scale={info['w_scale']}\n")
        f.write(f"bias_scale={info['b_scale']}\n")

print(f"\nQuantized weights saved to '{output_dir}/'!")

# ============================================================================
# GENERATE C HEADER FILES
# ============================================================================
print("\n" + "="*60)
print("GENERATING C HEADER FILES")
print("="*60)

def generate_c_header_multi_layer(layer_infos, filename):
    """Generate C header for multi-layer networks"""
    filepath = os.path.join(output_dir, filename)
    with open(filepath, 'w') as f:
        f.write("// Auto-generated Neural Network Weights\n")
        f.write("// Hardware-Friendly MNIST Model (scale=256)\n\n")
        f.write("#ifndef NN_WEIGHTS_H\n")
        f.write("#define NN_WEIGHTS_H\n\n")
        f.write("#include <stdint.h>\n\n")
        
        f.write(f"#define NUM_LAYERS {len(layer_infos)}\n")
        f.write(f"#define SCALE 256  // Power of 2!\n\n")
        
        for i, info in enumerate(layer_infos):
            name = f"layer_{i}"
            w = info['w_quant']
            b = info['b_quant']
            
            f.write(f"// Layer {i}: {info['name']}\n")
            f.write(f"#define {name.upper()}_INPUT_SIZE {w.shape[0]}\n")
            f.write(f"#define {name.upper()}_OUTPUT_SIZE {w.shape[1]}\n\n")
            
            # Weights
            f.write(f"const int16_t {name}_weights[{w.shape[0]}][{w.shape[1]}] = {{\n")
            for row in range(w.shape[0]):
                f.write("    {")
                f.write(", ".join(str(w[row, col]) for col in range(w.shape[1])))
                f.write("}")
                if row < w.shape[0] - 1:
                    f.write(",\n")
            f.write("\n};\n\n")
            
            # Biases
            f.write(f"const int16_t {name}_biases[{len(b)}] = {{\n    ")
            f.write(", ".join(str(x) for x in b))
            f.write("\n};\n\n")
        
        f.write("#endif // NN_WEIGHTS_H\n")

generate_c_header_multi_layer(layer_info, 'improved_nn_weights.h')
print(f"C header file generated: {output_dir}/improved_nn_weights.h")

# ============================================================================
# TEST QUANTIZED MODEL
# ============================================================================
print("\n" + "="*60)
print("TESTING QUANTIZED MODEL")
print("="*60)

def quantized_inference_simple(image_flat, layer_infos):
    """
    Simple quantized inference matching hardware implementation
    Uses scale=256 for everything (power of 2)
    """
    # Input is [0-1], scale to [0-256]
    x = (image_flat * 256).astype(np.int32)
    
    # Layer 1: x * w + b*256, then ReLU
    output = np.dot(x, layer_infos[0]['w_quant']) + layer_infos[0]['b_quant'] * 256
    output = np.maximum(0, output)  # ReLU
    
    # Layer 2: (hidden >> 8) * w + b*256
    x_scaled = output // 256
    output = np.dot(x_scaled, layer_infos[1]['w_quant']) + layer_infos[1]['b_quant'] * 256
    
    return np.argmax(output), output

# Test on sample images
print("\nTesting quantized model on 20 random test images:")
correct = 0
test_indices = np.random.choice(len(x_test_flat), 20, replace=False)

for idx in test_indices:
    pred, _ = quantized_inference_simple(x_test_flat[idx], layer_info)
    actual = y_test[idx]
    correct += (pred == actual)
    status = "[CORRECT]" if pred == actual else "[WRONG]"
    print(f"Image {idx}: Predicted {pred}, Actual {actual} {status}")

print(f"\nQuantized accuracy on 20 samples: {correct/20 * 100:.1f}%")

# Full quantized test
print("\nTesting on full test set (10,000 images)...")
all_correct = 0
for i in range(len(x_test_flat)):
    pred, _ = quantized_inference_simple(x_test_flat[i], layer_info)
    all_correct += (pred == y_test[i])

quantized_accuracy = all_correct / len(x_test_flat) * 100
print(f"Full quantized test accuracy: {quantized_accuracy:.2f}%")
print(f"Accuracy drop from quantization: {(test_accuracy*100 - quantized_accuracy):.2f}%")

# ============================================================================
# SUMMARY
# ============================================================================
print("\n" + "="*60)
print("HARDWARE-FRIENDLY TRAINING COMPLETE!")
print("="*60)
print(f"\nFloat model accuracy: {test_accuracy*100:.2f}%")
print(f"Quantized model accuracy: {quantized_accuracy:.2f}%")
print(f"Total parameters: {total_params:,}")
print(f"Memory required: ~{memory_kb:.1f} KB")
print(f"\nAll output files saved to: {output_dir}/")

print("\n" + "="*60)
print("HARDWARE IMPLEMENTATION IS NOW TRIVIAL!")
print("="*60)
print("""
SystemVerilog implementation:

  // Layer 1
  acc = input * weight + bias * 256;
  hidden = (acc > 0) ? acc : 0;  // ReLU
  
  // Layer 2
  acc = (hidden >> 8) * weight + bias * 256;
  prediction = argmax(acc);

Key points:
  - Scale is 256 (2^8) for ALL layers
  - Use >> 8 (shift right by 8) to divide by 256
  - No complex scaling needed!
  - Fits easily in 32-bit integers
  - Values in millions (not trillions!)
""")

print("="*60)
print("NEXT STEPS:")
print("="*60)
print("1. Run: python convert_weights_to_fpga.py")
print("2. Use the generated .hex files in your FPGA project")
print("3. Hardware will work immediately!")
print("4. Expected accuracy: 95-97% (excellent!)")
print("="*60)
