import os
import sys
import re
import requests
import urllib.parse
from PIL import Image
from io import BytesIO

# Ensure uploads/medicines exists locally for testing
backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
uploads_dir = os.path.join(backend_dir, "uploads")
meds_dir = os.path.join(uploads_dir, "medicines")
os.makedirs(meds_dir, exist_ok=True)

headers = {'User-Agent': 'MediScanMedicineCatalogBuilder/1.0 (contact@mediscan.com)'}

ignored_patterns = [
    r'structure',
    r'\bstr\b',
    r'[-_]str\d*',
    r'fig\d+',
    r'figure',
    r'label',
    r'\blbl',
    r'logo',
    r'chart',
    r'table',
    r'diagram',
    r'chemical',
    r'molecular',
    r'formula',
    r'graph',
    r'schematic',
    r'sketch',
    r'draw',
    r'line',
    r'doc',
    r'text',
    r'sheet',
    r'insert',
    r'info',
    r'monograph',
    r'warning',
    r'illustration',
    r'specimen',
    r'package[-_]insert',
    r'pi[-_]image',
    r'pi\d'
]

package_keywords = [
    'carton', 'box', 'package', 'container', 'blister', 'case', 'bottle', 
    'outer', 'pack', 'pkg', 'vial', 'ampule', 'pouch', 'wallet'
]

def verify_medicine_name_match(medicine_name, title):
    if not medicine_name or not title:
        return False
    q = medicine_name.lower().strip()
    t = title.lower().strip()
    t = re.sub(r'\[[^\]]*\]', ' ', t).strip()
    num_pat = r'\b\d+(?:\.\d*)?\s*(?:mg|g|ml|mcg|kg|tab|caps|cap|%)\b'
    q = re.sub(num_pat, ' ', q)
    t = re.sub(num_pat, ' ', t)
    
    filler_words = {
        'tablet', 'tablets', 'capsule', 'capsules', 'gel', 'cream', 'suspension',
        'injection', 'injections', 'solution', 'spray', 'drops', 'ointment',
        'inhaler', 'film', 'patch', 'elixir', 'syrup', 'usp', 'oral', 'topical',
        'ophthalmic', 'for', 'and', 'with', 'coax', 'sodium', 'potassium',
        'hydrochloride', 'hcl', 'phosphate', 'sulfate', 'calcium', 'maleate',
        'mesylate', 'tartrate', 'acetate', 'coated', 'clofibrate', 'solutab',
        'soluble', 'disintegrating', 'extended', 'release', 'delayed', 'enteric',
        'chewable', 'chewables', 'caplet', 'caplets', 'powder', 'aerosol'
    }
    
    paren_match = re.search(r'\(([^)]+)\)', t)
    t_brand_part = t
    t_active_part = ''
    if paren_match:
        t_active_part = paren_match.group(1)
        t_brand_part = t.replace(f"({t_active_part})", " ")
        
    t_brand_part = re.split(r'[\,\;\/]', t_brand_part)[0].strip()
    t_active_part = re.split(r'[\,\;\/]', t_active_part)[0].strip() if t_active_part else ''
    t_all_part = re.split(r'[\,\;\/]', t)[0].strip()
        
    def get_core_words(text):
        words = re.findall(r'[a-z0-9]+', text)
        return {w for w in words if w not in filler_words and not w.isdigit()}
        
    q_words = get_core_words(q)
    t_brand_words = get_core_words(t_brand_part)
    t_active_words = get_core_words(t_active_part) if t_active_part else set()
    t_all_words = get_core_words(t_all_part)
    
    if not q_words:
        return False
    if t_brand_words and q_words == t_brand_words:
        return True
    if t_active_words and q_words == t_active_words:
        return True
    if not t_active_words and q_words == t_all_words:
        return True
    return False

def is_structure_or_diagram(img):
    rgb_img = img.convert('RGB')
    chk_img = rgb_img.resize((128, 128))
    pixels = list(chk_img.convert('RGB').getdata())
    total = len(pixels)
    white_count = sum(1 for r, g, b in pixels if r > 240 and g > 240 and b > 240)
    white_pct = (white_count / total) * 100
    
    small_img = rgb_img.resize((64, 64))
    small_pixels = list(small_img.getdata())
    unique_colors = len(set(small_pixels))
    
    if white_pct > 92.0:
        return True, f"high white percentage ({white_pct:.1f}%)"
    if white_pct > 85.0 and unique_colors < 450:
        return True, f"diagram/structure (white={white_pct:.1f}%, colors={unique_colors})"
    return False, None

def get_candidates_from_query(drug_query, medicine_name):
    query_clean = re.sub(r'\b\d+(?:\.\d*)?\s*(?:mg|g|ml|mcg|kg|tab|caps|cap)\b', '', drug_query, flags=re.IGNORECASE).strip().lower()
    if not query_clean:
        query_clean = drug_query.lower()
        
    search_url = f"https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json?drug_name={urllib.parse.quote(query_clean)}&pagesize=15"
    
    res = requests.get(search_url, headers=headers, timeout=5)
    if res.status_code != 200:
        return [], set()
        
    results = res.json().get('data', [])
    candidates = []
    generic_names = set()
    
    for r in results:
        title = r.get('title', '')
        
        # Extract generic name inside parentheses if available
        paren_match = re.search(r'\(([^)]+)\)', title)
        if paren_match:
            gen_name = paren_match.group(1).split(',')[0].split(';')[0].strip()
            if gen_name:
                generic_names.add(gen_name)
                
        if not verify_medicine_name_match(medicine_name, title):
            continue
            
        setid = r.get('setid')
        media_url = f"https://dailymed.nlm.nih.gov/dailymed/services/v2/spls/{setid}/media.json"
        res_media = requests.get(media_url, headers=headers, timeout=5)
        if res_media.status_code == 200:
            media_files = res_media.json().get('data', {}).get('media', [])
            for m in media_files:
                mime = m.get('mime_type', '')
                if 'image' in mime:
                    url = m.get('url')
                    name = m.get('name', '')
                    if url:
                        candidates.append((name, url))
                        
    return candidates, generic_names

def fetch_image(medicine_name):
    # Phase 1: Search by Brand/Input Name
    print(f"Searching brand query: '{medicine_name}'")
    candidates, generic_names = get_candidates_from_query(medicine_name, medicine_name)
    
    # Filter and score candidates
    def process_candidates(candidates_list):
        scored = []
        for name, url in candidates_list:
            name_lower = name.lower()
            ignored = False
            for pattern in ignored_patterns:
                if re.search(pattern, name_lower):
                    ignored = True
                    break
            if ignored:
                continue
                
            score = 0
            for pk in package_keywords:
                if pk in name_lower:
                    score += 15
            for word in medicine_name.lower().split():
                if word in name_lower:
                    score += 5
            score += 1
            scored.append((score, name, url))
            
        scored.sort(key=lambda x: x[0], reverse=True)
        
        for score, name, url in scored:
            try:
                img_res = requests.get(url, headers=headers, timeout=10)
                if img_res.status_code == 200:
                    img = Image.open(BytesIO(img_res.content))
                    rejected, reason = is_structure_or_diagram(img)
                    if rejected:
                        print(f"  Visual reject for {name}: {reason}")
                        continue
                        
                    # Save
                    safe_filename = "".join(c for c in medicine_name if c.isalnum() or c in (' ', '_', '-')).strip().replace(' ', '_').lower()
                    filename = f"{safe_filename}.png"
                    filepath = os.path.join(meds_dir, filename)
                    
                    if img.mode in ('RGBA', 'LA', 'P'):
                        img = img.convert('RGB')
                    img.save(filepath, 'PNG')
                    print(f"  SUCCESSFULLY RESOLVED: {filename} from {url}")
                    return f"/uploads/medicines/{filename}"
            except Exception as e:
                print(f"  Error downloading {name}: {e}")
        return None

    path = process_candidates(candidates)
    if path:
        return path
        
    # Phase 2: Brand search failed to yield a package, try generic fallbacks
    print(f"Brand search failed. Generics parsed: {generic_names}")
    for gen in generic_names:
        print(f"Searching generic fallback query: '{gen}'")
        gen_candidates, _ = get_candidates_from_query(gen, medicine_name)
        path = process_candidates(gen_candidates)
        if path:
            return path
            
    print("Failed to resolve carton/package photo. Using placeholder.")
    return '/uploads/medicines/generic_pill.png'

# Test resolution for the 5 target drugs
drugs = [
    "Cozaar 50mg",
    "Januvia 100mg",
    "Prednisolone 5mg",
    "Spironolactone 25mg",
    "Ciprofloxacin 500mg"
]

for d in drugs:
    print(f"\n===== RESOLVING IMAGE FOR: {d} =====")
    res_path = fetch_image(d)
    print(f"Result Path for {d}: {res_path}")
