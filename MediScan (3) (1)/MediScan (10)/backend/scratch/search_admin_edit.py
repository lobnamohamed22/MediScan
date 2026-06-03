with open("c:/Users/lenovo/Downloads/MediScan (4) (1) (1)/MediScan (3) (1)/MediScan (10)/backend/static/admin/app.js", "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "edit" in line.lower() or "inventory" in line.lower():
        print(f"Line {i+1}: {line.strip()}")
