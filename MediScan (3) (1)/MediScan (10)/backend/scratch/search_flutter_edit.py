import os

mobile_lib = "c:/Users/lenovo/Downloads/MediScan (4) (1) (1)/MediScan (3) (1)/MediScan (10)/MediScan (10)/MediScan/mobile/lib"

print("Searching mobile files for edit/inventory/readonly widgets...")
for root, dirs, files in os.walk(mobile_lib):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            try:
                with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    if "medicine" in content.lower() or "inventory" in content.lower() or "edit" in content.lower():
                        lines = content.splitlines()
                        for i, line in enumerate(lines):
                            if "readOnly" in line or "enabled" in line or "TextField" in line:
                                if "med" in line.lower() or "name" in line.lower() or "qty" in line.lower() or "price" in line.lower():
                                    print(f"Found in: {path} (Line {i+1})")
                                    print(f"  {line.strip()}")
            except Exception as e:
                pass
