import os
import sys
import PIL.Image
import google.generativeai as genai
import json

# Setup API Key
api_key = os.getenv('GOOGLE_API_KEY') or os.getenv('GEMINI_API_KEY')
if not api_key:
    # Read from .env
    with open('.env', 'r') as f:
        for line in f:
            if line.startswith('GOOGLE_API_KEY='):
                api_key = line.split('=', 1)[1].strip()
                break

if not api_key:
    print("Error: No API key found")
    sys.exit(1)

genai.configure(api_key=api_key)

filepath = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\MediScan (3) (1)\MediScan (10)\backend\uploads\prescriptions\presc_58e4dfb2-a2e3-4ffe-b12e-6c8f530167ae.jpg"
if not os.path.exists(filepath):
    print(f"File not found: {filepath}")
    sys.exit(1)

image = PIL.Image.open(filepath)

OCR_PROMPT = """You are a medical OCR expert.
Read this handwritten prescription image carefully and thoroughly from top to bottom.
Extract EVERY single item listed on the prescription sheet, including:
- Standard medicines, pills, capsules, and tablets
- Creams, ointments, drops, and gels
- Medical devices, supplies, compression stockings (e.g., Venusen Compression Stocking), and braces

You MUST extract ALL items. Do not skip or omit any item. Double check the entire image to ensure no item is missed.

Return ONLY a valid JSON array like this, with no extra text or explanation:
[
  {
    "medicine_name": "Paracetamol 500mg",
    "dosage": "500mg",
    "frequency": "3 times daily",
    "duration_days": 5,
    "quantity": 15
  }
]
If you cannot read clearly, make your best guess based on medical context. Return ONLY the JSON array, nothing else."""

print("Calling Gemini model 'gemini-2.5-flash'...")
try:
    model = genai.GenerativeModel('gemini-2.5-flash')
    response = model.generate_content([OCR_PROMPT, image])
    print("\n--- Response ---")
    print(response.text)
except Exception as e:
    print(f"Error calling model: {e}")
