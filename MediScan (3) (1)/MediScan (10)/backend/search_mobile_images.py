import os

mobile_dir = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\MediScan (3) (1)\MediScan (10)\MediScan (10)\MediScan\mobile"

keywords = ["medicine_image", "image", "png", "NetworkImage", "generic_pill", "panadol", "ibuprofen"]

for root, dirs, files in os.walk(mobile_dir):
    if ".dart_tool" in root or "build" in root or ".git" in root:
        continue
    for file in files:
        if file.endswith(".dart"):
            filepath = os.path.join(root, file)
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                    found = [k for k in keywords if k in content]
                    if found:
                        rel_path = os.path.relpath(filepath, mobile_dir)
                        print(f"File: {rel_path} | Found keywords: {found}")
            except Exception as e:
                pass
