import os

filepath = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\MediScan (3) (1)\MediScan (10)\MediScan (10)\MediScan\mobile\lib\screens\prescription_verification_screen.dart"

try:
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    print(f"--- prescription_verification_screen.dart (1 to 100) ---")
    for i in range(0, min(100, len(lines))):
        print(f"{i+1:3}: {lines[i]}", end='')
except Exception as e:
    print(f"Error: {e}")
