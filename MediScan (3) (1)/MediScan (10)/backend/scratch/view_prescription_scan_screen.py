import os

filepath = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\MediScan (3) (1)\MediScan (10)\MediScan (10)\MediScan\mobile\lib\screens\prescription_scan_screen.dart"

try:
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    start_line = -1
    for idx, line in enumerate(lines):
        if 'uploadPrescription' in line:
            start_line = idx
            break
            
    if start_line != -1:
        print(f"--- prescription_scan_screen.dart around line {start_line+1} ---")
        for i in range(max(0, start_line - 15), min(start_line + 45, len(lines))):
            print(f"{i+1:3}: {lines[i]}", end='')
    else:
        print("uploadPrescription not found")
except Exception as e:
    print(f"Error: {e}")
