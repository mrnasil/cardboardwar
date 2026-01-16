from PIL import Image
import os

source_path = r'f:\repos\godot\BrotatoClone\assets\sprites\cursor.png'
dest_path = r'f:\repos\godot\BrotatoClone\assets\cursor.png'

try:
    if os.path.exists(source_path):
        img = Image.open(source_path)
        print(f"Original size: {img.size}")
        
        # Custom resizing logic: Width 32px
        target_width = 32
        if img.width != target_width:
             w_percent = (target_width / float(img.size[0]))
             h_size = int((float(img.size[1]) * float(w_percent)))
             img = img.resize((target_width, h_size), Image.Resampling.LANCZOS)
        
        # Save directly (no 32x32 box constraint as the cursor is now taller)
        img.save(dest_path)
        print(f"Saved resized image to {dest_path}. Size: {img.size}")
    else:
        print(f"Source file not found: {source_path}")
except Exception as e:
    print(f"Error: {e}")
