import os

filepath = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\MediScan (3) (1)\MediScan (10)\MediScan (10)\MediScan\mobile\lib\services\api_service.dart"

try:
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    # Find uploadPrescription function
    start_line = -1
    for idx, line in enumerate(lines):
        if 'uploadPrescription' in line:
            start_line = idx
            break
            
    if start_line != -1:
        print(f"--- api_service.dart from line {start_line+1} ---")
        for i in range(start_line, min(start_line + 45, len(lines))):
            print(f"{i+1:3}: {lines[i]}", end='')
    else:
        print("uploadPrescription not found")
except Exception as e:
    print(f"Error: {e}")
