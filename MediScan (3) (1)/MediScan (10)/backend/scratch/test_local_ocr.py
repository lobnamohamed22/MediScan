import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from routes.prescriptions import run_local_ocr

filepath = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\MediScan (3) (1)\MediScan (10)\backend\uploads\prescriptions\presc_58e4dfb2-a2e3-4ffe-b12e-6c8f530167ae.jpg"
if not os.path.exists(filepath):
    print(f"File not found: {filepath}")
    sys.exit(1)

print("Running local OCR...")
words = run_local_ocr(filepath)
print(f"Detected words: {words}")
