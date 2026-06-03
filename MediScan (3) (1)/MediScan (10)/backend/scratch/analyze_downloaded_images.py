import os
import sys
import requests
from PIL import Image
from io import BytesIO

urls = {
    "Cozaar_01": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=9949448f-c3b9-44ee-94ed-c1aca8c90f39&name=cozaar-01.jpg",
    "Cozaar_02": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=9949448f-c3b9-44ee-94ed-c1aca8c90f39&name=cozaar-02.jpg",
    "Cozaar_04": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=9949448f-c3b9-44ee-94ed-c1aca8c90f39&name=cozaar-04.jpg",
    "Januvia_01": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=f85a48d0-0407-4c50-b0fa-7673a160bf01&name=januvia-01.jpg",
    "Januvia_02": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=f85a48d0-0407-4c50-b0fa-7673a160bf01&name=januvia-02.jpg",
    "Januvia_03": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=f85a48d0-0407-4c50-b0fa-7673a160bf01&name=januvia-03.jpg",
    "Januvia_04": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=f85a48d0-0407-4c50-b0fa-7673a160bf01&name=januvia-04.jpg",
    "Januvia_05": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=f85a48d0-0407-4c50-b0fa-7673a160bf01&name=januvia-05.jpg",
    "Januvia_06": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=f85a48d0-0407-4c50-b0fa-7673a160bf01&name=januvia-06.jpg",
    "Pred_Structure": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=4c0dcbfd-2848-9bd0-e063-6394a90af5a7&name=pred-structure.jpg",
    "Pred_Carton": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=4c0dcbfd-2848-9bd0-e063-6394a90af5a7&name=prednisoLONE_OS_5mL_Carton_50ct.jpg",
    "Spiro_Fig1": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=3487305c-25a6-4e82-923c-3e4dd638c988&name=spironolactone-figure-1.jpg",
    "Spiro_Structure": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=3487305c-25a6-4e82-923c-3e4dd638c988&name=spironolactone-structure-image.jpg",
    "Spiro_lbl": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=1c31c953-05ce-475a-b93f-80aeb12bde95&name=lbl713352204.jpg",
    "Cipro_Str1": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=47d1e4c5-f669-4aca-9e8c-0d6bb833b859&name=ciprofloxacin-str1.jpg",
    "Cipro_Remedy_Label": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=47d1e4c5-f669-4aca-9e8c-0d6bb833b859&name=Remedy_Label.jpg",
    "Cipro_Package": "https://dailymed.nlm.nih.gov/dailymed/image.cfm?setid=47d1e4c5-f669-4aca-9e8c-0d6bb833b859&name=Ciprofloxacin+500mg_70518-4214-01.jpg"
}

headers = {'User-Agent': 'MediScanMedicineCatalogBuilder/1.0 (contact@mediscan.com)'}

for key, url in urls.items():
    try:
        res = requests.get(url, headers=headers, timeout=10)
        if res.status_code == 200:
            img = Image.open(BytesIO(res.content))
            width, height = img.size
            
            # Let's count white/near-white pixels
            # Convert to RGB to ensure 3 channels
            rgb_img = img.convert('RGB')
            pixels = list(rgb_img.getdata())
            total_pixels = len(pixels)
            
            # Count pixels close to white (e.g. R, G, B all > 240)
            white_count = sum(1 for r, g, b in pixels if r > 240 and g > 240 and b > 240)
            white_pct = (white_count / total_pixels) * 100
            
            # Let's count number of unique colors
            # To be efficient, we can check number of unique colors in a resized/smaller version
            small_img = rgb_img.resize((64, 64))
            small_pixels = list(small_img.getdata())
            unique_colors = len(set(small_pixels))
            
            print(f"{key:25} | Size: {width:4}x{height:<4} | White Pixels: {white_pct:5.1f}% | Unique Colors (64x64): {unique_colors:4} | URL: {url.split('name=')[-1][:30]}...")
        else:
            print(f"{key:25} | Failed to fetch (Status: {res.status_code})")
    except Exception as e:
        print(f"{key:25} | Error: {str(e)}")
