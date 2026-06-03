import os

mobile_lib = "c:/Users/lenovo/Downloads/MediScan (4) (1) (1)/MediScan (3) (1)/MediScan (10)/MediScan (10)/MediScan/mobile/lib"

print("Searching mobile files for blue colors or blue text styles...")
for root, dirs, files in os.walk(mobile_lib):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            try:
                with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    lines = content.splitlines()
                    for i, line in enumerate(lines):
                        if 'blue' in line.lower() or '2196f3' in line.lower():
                            print(f"[{file}:{i+1}] {line.strip()}")
            except Exception as e:
                pass
