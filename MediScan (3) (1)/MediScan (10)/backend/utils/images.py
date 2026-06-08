import os
import re
import requests
import urllib.parse
from PIL import Image
from io import BytesIO

def verify_medicine_name_match(medicine_name, title):
    """
    Strictly verifies if the DailyMed SPL title belongs to the exact medicine name.
    Returns True if it matches, False if there is any mismatch or uncertainty.
    """
    if not medicine_name or not title:
        return False
        
    # Clean strings: lowercase, replace punctuation/special chars with spaces (keep parentheses in title)
    q = medicine_name.lower().strip()
    t = title.lower().strip()
    
    # Remove manufacturer details enclosed in brackets (e.g. [ORGANON LLC])
    t = re.sub(r'\[[^\]]*\]', ' ', t).strip()
    
    # Remove dosage/strength numbers (e.g. 500mg, 50 mg, 5%, 10ml, etc.)
    num_pat = r'\b\d+(?:\.\d*)?\s*(?:mg|g|ml|mcg|kg|tab|caps|cap|%)\b'
    q = re.sub(num_pat, ' ', q)
    t = re.sub(num_pat, ' ', t)
    
    # Filler words and dosage forms to ignore in word sets
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
    
    # Extract parenthesis contents (generic name part inside brand SPLs)
    paren_match = re.search(r'\(([^)]+)\)', t)
    t_brand_part = t
    t_active_part = ''
    if paren_match:
        t_active_part = paren_match.group(1)
        # Brand part is outside parentheses
        t_brand_part = t.replace(f"({t_active_part})", " ")
        
    # Split by comma or semicolon to ignore packaging details/dosage form specifics after the primary name
    # e.g., "COZAAR" from "COZAAR, FILM COATED"
    t_brand_part = re.split(r'[\,\;\/]', t_brand_part)[0].strip()
    t_active_part = re.split(r'[\,\;\/]', t_active_part)[0].strip() if t_active_part else ''
    t_all_part = re.split(r'[\,\;\/]', t)[0].strip()
        
    def get_core_words(text):
        # Extract alphanumeric words and filter out filler/dosage words and pure numbers
        words = re.findall(r'[a-z0-9]+', text)
        return {w for w in words if w not in filler_words and not w.isdigit()}
        
    q_words = get_core_words(q)
    t_brand_words = get_core_words(t_brand_part)
    t_active_words = get_core_words(t_active_part) if t_active_part else set()
    t_all_words = get_core_words(t_all_part)
    
    if not q_words:
        return False
        
    # Check if query matches brand part exactly
    if t_brand_words and q_words == t_brand_words:
        return True
        
    # Check if query matches active part exactly (if present)
    if t_active_words and q_words == t_active_words:
        return True
        
    # Check if query matches all title words exactly (for non-parentheses titles)
    if not t_active_words and q_words == t_all_words:
        return True
        
    return False

def is_structure_or_diagram(img):
    """
    Analyzes visual features of a downloaded PIL image to reject chemical structures,
    molecular diagrams, graphs, documents, and logos.
    """
    try:
        rgb_img = img.convert('RGB')
        
        # 1. Check percentage of white/near-white pixels
        chk_img = rgb_img.resize((128, 128))
        pixels = list(chk_img.getdata())
        total = len(pixels)
        white_count = sum(1 for r, g, b in pixels if r > 240 and g > 240 and b > 240)
        white_pct = (white_count / total) * 100
        
        # 2. Check color variety in a smaller thumbnail
        small_img = rgb_img.resize((64, 64))
        small_pixels = list(small_img.getdata())
        unique_colors = len(set(small_pixels))
        
        # Heuristics:
        # Diagrams/structures have very high white percentage or low color counts
        if white_pct > 92.0:
            return True, f"high white percentage ({white_pct:.1f}%)"
        if white_pct > 85.0 and unique_colors < 450:
            return True, f"diagram/structure (white={white_pct:.1f}%, colors={unique_colors})"
            
        return False, None
    except Exception as e:
        return False, None

def fetch_medicine_image_from_dailymed(medicine_name, uploads_dir):
    """
    Queries DailyMed API, searches by drug name, fetches associated media,
    filters and ranks them to find an official package/box/carton photo,
    downloads and saves it locally, and returns the relative URL path.
    Includes strict naming filters, visual heuristics, and automatic brand-to-active fallbacks.
    """
    try:
        query = medicine_name.strip()
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
        
        def get_candidates_from_query(drug_query):
            query_clean = re.sub(r'\b\d+(?:\.\d*)?\s*(?:mg|g|ml|mcg|kg|tab|caps|cap)\b', '', drug_query, flags=re.IGNORECASE).strip().lower()
            if not query_clean:
                query_clean = drug_query.lower()
                
            search_url = f"https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json?drug_name={urllib.parse.quote(query_clean)}&pagesize=15"
            res = requests.get(search_url, headers=headers, timeout=5)
            if res.status_code != 200:
                return [], set()
                
            results = res.json().get('data', [])
            candidates_list = []
            generic_names_set = set()
            
            for r in results:
                title = r.get('title', '')
                
                # Extract generic name inside parentheses if available
                paren_match = re.search(r'\(([^)]+)\)', title)
                if paren_match:
                    gen_name = paren_match.group(1).split(',')[0].split(';')[0].strip()
                    if gen_name:
                        generic_names_set.add(gen_name)
                        
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
                                candidates_list.append((name, url))
                                
            return candidates_list, generic_names_set
            
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
                for word in query.lower().split():
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
                        
                        # Validate against visual structure/diagram heuristics
                        rejected, reason = is_structure_or_diagram(img)
                        if rejected:
                            continue
                            
                        # Generate safe local filename
                        safe_filename = "".join(c for c in medicine_name if c.isalnum() or c in (' ', '_', '-')).strip().replace(' ', '_').lower()
                        filename = f"{safe_filename}.png"
                        filepath = os.path.join(uploads_dir, 'medicines', filename)
                        
                        os.makedirs(os.path.dirname(filepath), exist_ok=True)
                        if img.mode in ('RGBA', 'LA', 'P'):
                            img = img.convert('RGB')
                        img.save(filepath, 'PNG')
                        return f"/uploads/medicines/{filename}"
                except Exception:
                    pass
            return None

        # Phase 1: Brand Search
        candidates, generic_names = get_candidates_from_query(query)
        path = process_candidates(candidates)
        if path:
            return path
            
        # Phase 2: Generic Fallback Search
        for gen in generic_names:
            gen_candidates, _ = get_candidates_from_query(gen)
            path = process_candidates(gen_candidates)
            if path:
                return path
                
        return None
    except Exception:
        return None

def resolve_medicine_image_path(medicine_name, uploads_dir):
    """
    Combines local verified asset matches and remote DailyMed NLM downloading.
    Strictly verified and saves paths to database records.
    """
    if not medicine_name:
        return '/uploads/medicines/generic_pill.png'
        
    name_lower = medicine_name.lower().strip()
    
    # 1. Local verified match first (fast and guaranteed)
    if 'paracetamol' in name_lower:
        return '/uploads/medicines/paracetamol.png'
    elif 'panadol' in name_lower:
        return '/uploads/medicines/panadol.png'
    elif 'ibuprofen' in name_lower or 'brufen' in name_lower:
        return '/uploads/medicines/ibuprofen.png'
    elif 'amoxicillin' in name_lower or 'amoxil' in name_lower or 'amoxycillin' in name_lower:
        return '/uploads/medicines/amoxicillin.png'
    elif 'augmentin' in name_lower:
        return '/uploads/medicines/augmentin.png'
    elif any(k in name_lower for k in ['conventin', 'gabapentin', 'conveniui', 'conventiui', 'convenu', 'conventu', 'conveni', 'conven', 'convenl']):
        return '/uploads/medicines/conventin.png'
    elif 'nexium' in name_lower or 'esomeprazole' in name_lower:
        return '/uploads/medicines/nexium.png'
    elif any(k in name_lower for k in ['recoxibright', 'etoricoxib', 'recoribright', 'recori', 'recox']):
        return '/uploads/medicines/recoxibright.png'
    elif 'sulfax' in name_lower:
        return '/uploads/medicines/sulfax.png'
    elif any(k in name_lower for k in ['sulfox', 'sulfoa', 'sulfora', 'sulfox gel', 'sulfora gel']):
        return '/uploads/medicines/sulfox.png'
    elif any(k in name_lower for k in ['venusen', 'venoson', 'venusan', 'venuson', 'venus', 'venos', 'stocking']):
        return '/uploads/medicines/venusen.png'
    elif 'acyclovir' in name_lower:
        return '/uploads/medicines/acyclovir_400mg.png'
    elif 'amlodipine' in name_lower:
        return '/uploads/medicines/amlodipine_5mg.png'
    elif 'amoxicillin 500mg' in name_lower:
        return '/uploads/medicines/amoxicillin_500mg.png'
    elif 'atorvastatin' in name_lower:
        return '/uploads/medicines/atorvastatin_20mg.png'
    elif 'januvia' in name_lower:
        return '/uploads/medicines/januvia_100mg.png'
    elif 'voltaren' in name_lower:
        return '/uploads/medicines/voltaren_75mg.png'
    elif 'cozaar' in name_lower:
        return '/uploads/medicines/cozaar_50mg.png'
    elif 'flagyl' in name_lower:
        return '/uploads/medicines/flagyl_500mg.png'
    elif 'lipitor' in name_lower:
        return '/uploads/medicines/lipitor_20mg.png'
    elif 'ventolin' in name_lower:
        return '/uploads/medicines/ventolin.png'
        
    # 2. Remote image retrieval from trusted source (DailyMed NLM)
    remote_path = fetch_medicine_image_from_dailymed(medicine_name, uploads_dir)
    if remote_path:
        return remote_path
        
    # 3. Fallback temporary placeholder
    return '/uploads/medicines/generic_pill.png'
