with open(r'c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\MediScan (3) (1)\MediScan (10)\backend\routes\prescriptions.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()
    for idx, line in enumerate(lines):
        if any(w in line for w in ['medicine_image', 'image_url', 'get_image_hash_fallback_medicines']):
            print(f"Line {idx+1}: {line.strip()}")
