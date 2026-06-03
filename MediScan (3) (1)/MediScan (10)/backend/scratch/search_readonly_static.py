import os

static_dir = "c:/Users/lenovo/Downloads/MediScan (4) (1) (1)/MediScan (3) (1)/MediScan (10)/backend/static"

print("Searching for 'readOnly' or 'readonly' in static directory...")
for root, dirs, files in os.walk(static_dir):
    for file in files:
        if file.endswith(('.js', '.html')):
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
