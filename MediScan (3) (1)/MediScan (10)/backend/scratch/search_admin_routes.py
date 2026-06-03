with open("c:/Users/lenovo/Downloads/MediScan (4) (1) (1)/MediScan (3) (1)/MediScan (10)/backend/routes/admin.py", "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()
for i, line in enumerate(lines):
    if "/inventory" in line or "def " in line:
        if "inventory" in line or "med" in line or "route" in line:
            print(f"Line {i+1}: {line.strip()}")
