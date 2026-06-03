import os
import re

routes_dir = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\MediScan (3) (1)\MediScan (10)\backend\routes"

for file in os.listdir(routes_dir):
    if file.endswith(".py"):
        filepath = os.path.join(routes_dir, file)
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                matches = re.findall(r'(\b\w*image\w*\b)', content, re.IGNORECASE)
                if matches:
                    print(f"File: {file} | Found references: {set(matches)}")
        except Exception:
            pass
