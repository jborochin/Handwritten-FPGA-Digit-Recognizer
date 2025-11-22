import numpy as np
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
import tkinter as tk
from PIL import Image, ImageDraw
import cv2
import os
import glob

# Find the most recent training output folder
print("Looking for trained model weights...")
output_folders = glob.glob("mnist_training_output_*")
if not output_folders:
    print("ERROR: No training output folders found!")
    print("Please run the training script first (improved_trainer.py)")
    exit(1)

# Use the most recent folder
latest_folder = max(output_folders, key=os.path.getctime)
print(f"Using model from: {latest_folder}")

# Load the quantized model weights from the latest training
try:
    layer_files = sorted([f for f in os.listdir(latest_folder) if f.startswith('layer_') and f.endswith('_weights_quantized.npy')])
    num_layers = len(layer_files)
    
    print(f"Found {num_layers} layers")
    
    # Load all layers
    layers_info = []
    for i in range(num_layers):
        w_quant = np.load(os.path.join(latest_folder, f'layer_{i}_weights_quantized.npy'))
        b_quant = np.load(os.path.join(latest_folder, f'layer_{i}_biases_quantized.npy'))
        
        # Load scales
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
        
        print(f"  Layer {i}: {w_quant.shape[0]} -> {w_quant.shape[1]}")
    
    print("Model loaded successfully!")
    
    # Build architecture string
    arch_str = str(layers_info[0]['w_quant'].shape[0])
    for layer in layers_info:
        arch_str += f" -> {layer['w_quant'].shape[1]}"
    print(f"Architecture: {arch_str}")
    
except Exception as e:
    print(f"ERROR loading model: {e}")
    print("Please ensure the training script completed successfully.")
    exit(1)

def quantized_inference_multi(image_flat, layers_info):
    """Perform inference using quantized weights for multi-layer networks"""
    x = image_flat
    
    for i, info in enumerate(layers_info):
        # Scale input to match quantized weights
        if i == 0:
            x_scaled = (x * info['w_scale']).astype(np.int64)
        else:
            x_scaled = x
        
        # Matrix multiply + bias
        output = np.dot(x_scaled, info['w_quant']) + info['b_quant'] * info['w_scale']
        
        # ReLU (except for last layer)
        if i < len(layers_info) - 1:
            output = np.maximum(0, output)
        
        x = output
    
    # Get prediction
    prediction = np.argmax(output)
    
    # Simple softmax for confidence (scaled down to prevent overflow)
    output_scaled = output / (info['w_scale'] * 1000)
    exp_output = np.exp(output_scaled - np.max(output_scaled))
    confidence = exp_output / np.sum(exp_output)
    
    return prediction, confidence

class DigitDrawingApp:
    def __init__(self, root, layers_info, output_folder):
        self.root = root
        self.layers_info = layers_info
        self.output_folder = output_folder
        self.root.title("Handwritten Digit Recognizer - Test Your Model!")
        
        # Drawing parameters
        self.canvas_size = 280  # 10x the MNIST size for easier drawing
        self.brush_size = 20
        
        # Create main frame
        main_frame = tk.Frame(root)
        main_frame.pack(padx=10, pady=10)
        
        # Instructions
        instructions = tk.Label(main_frame, 
                              text="Draw a digit (0-9) and click 'Predict'",
                              font=("Arial", 14, "bold"))
        instructions.grid(row=0, column=0, columnspan=2, pady=10)
        
        # Canvas for drawing
        self.canvas = tk.Canvas(main_frame, width=self.canvas_size, 
                               height=self.canvas_size, bg='black', 
                               cursor='cross')
        self.canvas.grid(row=1, column=0, padx=10, pady=10)
        self.canvas.bind("<B1-Motion>", self.draw)
        self.canvas.bind("<Button-1>", self.draw)
        
        # PIL Image for processing
        self.image = Image.new('L', (self.canvas_size, self.canvas_size), 0)
        self.draw_handler = ImageDraw.Draw(self.image)
        
        # Result frame
        result_frame = tk.Frame(main_frame)
        result_frame.grid(row=1, column=1, padx=10, pady=10)
        
        self.result_label = tk.Label(result_frame, 
                                     text="Prediction: ?",
                                     font=("Arial", 24, "bold"),
                                     fg="blue")
        self.result_label.pack(pady=10)
        
        self.confidence_label = tk.Label(result_frame,
                                        text="Confidence: -%",
                                        font=("Arial", 12))
        self.confidence_label.pack(pady=5)
        
        # Confidence bar chart
        self.fig, self.ax = plt.subplots(figsize=(4, 3))
        self.canvas_plot = FigureCanvasTkAgg(self.fig, result_frame)
        self.canvas_plot.get_tk_widget().pack(pady=10)
        
        # Initial empty plot
        self.ax.bar(range(10), [0]*10, color='lightblue')
        self.ax.set_xlabel('Digit')
        self.ax.set_ylabel('Confidence')
        self.ax.set_title('Prediction Probabilities')
        self.ax.set_xticks(range(10))
        self.ax.set_ylim(0, 1)
        self.fig.tight_layout()
        
        # Buttons
        button_frame = tk.Frame(main_frame)
        button_frame.grid(row=2, column=0, columnspan=2, pady=10)
        
        predict_btn = tk.Button(button_frame, text="Predict", 
                               command=self.predict,
                               font=("Arial", 12, "bold"),
                               bg="green", fg="white",
                               padx=20, pady=10)
        predict_btn.pack(side=tk.LEFT, padx=5)
        
        clear_btn = tk.Button(button_frame, text="Clear", 
                             command=self.clear_canvas,
                             font=("Arial", 12),
                             bg="red", fg="white",
                             padx=20, pady=10)
        clear_btn.pack(side=tk.LEFT, padx=5)
        
        save_btn = tk.Button(button_frame, text="Save Image", 
                            command=self.save_image,
                            font=("Arial", 12),
                            padx=20, pady=10)
        save_btn.pack(side=tk.LEFT, padx=5)
    
    def draw(self, event):
        """Draw on canvas"""
        x, y = event.x, event.y
        r = self.brush_size
        
        # Draw on tkinter canvas
        self.canvas.create_oval(x-r, y-r, x+r, y+r, 
                               fill='white', outline='white')
        
        # Draw on PIL image
        self.draw_handler.ellipse([x-r, y-r, x+r, y+r], 
                                  fill=255)
    
    def clear_canvas(self):
        """Clear the canvas"""
        self.canvas.delete("all")
        self.image = Image.new('L', (self.canvas_size, self.canvas_size), 0)
        self.draw_handler = ImageDraw.Draw(self.image)
        
        self.result_label.config(text="Prediction: ?", fg="blue")
        self.confidence_label.config(text="Confidence: -%")
        
        # Clear plot
        self.ax.clear()
        self.ax.bar(range(10), [0]*10, color='lightblue')
        self.ax.set_xlabel('Digit')
        self.ax.set_ylabel('Confidence')
        self.ax.set_title('Prediction Probabilities')
        self.ax.set_xticks(range(10))
        self.ax.set_ylim(0, 1)
        self.canvas_plot.draw()
    
    def preprocess_image(self):
        """Preprocess drawn image to match MNIST format"""
        # Convert to numpy array
        img_array = np.array(self.image)
        
        # Resize to 28x28 (MNIST size)
        img_resized = cv2.resize(img_array, (28, 28), 
                                interpolation=cv2.INTER_AREA)
        
        # Find bounding box of non-zero pixels to center the digit
        rows = np.any(img_resized, axis=1)
        cols = np.any(img_resized, axis=0)
        
        if rows.any() and cols.any():
            rmin, rmax = np.where(rows)[0][[0, -1]]
            cmin, cmax = np.where(cols)[0][[0, -1]]
            
            # Extract digit
            digit = img_resized[rmin:rmax+1, cmin:cmax+1]
            
            # Calculate padding to center in 20x20 box (MNIST standard)
            h, w = digit.shape
            
            # Scale to fit in 20x20 while maintaining aspect ratio
            scale = min(20.0/h, 20.0/w)
            new_h = int(h * scale)
            new_w = int(w * scale)
            
            digit_scaled = cv2.resize(digit, (new_w, new_h))
            
            # Center in 28x28 image
            centered = np.zeros((28, 28), dtype=np.uint8)
            y_offset = (28 - new_h) // 2
            x_offset = (28 - new_w) // 2
            centered[y_offset:y_offset+new_h, x_offset:x_offset+new_w] = digit_scaled
            
            img_processed = centered
        else:
            img_processed = img_resized
        
        # Normalize to [0, 1]
        img_normalized = img_processed.astype('float32') / 255.0
        
        # Flatten to 784-element vector
        img_flat = img_normalized.reshape(784)
        
        return img_flat, img_processed
    
    def predict(self):
        """Run prediction on drawn digit"""
        # Preprocess the image
        img_flat, img_processed = self.preprocess_image()
        
        # Check if anything was drawn
        if np.sum(img_flat) < 0.01:
            self.result_label.config(text="Draw something first!", fg="red")
            return
        
        # Run inference
        prediction, confidence = quantized_inference_multi(
            img_flat, self.layers_info
        )
        
        # Update result label
        self.result_label.config(
            text=f"Prediction: {prediction}",
            fg="green" if confidence[prediction] > 0.8 else "orange"
        )
        self.confidence_label.config(
            text=f"Confidence: {confidence[prediction]*100:.1f}%"
        )
        
        # Update confidence plot
        self.ax.clear()
        colors = ['green' if i == prediction else 'lightblue' 
                 for i in range(10)]
        self.ax.bar(range(10), confidence, color=colors)
        self.ax.set_xlabel('Digit')
        self.ax.set_ylabel('Confidence')
        self.ax.set_title('Prediction Probabilities')
        self.ax.set_xticks(range(10))
        self.ax.set_ylim(0, 1)
        self.canvas_plot.draw()
        
        # Show processed image in terminal
        print("\nProcessed 28x28 image:")
        self._print_ascii_image(img_processed)
        print(f"Prediction: {prediction} (Confidence: {confidence[prediction]*100:.1f}%)")
        print("All probabilities:", 
              [f"{i}:{confidence[i]*100:.1f}%" for i in range(10)])
    
    def _print_ascii_image(self, img):
        """Print ASCII representation of image"""
        chars = ' .:-=+*#%@'
        for row in img:
            line = ''.join([chars[min(int(pixel/28), 9)] for pixel in row])
            print(line)
    
    def save_image(self):
        """Save the current drawing and processed version"""
        import datetime
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Create saved_drawings folder inside the model output folder
        save_dir = os.path.join(self.output_folder, 'saved_drawings')
        os.makedirs(save_dir, exist_ok=True)
        
        # Save original drawing
        self.image.save(os.path.join(save_dir, f'drawing_{timestamp}_original.png'))
        
        # Save processed 28x28 version
        img_flat, img_processed = self.preprocess_image()
        Image.fromarray(img_processed).save(os.path.join(save_dir, f'drawing_{timestamp}_processed.png'))
        
        # Save as binary for FPGA
        img_quantized = (img_flat * 256).astype(np.uint8)
        img_quantized.tofile(os.path.join(save_dir, f'drawing_{timestamp}.bin'))
        
        print(f"\nSaved images to {save_dir}:")
        print(f"  - drawing_{timestamp}_original.png (280x280)")
        print(f"  - drawing_{timestamp}_processed.png (28x28)")
        print(f"  - drawing_{timestamp}.bin (binary for FPGA)")
        
        self.result_label.config(text="Images saved!", fg="blue")

# Run the application
if __name__ == "__main__":
    print("\n" + "="*60)
    print("Handwritten Digit Recognizer - Interactive Tester")
    print("="*60)
    print("Instructions:")
    print("1. Draw a digit (0-9) on the black canvas")
    print("2. Click 'Predict' to see the model's prediction")
    print("3. Click 'Clear' to draw a new digit")
    print("4. Click 'Save Image' to export for FPGA testing")
    print("="*60 + "\n")
    
    root = tk.Tk()
    app = DigitDrawingApp(root, layers_info, latest_folder)
    root.mainloop()