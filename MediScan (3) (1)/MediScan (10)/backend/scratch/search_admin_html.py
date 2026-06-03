with open("c:/Users/lenovo/Downloads/MediScan (4) (1) (1)/MediScan (3) (1)/MediScan (10)/backend/static/admin/index.html", "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "inv-med-name" in line or "inventory-modal" in line:
        print(f"Line {i+1}: {line.strip()}")
