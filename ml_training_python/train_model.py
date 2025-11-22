import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import matplotlib.pyplot as plt

# Load MNIST dataset
print("Loading MNIST dataset...")
(x_train, y_train), (x_test, y_test) = keras.datasets.mnist.load_data()

# Normalize to [0, 1]
x_train = x_train.astype("float32") / 255.0
x_test = x_test.astype("float32") / 255.0

# Flatten images from 28x28 to 784
x_train_flat = x_train.reshape(-1, 784)
x_test_flat = x_test.reshape(-1, 784)

print(f"Training samples: {x_train_flat.shape[0]}")
print(f"Test samples: {x_test_flat.shape[0]}")

# Create a simple 1-hidden-layer MLP optimized for FPGA
# Architecture: 784 -> 64 -> 10 (small enough for FPGA memory)
model = keras.Sequential([
    layers.Dense(64, activation='relu', input_shape=(784,), name='hidden_layer'),
    layers.Dense(10, activation='softmax', name='output_layer')
])

model.compile(
    optimizer='adam',
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
)

print("\nModel Architecture:")
model.summary()

# Train the model
print("\nTraining model...")
history = model.fit(
    x_train_flat, y_train,
    batch_size=128,
    epochs=10,
    validation_split=0.1,
    verbose=1
)

# Evaluate on test set
test_loss, test_accuracy = model.evaluate(x_test_flat, y_test, verbose=0)
print(f"\nTest Accuracy: {test_accuracy * 100:.2f}%")

# Plot training history
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
plt.savefig('training_history.png')
print("\nTraining history saved to 'training_history.png'")

# Extract weights and biases
weights_hidden, biases_hidden = model.layers[0].get_weights()
weights_output, biases_output = model.layers[1].get_weights()

print(f"\nWeight shapes:")
print(f"Hidden layer weights: {weights_hidden.shape}")
print(f"Hidden layer biases: {biases_hidden.shape}")
print(f"Output layer weights: {weights_output.shape}")
print(f"Output layer biases: {biases_output.shape}")

# Quantize to 8-bit fixed-point (Q7.8 format - 1 sign bit, 7 integer bits, 8 fractional bits)
def quantize_weights(weights, bits=16, frac_bits=8):
    """Quantize weights to fixed-point format"""
    scale = 2 ** frac_bits
    quantized = np.round(weights * scale).astype(np.int32)
    # Clip to representable range
    max_val = 2 ** (bits - 1) - 1
    min_val = -(2 ** (bits - 1))
    quantized = np.clip(quantized, min_val, max_val)
    return quantized, scale

# Quantize all weights (16-bit for better accuracy)
w1_quant, scale1 = quantize_weights(weights_hidden, bits=16, frac_bits=8)
b1_quant, _ = quantize_weights(biases_hidden, bits=16, frac_bits=8)
w2_quant, scale2 = quantize_weights(weights_output, bits=16, frac_bits=8)
b2_quant, _ = quantize_weights(biases_output, bits=16, frac_bits=8)

# Save quantized weights to files for FPGA
np.save('weights_hidden_quantized.npy', w1_quant)
np.save('biases_hidden_quantized.npy', b1_quant)
np.save('weights_output_quantized.npy', w2_quant)
np.save('biases_output_quantized.npy', b2_quant)

print("\nQuantized weights saved to .npy files")

# Generate C header files for MicroBlaze
def generate_c_header(weights, biases, layer_name, filename):
    """Generate C header file with weight arrays"""
    with open(filename, 'w') as f:
        f.write(f"// Auto-generated weights for {layer_name}\n")
        f.write(f"// Generated from MNIST training script\n\n")
        f.write(f"#ifndef {layer_name.upper()}_WEIGHTS_H\n")
        f.write(f"#define {layer_name.upper()}_WEIGHTS_H\n\n")
        
        # Write dimensions
        f.write(f"#define {layer_name.upper()}_INPUT_SIZE {weights.shape[0]}\n")
        f.write(f"#define {layer_name.upper()}_OUTPUT_SIZE {weights.shape[1]}\n\n")
        
        # Write weights (row-major order for easier access)
        f.write(f"const int16_t {layer_name}_weights[{weights.shape[0]}][{weights.shape[1]}] = {{\n")
        for i in range(weights.shape[0]):
            f.write("    {")
            for j in range(weights.shape[1]):
                f.write(f"{weights[i, j]}")
                if j < weights.shape[1] - 1:
                    f.write(", ")
            f.write("}")
            if i < weights.shape[0] - 1:
                f.write(",\n")
            else:
                f.write("\n")
        f.write("};\n\n")
        
        # Write biases
        f.write(f"const int16_t {layer_name}_biases[{biases.shape[0]}] = {{\n    ")
        for i, b in enumerate(biases):
            f.write(f"{b}")
            if i < len(biases) - 1:
                f.write(", ")
        f.write("\n};\n\n")
        f.write(f"#endif // {layer_name.upper()}_WEIGHTS_H\n")

generate_c_header(w1_quant, b1_quant, "hidden", "hidden_weights.h")
generate_c_header(w2_quant, b2_quant, "output", "output_weights.h")

print("C header files generated: hidden_weights.h, output_weights.h")

# Test quantized inference
def quantized_inference(image, w1, b1, w2, b2, scale=256):
    """Perform inference using quantized weights"""
    # Input is already normalized [0, 1], scale to match weight scaling
    x = (image * scale).astype(np.int32)
    
    # Hidden layer
    hidden = np.dot(x, w1) + b1 * scale
    hidden = np.maximum(0, hidden)  # ReLU
    
    # Output layer
    output = np.dot(hidden, w2) + b2 * scale * scale
    
    # Softmax (for prediction, just take argmax)
    prediction = np.argmax(output)
    return prediction

# Test on a few examples
print("\nTesting quantized inference on sample images:")
num_test = 10
correct = 0
for i in range(num_test):
    pred = quantized_inference(x_test_flat[i], w1_quant, b1_quant, w2_quant, b2_quant)
    actual = y_test[i]
    correct += (pred == actual)
    status = '[CORRECT]' if pred == actual else '[WRONG]'
    print(f"Image {i}: Predicted {pred}, Actual {actual} {status}")

print(f"\nQuantized model accuracy on {num_test} samples: {correct/num_test * 100:.1f}%")

# Save a few test images for FPGA testing
print("\nSaving test images for FPGA...")
for i in range(5):
    img_quantized = (x_test_flat[i] * 256).astype(np.uint8)
    np.save(f'test_image_{i}_label_{y_test[i]}.npy', img_quantized)
    
    # Also save as raw binary for easy FPGA loading
    img_quantized.tofile(f'test_image_{i}.bin')

print("Test images saved as .npy and .bin files")

# Visualize some predictions
fig, axes = plt.subplots(2, 5, figsize=(12, 5))
for i in range(10):
    ax = axes[i // 5, i % 5]
    ax.imshow(x_test[i], cmap='gray')
    pred = quantized_inference(x_test_flat[i], w1_quant, b1_quant, w2_quant, b2_quant)
    actual = y_test[i]
    color = 'green' if pred == actual else 'red'
    ax.set_title(f'Pred: {pred}\nActual: {actual}', color=color)
    ax.axis('off')

plt.tight_layout()
plt.savefig('sample_predictions.png')
print("Sample predictions saved to 'sample_predictions.png'")

print("\n" + "="*60)
print("Week 1 Complete! Summary:")
print("="*60)
print(f"[OK] Model trained with {test_accuracy*100:.2f}% accuracy")
print(f"[OK] Architecture: 784 -> 64 -> 10 (small enough for FPGA)")
print(f"[OK] Weights quantized to 16-bit fixed-point")
print(f"[OK] Total parameters: {784*64 + 64 + 64*10 + 10} = {784*64 + 64 + 64*10 + 10:,}")
print(f"[OK] Memory required: ~{(784*64 + 64 + 64*10 + 10) * 2 / 1024:.1f} KB")
print("[OK] Generated C header files for MicroBlaze")
print("[OK] Generated test images for FPGA validation")
print("\nNext steps for Week 2:")
print("1. Implement MAC accelerator in SystemVerilog")
print("2. Create AXI interface for MicroBlaze communication")
print("3. Test weight loading and matrix multiplication on FPGA")
print("="*60)