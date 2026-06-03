import os

lib_dir = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\MediScan (3) (1)\MediScan (10)\MediScan (10)\MediScan\mobile\lib"

for dirpath, dirnames, filenames in os.walk(lib_dir):
    for file in filenames:
        if file.endswith('.dart'):
            filepath = os.path.join(dirpath, file)
            try:
                with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    if 'prescription' in content.lower() or 'upload' in content.lower() or 'ocr' in content.lower():
                        print(f"Found in: {filepath}")
                        # Print occurrences of prescription api calls or logic
                        for idx, line in enumerate(content.splitlines(), 1):
                            if 'api' in line.lower() or 'upload' in line.lower() or 'medicines' in line.lower():
                                if 'prescription' in line.lower() or 'ocr' in line.lower() or 'med' in line.lower():
                                    print(f"  Line {idx}: {line.strip()}")
            except Exception as e:
                pass
