import os

workspace = "c:/Users/lenovo/Downloads/MediScan (4) (1) (1)"

print("Searching for 'readOnly' or 'readonly' in static files...")
for root, dirs, files in os.walk(workspace):
    if any(p in root for p in ['node_modules', '.dart_tool', 'build', '.git', 'venv']):
        continue
    for file in files:
        if file.endswith(('.py', '.js', '.dart', '.html', '.css')):
            path = os.path.join(root, file)
            try:
                with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    if "readonly" in content.lower():
                        print(f"Found in: {path}")
                        lines = content.splitlines()
                        for i, line in enumerate(lines):
                            if "readonly" in line.lower():
                                print(f"  Line {i+1}: {line.strip()}")
            except Exception as e:
                pass
