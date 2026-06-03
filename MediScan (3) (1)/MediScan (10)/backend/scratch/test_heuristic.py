import os
import sys
import requests
from PIL import Image
from io import BytesIO

urls = {
    # Molecular structures / diagrams / drawings
    "Cozaar_01_Structure": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=9949448f-c3b9-44ee-94ed-c1aca8c90f39&name=cozaar-01.jpg",
    "Januvia_01_Structure": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=f85a48d0-0407-4c50-b0fa-7673a160bf01&name=januvia-01.jpg",
    "Januvia_02_Structure": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=f85a48d0-0407-4c50-b0fa-7673a160bf01&name=januvia-02.jpg",
    "Januvia_03_Structure": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=f85a48d0-0407-4c50-b0fa-7673a160bf01&name=januvia-03.jpg",
    "Pred_Structure": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=4c0dcbfd-2848-9bd0-e063-6394a90af5a7&name=pred-structure.jpg",
    "Spiro_Structure": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=3487305c-25a6-4e82-923c-3e4dd638c988&name=spironolactone-structure-image.jpg",
    "Spiro_Fig1_Graph": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=3487305c-25a6-4e82-923c-3e4dd638c988&name=spironolactone-figure-1.jpg",
    "Cipro_Str1_Structure": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=47d1e4c5-f669-4aca-9e8c-0d6bb833b859&name=ciprofloxacin-str1.jpg",
    
    # Real Packages / Boxes
    "Cozaar_02_Tablet": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=9949448f-c3b9-44ee-94ed-c1aca8c90f39&name=cozaar-02.jpg",
    "Cozaar_04_Carton": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=9949448f-c3b9-44ee-94ed-c1aca8c90f39&name=cozaar-04.jpg",
    "Januvia_04_Carton": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=f85a48d0-0407-4c50-b0fa-7673a160bf01&name=januvia-04.jpg",
    "Januvia_05_Carton": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=f85a48d0-0407-4c50-b0fa-7673a160bf01&name=januvia-05.jpg",
    "Pred_Carton": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=4c0dcbfd-2848-9bd0-e063-6394a90af5a7&name=prednisoLONE_OS_5mL_Carton_50ct.jpg",
    "Cipro_Package": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=47d1e4c5-f669-4aca-9e8c-0d6bb833b859&name=Ciprofloxacin+500mg_70518-4214-01.jpg"
}

headers = {'User-Agent': 'MediScanMedicineCatalogBuilder/1.0 (contact@mediscan.com)'}

def is_structure_or_diagram(img):
    # Convert to RGB to ensure 3 channels
    rgb_img = img.convert('RGB')
    
    # 1. Resize and check white pixels
    chk_img = rgb_img.resize((128, 128))
    # Using list conversion to avoid deprecation warnings in PIL 14
    pixels = list(chk_img.convert('RGB').getdata())
    total = len(pixels)
    
    white_count = sum(1 for r, g, b in pixels if r > 240 and g > 240 and b > 240)
    white_pct = (white_count / total) * 100
    
    # 2. Unique colors check in 64x64
    small_img = rgb_img.resize((64, 64))
    small_pixels = list(small_img.getdata())
    unique_colors = len(set(small_pixels))
    
    # Refined Heuristics:
    if white_pct > 92.0:
        return True, f"REJECTED: high white percentage ({white_pct:.1f}%)"
    if white_pct > 85.0 and unique_colors < 450:
        return True, f"REJECTED: diagram/structure (white={white_pct:.1f}%, colors={unique_colors})"
        
    return False, f"ACCEPTED (white={white_pct:.1f}%, colors={unique_colors})"

for key, url in urls.items():
    try:
        res = requests.get(url, headers=headers, timeout=10)
        if res.status_code == 200:
            img = Image.open(BytesIO(res.content))
            rejected, msg = is_structure_or_diagram(img)
            print(f"{key:25} | {msg}")
        else:
            print(f"{key:25} | HTTP error {res.status_code}")
    except Exception as e:
        print(f"{key:25} | Error: {str(e)}")
