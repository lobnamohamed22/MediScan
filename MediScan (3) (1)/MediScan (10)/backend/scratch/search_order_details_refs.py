import os

mobile_lib = "c:/Users/lenovo/Downloads/MediScan (4) (1) (1)/MediScan (3) (1)/MediScan (10)/MediScan (10)/MediScan/mobile/lib"

print("Searching mobile files for OrderDetailsScreen references...")
for root, dirs, files in os.walk(mobile_lib):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            try:
                with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    if "OrderDetailsScreen" in content:
                        print(f"Referenced in: {path}")
            except Exception as e:
                pass
