with open(r'c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\MediScan (3) (1)\MediScan (10)\backend\routes\cart.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()
    for idx, line in enumerate(lines):
        if any(w in line for w in ['medicine_image', 'image_url']):
            print(f"Line {idx+1}: {line.strip()}")
