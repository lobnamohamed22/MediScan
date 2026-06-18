import pymysql
import re
from datetime import date, datetime

def calculate_levenshtein_distance(s1, s2):
    if len(s1) < len(s2):
        return calculate_levenshtein_distance(s2, s1)
    if len(s2) == 0:
        return len(s1)
    v0 = [0] * (len(s2) + 1)
    v1 = [0] * (len(s2) + 1)
    for i in range(len(v0)):
        v0[i] = i
    for i in range(len(s1)):
        v1[0] = i + 1
        for j in range(len(s2)):
            cost = 0 if s1[i] == s2[j] else 1
            v1[j + 1] = min(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost)
        v0 = list(v1)
    return v0[len(s2)]

def calculate_similarity(s1, s2):
    s1 = s1.lower().strip()
    s2 = s2.lower().strip()
    if s1 == s2:
        return 1.0
    if not s1 or not s2:
        return 0.0
    suffixes_pat = r'\b(?:\d+\.?\d*\s*)?(mg|g|ml|cream|gel|injection|inhaler|tablets|tablet|capsules|capsule)\b'
    clean1 = re.sub(suffixes_pat, '', s1).strip()
    clean2 = re.sub(suffixes_pat, '', s2).strip()
    clean1 = re.sub(r'\s+', ' ', clean1).strip()
    clean2 = re.sub(r'\s+', ' ', clean2).strip()
    if clean1 == clean2:
        return 1.0
    if not clean1 or not clean2:
        return 0.0
    if clean1 in clean2 or clean2 in clean1:
        common_len = min(len(clean1), len(clean2))
        max_len = max(len(clean1), len(clean2))
        return common_len / max_len
    distance = calculate_levenshtein_distance(clean1, clean2)
    max_length = max(len(clean1), len(clean2))
    score = 1.0 - (distance / max_length)
    return score

try:
    connection = pymysql.connect(
        host='127.0.0.1',
        user='root',
        password='',
        database='mediscan_db',
        cursorclass=pymysql.cursors.DictCursor
    )
    with connection.cursor() as cursor:
        def get_global_avg_price(med_name):
            # direct match in other pharmacies
            cursor.execute("SELECT price FROM medicine_inventory WHERE medicine_name LIKE %s AND price > 0", (med_name,))
            g_prices = cursor.fetchall()
            if g_prices:
                return sum(float(p['price']) for p in g_prices) / len(g_prices)
            
            # fuzzy match in other pharmacies
            cursor.execute("SELECT medicine_name, AVG(price) as avg_p FROM medicine_inventory WHERE price > 0 GROUP BY medicine_name")
            all_prices = cursor.fetchall()
            
            best_ratio = 0.0
            best_price = 0.0
            for c in all_prices:
                ratio = calculate_similarity(med_name, c['medicine_name'])
                if ratio > best_ratio:
                    best_ratio = ratio
                    best_price = float(c['avg_p'])
            if best_ratio >= 0.70:
                return best_price
            return 30.0  # default price fallback

        # Let's test with the pharmacy_id in the exact row we found:
        # '0066d622-ab38-404a-b987-4836c714ed2c'
        pharmacy_id = '1'
        names = ['panadol']
        
        for raw_name in names:
            name_clean = raw_name.strip()
            qty = 1
            matched_name = None
            avg_price = 0.0
            total_stock = 0
            available = False
            matched = False
            
            # 1. Search in specific pharmacy inventory
            cursor.execute("SELECT * FROM medicine_inventory WHERE pharmacy_id = %s AND medicine_name LIKE %s", (pharmacy_id, name_clean))
            inv_matches = cursor.fetchall()
            print(f"inv_matches (exact): {inv_matches}")
            
            if not inv_matches:
                # Fuzzy match in specific pharmacy inventory
                cursor.execute("SELECT * FROM medicine_inventory WHERE pharmacy_id = %s", (pharmacy_id,))
                all_pharm_inv = cursor.fetchall()
                best_ratio = 0.0
                pharmacy_match = None
                for item in all_pharm_inv:
                    ratio = calculate_similarity(name_clean, item['medicine_name'])
                    if ratio > best_ratio:
                        best_ratio = ratio
                        pharmacy_match = item
                if best_ratio >= 0.70 and pharmacy_match:
                    inv_matches = [pharmacy_match]
                print(f"inv_matches (fuzzy): {inv_matches}")
                
            if inv_matches:
                matched = True
                matched_name = inv_matches[0]['medicine_name']
                total_stock = sum(int(r['stock_quantity']) if r['stock_quantity'] is not None else 0 for r in inv_matches)
                valid_prices = [float(r['price']) for r in inv_matches if r['price'] is not None and r['price'] > 0]
                if valid_prices:
                    avg_price = sum(valid_prices) / len(valid_prices)
                    available = total_stock > 0
                else:
                    avg_price = get_global_avg_price(matched_name)
                    available = False
                    total_stock = 0
            
            print(f"RESULT: Name: {name_clean}, Matched: {matched}, Matched Name: {matched_name}, Price: {avg_price}, Stock: {total_stock}, Available: {available}")
finally:
    connection.close()
