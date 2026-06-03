import os

backend_dir = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\MediScan (3) (1)\MediScan (10)\backend"

for root, dirs, files in os.walk(backend_dir):
    if "venv" in root or "__pycache__" in root or ".git" in root or "instance" in root:
        continue
    for file in files:
        if file.endswith(".py"):
            filepath = os.path.join(root, file)
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                    if "generic_pill.png" in content:
                        rel_path = os.path.relpath(filepath, backend_dir)
                        print(f"File: {rel_path}")
            except Exception:
                pass
