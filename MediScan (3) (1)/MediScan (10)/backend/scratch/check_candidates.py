import os
import sys
import requests
import urllib.parse
import re

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from utils.images import verify_medicine_name_match

drugs = [
    "Cozaar 50mg",
    "Januvia 100mg",
    "Prednisolone 5mg",
    "Spironolactone 25mg",
    "Ciprofloxacin 500mg"
]

headers = {'User-Agent': 'MediScanMedicineCatalogBuilder/1.0 (contact@mediscan.com)'}

for drug in drugs:
    print(f"\n==================== {drug} ====================")
    query = drug.strip()
    query_clean = re.sub(r'\b\d+(?:\.\d*)?\s*(?:mg|g|ml|mcg|kg|tab|caps|cap)\b', '', query, flags=re.IGNORECASE).strip().lower()
    if not query_clean:
        query_clean = query.lower()
        
    search_url = f"https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json?drug_name={urllib.parse.quote(query_clean)}&pagesize=5"
    
    res = requests.get(search_url, headers=headers, timeout=5)
    if res.status_code != 200:
        print("Search API error")
        continue
        
    results = res.json().get('data', [])
    if not results:
        print("No search results")
        continue
        
    for r in results:
        title = r.get('title', '')
        matches = verify_medicine_name_match(drug, title)
        print(f"SPL Title: {title} | Matches: {matches}")
        if not matches:
            continue
            
        setid = r.get('setid')
        media_url = f"https://dailymed.nlm.nih.gov/dailymed/services/v2/spls/{setid}/media.json"
        res_media = requests.get(media_url, headers=headers, timeout=5)
        if res_media.status_code == 200:
            media_files = res_media.json().get('data', {}).get('media', [])
            print(f"Found {len(media_files)} media files:")
            for m in media_files:
                mime = m.get('mime_type', '')
                if 'image' in mime:
                    print(f"  - Name: {m.get('name')} | URL: {m.get('url')}")
        else:
            print("  Failed to get media")
