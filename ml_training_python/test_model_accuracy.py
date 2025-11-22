#!/usr/bin/env python3
"""
Test the quantized model accuracy in Python
This should match your hardware results!
"""

import numpy as np
from tensorflow import keras
import glob
import os

# Find latest training
folders = glob.glob("mnist_training_output_*")
if not folders:
    print("No training folders found!")
    exit(1)

latest = max(folders, key=os.path.getctime)
print(f"Testing model from: {latest}\n")

# Load quantized weights
w1 = np.load(os.path.join(latest, 'layer_0_weights_quantized.npy'))
b1 = np.load(os.path.join(latest, 'layer_0_biases_quantized.npy'))
w2 = np.load(os.path.join(latest, 'layer_1_weights_quantized.npy'))
b2 = np.load(os.path.join(latest, 'layer_1_biases_quantized.npy'))

# Load scales
with open(os.path.join(latest, 'layer_0_scales.txt')) as f:
    scale = float(f.readlines()[0].split('=')[1])

print(f"Model: 784 -> 128 -> 10")
print(f"Scale: {scale}")
print(f"Weight range: [{w1.min()}, {w1.max()}]")
print()

# Load MNIST test set
(_, _), (x_test, y_test) = keras.datasets.mnist.load_data()
x_test = x_test.astype("float32") / 255.0

def quantized_inference(image_flat):
    """Match hardware implementation exactly"""
    # Scale input to [0-256]
    x = (image_flat * 256).astype(np.int32)
    
    # Layer 1: x * w + b*256, then ReLU
    hidden = np.dot(x, w1) + b1 * 256
    hidden = np.maximum(0, hidden)
    
    # Layer 2: (hidden >> 8) * w + b*256
    x_scaled = hidden // 256
    output = np.dot(x_scaled, w2) + b2 * 256
    
    return np.argmax(output), output

# Test on first 10 images (matching your simulation)
print("="*60)
print("Testing First 10 Images (matches Vivado testbench)")
print("="*60)

correct = 0
for i in range(10):
    img_flat = x_test[i].flatten()
    pred, outputs = quantized_inference(img_flat)
    actual = y_test[i]
    
    is_correct = (pred == actual)
    correct += is_correct
    
    status = "✓ CORRECT" if is_correct else "✗ WRONG"
    print(f"Image {i}: Expected={actual}, Predicted={pred} {status}")
    
    # Show output values
    print(f"  Outputs: ", end="")
    for j in range(10):
        marker = " <--" if j == pred else ""
        print(f"{j}:{outputs[j]:>10}{marker}", end=" ")
    print()

accuracy_10 = correct / 10.0 * 100
print(f"\nAccuracy on 10 images: {correct}/10 = {accuracy_10:.1f}%")

# Test on full test set (10,000 images)
print("\n" + "="*60)
print("Testing Full Test Set (10,000 images)")
print("="*60)

correct_full = 0
predictions = []
for i in range(len(x_test)):
    img_flat = x_test[i].flatten()
    pred, _ = quantized_inference(img_flat)
    predictions.append(pred)
    if pred == y_test[i]:
        correct_full += 1
    
    if (i + 1) % 1000 == 0:
        print(f"  Tested {i+1}/10000 images... ({correct_full}/{i+1} correct)")

accuracy_full = correct_full / len(x_test) * 100
print(f"\nFinal Accuracy: {correct_full}/{len(x_test)} = {accuracy_full:.2f}%")

# Per-digit accuracy
print("\n" + "="*60)
print("Per-Digit Accuracy")
print("="*60)

for digit in range(10):
    mask = (y_test == digit)
    digit_correct = np.sum(np.array(predictions)[mask] == digit)
    digit_total = np.sum(mask)
    digit_acc = digit_correct / digit_total * 100
    print(f"Digit {digit}: {digit_correct}/{digit_total} = {digit_acc:.1f}%")

print("\n" + "="*60)
print("SUMMARY")
print("="*60)
print(f"Scale used: {scale}")
print(f"10-image test: {accuracy_10:.1f}%")
print(f"Full test set: {accuracy_full:.2f}%")
print()
print("Hardware should match the 10-image results!")
print("If Vivado shows similar accuracy, your FPGA implementation is correct!")
print("="*60)
