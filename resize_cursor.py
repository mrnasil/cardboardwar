from PIL import Image
import os

path = r'f:\repos\godot\BrotatoClone\assets\sprites\cursor.png'
try:
    if os.path.exists(path):
        img = Image.open(path)
        print(f"Original size: {img.size}")
        
        # Calculate new height to maintain aspect ratio
        width = 32
        w_percent = (width / float(img.size[0]))
        h_size = int((float(img.size[1]) * float(w_percent)))
        
        img = img.resize((width, h_size), Image.Resampling.LANCZOS)
        img.save(path)
        print(f"Resized to {width}x{h_size}")
    else:
        print(f"File not found: {path}")
except Exception as e:
    print(f"Error: {e}")
