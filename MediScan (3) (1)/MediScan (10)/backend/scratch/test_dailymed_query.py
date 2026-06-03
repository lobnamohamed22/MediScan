import requests
import urllib.parse
import re

meds = ["Cozaar 50mg", "Januvia 100mg", "Prednisolone 5mg", "Spironolactone 25mg", "Ciprofloxacin 500mg"]

for med in meds:
    print(f"\n===== Querying DailyMed for: {med} =====")
    query_clean = re.sub(r'\b\d+(?:\.\d*)?\s*(?:mg|g|ml|mcg|kg|tab|caps|cap)\b', '', med, flags=re.IGNORECASE).strip().lower()
    search_url = f"https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json?drug_name={urllib.parse.quote(query_clean)}&pagesize=5"
    
    headers = {'User-Agent': 'MediScanMedicineCatalogBuilder/1.0 (contact@mediscan.com)'}
    res = requests.get(search_url, headers=headers, timeout=10)
    if res.status_code != 200:
        print(f"Failed to query SPLs for {med}: {res.status_code}")
        continue
        
    results = res.json().get('data', [])
    for r in results:
        title = r.get('title', '')
        setid = r.get('setid')
        print(f"SPL Title: {title} | SetID: {setid}")
        
        media_url = f"https://dailymed.nlm.nih.gov/dailymed/services/v2/spls/{setid}/media.json"
        res_media = requests.get(media_url, headers=headers, timeout=10)
        if res_media.status_code == 200:
            media_files = res_media.json().get('data', {}).get('media', [])
            for m in media_files:
                mime = m.get('mime_type', '')
                if 'image' in mime:
                    url = m.get('url')
                    name = m.get('name', '')
                    print(f"  Image Name: {name}")
                    print(f"  Image URL: {url}")
