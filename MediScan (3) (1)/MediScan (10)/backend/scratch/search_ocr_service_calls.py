import os

root_dir = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)"

for dirpath, dirnames, filenames in os.walk(root_dir):
    if any(x in dirpath.lower() for x in ['.git', 'node_modules', 'env', 'venv', '__pycache__', '.vscode']):
        continue
    for file in filenames:
        if file.endswith(('.py', '.dart', '.js')):
            filepath = os.path.join(dirpath, file)
            try:
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    if 'extract_medicine_from_image' in content:
                        print(f"Called in: {filepath}")
            except Exception:
                pass
