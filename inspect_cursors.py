import os
from PIL import Image

paths = [
    r'f:\repos\godot\BrotatoClone\assets\cursor.png',
    r'f:\repos\godot\BrotatoClone\assets\sprites\cursor.png'
]

for path in paths:
    print(f"Checking {path}...")
    if os.path.exists(path):
        try:
            with Image.open(path) as img:
                print(f"  Valid image. Size: {img.size}, Format: {img.format}")
        except Exception as e:
            print(f"  Error opening image: {e}")
            # Try to see file size
            print(f"  File size in bytes: {os.path.getsize(path)}")
    else:
        print("  File does not exist.")
