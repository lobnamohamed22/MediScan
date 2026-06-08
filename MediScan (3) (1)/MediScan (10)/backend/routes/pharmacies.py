from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from extensions import db
from sqlalchemy import text
from models.pharmacy import Pharmacy
from models.medicine import MedicineInventory, MedicineInfo

pharmacies_bp = Blueprint('pharmacies', __name__)

def transliterate_arabic_to_english(text):
    if not text:
        return text
    
    # Check if text contains Arabic characters (Unicode range 0x0600 - 0x06FF)
    has_arabic = any(0x0600 <= ord(c) <= 0x06FF for c in text)
    if not has_arabic:
        # Check if it has Franco names like "MSTFy MHMWD"
        franco_map = {
            "MSTFy MHMWD": "Mostafa Mahmoud Pharmacy",
            "Abdel-Khaiek": "Abdel-Khalek Pharmacy",
            "elezaby": "El Ezaby Pharmacy",
            "elezaby": "El Ezaby Pharmacy",
            "Mti": "MTI Pharmacy",
            "sandy Pharmacy": "Sandy Pharmacy",
            "Sandy pharmacy": "Sandy Pharmacy",
            "Dr George Anwar ferig": "Dr. George Anwar Farag Pharmacy",
            "Pharmacy SWSN ALHDYTha": "Sawsan Al-Hadeetha Pharmacy",
            "Pharmacy Roushdy": "Roushdy Pharmacy",
            "Pharmacy KARMN": "Carmen Pharmacy",
            "Pharmacy ShAHBWR": "Shahbour Pharmacy",
            "Pharmacy FAYQ": "Fayek Pharmacy",
            "Pharmacy ALMRWa": "Al-Marwa Pharmacy",
            "Pharmacy AShRF": "Ashraf Pharmacy",
            "Pharmacy ALWLYD": "Al-Waleed Pharmacy",
            "Pharmacy JAMAa ALDWL ALARBYa": "Arab League Pharmacy",
            "Pharmacy ALMMALYK": "Al-Mamalik Pharmacy",
            "Pharmacy LYLa": "Layla Pharmacy",
            "Pharmacy ALaSAAF BRMSYS": "Al-Isaaf Pharmacy (Ramses)",
            "Pharmacy HSNYN": "Hosny Pharmacy",
            "Pharmacy ABD ALRHMN SALH": "Abdel-Rahman Saleh Pharmacy",
            "Dr. Pharmacy TARQ ALALKY (AWNY SABQA)": "Dr. Tarek Al-Alky Pharmacy",
            "Pharmacies SYF": "Seif Pharmacy",
            "AZBY": "El Ezaby Pharmacy",
            "NWRMNDY": "Normandy Pharmacy",
            "Dr. Pharmacy HNAN MHMWD TH": "Dr. Hanan Mahmoud Pharmacy",
            "Pharmacy AHMD ABW ALFTWH": "Dr. Ahmed Abou Al-Fotouh Pharmacy",
            "Pharmacy NWR ALASLaM": "Nour Al-Islam Pharmacy",
            "Pharmacy MSTFy MHMWD": "Mostafa Mahmoud Pharmacy",
            "Nagui": "Nagui Pharmacy",
            "Saad": "Saad Pharmacy",
            "Elezaby": "El Ezaby Pharmacy",
            "Hindam": "Hindam Pharmacy",
            "Boon": "Boon Pharmacy",
            "Hanna pharmacy": "Hanna Pharmacy",
            "Reham pharmacy": "Reham Pharmacy",
            "Al-Quds pharmacy": "Al-Quds Pharmacy",
            "Makram pharmacy": "Makram Pharmacy",
            "Care pharmacy": "Care Pharmacy",
            "Al-Safa pharmacy": "Al-Safa Pharmacy",
            "Dawa2y": "Dawaey Pharmacy",
            "Africia": "Africa Pharmacy",
            "Sakla": "Sakla Pharmacy",
            "Al Azaby": "El Ezaby Pharmacy",
            "ShARA ALJAMAa ALHDYTha": "Modern University Street",
            "ShARA ALMNYL": "Manial Street",
            "ShARA ALWHDH": "El-Wehda Street",
            "ShARA AHMD TYSYR": "Ahmed Taysir Street",
            "ShARA BWRSAYD": "Port Said Street",
            "ShARA FYLYB HNA": "Philip Henein Street",
            "ShARA ALRWDa": "El-Rowdah Street",
            "ShARA KhLF ALNADy": "Behind the Club Street",
            "ShARA AThMAN BN AFAN": "Othman Ibn Affan Street",
            "HARa ALTMSAH": "El-Temsah Alley",
            "ALQAHRa": "Cairo",
            "ABW BKR ALSDYQ": "Abu Bakr Al-Siddiq Street",
        }
        for fr, en in franco_map.items():
            if fr in text:
                text = text.replace(fr, en)
        return text

    # Exact name mappings first
    exact_mappings = {
        "عز الدين": "Ezzeddin Pharmacy",
        "صيدلية عز الدين": "Ezzeddin Pharmacy",
        "أبو العز": "Abou El Ezz Pharmacy",
        "صيدلية أبو العز": "Abou El Ezz Pharmacy",
        "البدري": "El Badry Pharmacy",
        "صيدلية البدري": "El Badry Pharmacy",
        "مصطفى محمود": "Mostafa Mahmoud Pharmacy",
        "صيدلية مصطفى محمود": "Mostafa Mahmoud Pharmacy",
        "المنى": "El Mouna Pharmacy",
        "صيدلية المنى": "El Mouna Pharmacy",
        "اللواء": "El Lewaa Pharmacy",
        "صيدلية اللواء": "El Lewaa Pharmacy",
        "سالم": "Salem Pharmacy",
        "صيدلية سالم": "Salem Pharmacy",
        "ايهاب سمير": "Ihab Samir Pharmacy",
        "صيدلية ايهاب سمير": "Ihab Samir Pharmacy",
        "الإسعاف": "Al-Isaaf Pharmacy",
        "صيدلية الإسعاف": "Al-Isaaf Pharmacy",
        "العزبي": "El Ezaby Pharmacy",
        "صيدلية العزبي": "El Ezaby Pharmacy",
        "نورالدين": "Nour El Din Pharmacy",
        "صيدلية نورالدين": "Nour El Din Pharmacy",
        "الاسكندرية": "Alexandria Pharmacy",
        "صيدلية الاسكندرية": "Alexandria Pharmacy",
        "محمود": "Mahmoud Pharmacy",
        "صيدلية محمود": "Mahmoud Pharmacy",
        "حياتي": "Hayati Pharmacy",
        "صيدلية حياتي": "Hayati Pharmacy",
        "دلمار وعطاالله": "Delmar & Attalla Pharmacy",
        "صيدلية دلمار وعطاالله": "Delmar & Attalla Pharmacy",
        "السمني": "El Semary Pharmacy",
        "صيدلية السمني": "El Semary Pharmacy",
        "فضل": "Fadl Pharmacy",
        "صيدلية فضل": "Fadl Pharmacy",
        "دكتور سامح": "Dr. Sameh Pharmacy",
        "صيدلية دكتور سامح": "Dr. Sameh Pharmacy",
        "مكة": "Mekka Pharmacy",
        "صيدلية مكة": "Mekka Pharmacy",
        "نهلة": "Nahla Pharmacy",
        "صيدليات نهلة": "Nahla Pharmacy",
        "الشنهاب": "El Shanhab Pharmacy",
        "صيدليه الشنهاب": "El Shanhab Pharmacy",
        "د. نورهان": "Dr. Nourhan Pharmacy",
        "صيدلية د. نورهان": "Dr. Nourhan Pharmacy",
        "رنا": "Rana Pharmacy",
        "ص.رنا": "Rana Pharmacy",
        "الفتح": "Al-Fath Pharmacy",
        "صيدليه الفتح": "Al-Fath Pharmacy",
        "سحر": "Sahar Pharmacy",
        "صيدلية سحر": "Sahar Pharmacy",
        "عماد": "Emad Pharmacy",
        "صيدلية عماد": "Emad Pharmacy",
        "الخليج": "El Khalij Pharmacy",
        "صيدلية الخليج": "El Khalij Pharmacy",
        "رشدى": "Roushdy Pharmacy",
        "صيدلية رشدى": "Roushdy Pharmacy",
        "علي": "Ali Pharmacy",
        "صيدلية علي": "Ali Pharmacy",
        "نورهان": "Nourhan Pharmacy",
        "فايق": "Fayek Pharmacy",
        "مروة": "Marwa Pharmacy",
        "الكردي": "El Kordy Pharmacy",
        "طارق": "Tarek Pharmacy",
        "العلكي": "El Alky Pharmacy",
        "عوني": "Awny Pharmacy",
        "العجيزي": "El Ageezy Pharmacy",
        "المعادي": "Maadi Pharmacy",
        "البرج": "El Borg Pharmacy",
    }

    cleaned_text = text.strip()
    if cleaned_text in exact_mappings:
        return exact_mappings[cleaned_text]

    # Substring replacements
    replacements = {
        "صيدلية الدكتور": "Dr. Pharmacy",
        "صيدلية د.": "Dr. Pharmacy",
        "صيدلية د": "Dr. Pharmacy",
        "صيدلية": "Pharmacy",
        "صيدليات": "Pharmacies",
        "صيدليه": "Pharmacy",
        "ص.": "Pharmacy ",
        "دكتور": "Dr.",
        "د.": "Dr.",
    }
    
    for ar, en in replacements.items():
        text = text.replace(ar, en)

    char_map = {
        'أ': 'A', 'إ': 'A', 'آ': 'A', 'ا': 'A',
        'ب': 'B',
        'ت': 'T', 'ة': 'a',
        'ث': 'Th',
        'ج': 'J',
        'ح': 'H',
        'خ': 'Kh',
        'د': 'D',
        'ذ': 'Th',
        'ر': 'R',
        'ز': 'Z',
        'س': 'S',
        'ش': 'Sh',
        'ص': 'S',
        'ض': 'D',
        'ط': 'T',
        'ظ': 'Z',
        'ع': 'A',
        'غ': 'Gh',
        'ف': 'F',
        'ق': 'Q',
        'ك': 'K',
        'ل': 'L',
        'م': 'M',
        'ن': 'N',
        'ه': 'H',
        'و': 'W',
        'ي': 'Y', 'ى': 'y',
        'ء': '', 'ئ': 'Y', 'ؤ': 'W',
    }

    result = []
    i = 0
    while i < len(text):
        if i < len(text) - 1 and text[i:i+2] == 'لا':
            result.append('La')
            i += 2
            continue
            
        c = text[i]
        if 0x0600 <= ord(c) <= 0x06FF:
            result.append(char_map.get(c, c))
        else:
            result.append(c)
        i += 1
        
    res_str = "".join(result)
    import re
    res_str = re.sub(r'\s+', ' ', res_str).strip()
    return res_str

# -------------------------------
# 1. GET PHARMACY BY ID
# -------------------------------
@pharmacies_bp.route('/<string:id>', methods=['GET'])
@jwt_required()
def get_pharmacy(id):
    try:
        pharmacy = Pharmacy.query.filter_by(pharmacy_id=id).first()
        if not pharmacy:
            return jsonify({'success': False, 'message': 'Pharmacy not found'}), 404
        # Transliterate dynamic Arabic properties if present
        data = pharmacy.to_dict()
        data['name'] = transliterate_arabic_to_english(data['name'])
        data['address'] = transliterate_arabic_to_english(data['address'])
        return jsonify({'success': True, 'data': data}), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# GET PHARMACY INVENTORY BY PHARMACY ID
@pharmacies_bp.route('/<string:id>/inventory', methods=['GET'])
@jwt_required()
def get_pharmacy_inventory(id):
    try:
        from models.medicine import MedicineInventory
        inventory = MedicineInventory.query.filter_by(pharmacy_id=id).all()
        return jsonify({
            'success': True,
            'data': [i.to_dict() for i in inventory]
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

def fetch_and_register_osm_pharmacies(lat, lng, radius_km, name_filter=None):
    import requests
    import random
    from datetime import date, timedelta
    from models.pharmacy import Pharmacy
    from models.medicine import MedicineInventory, MedicineInfo
    from extensions import db

    if not lat or not lng:
        return

    # Check Egypt geographic boundaries (22.0 <= lat <= 32.0 and 24.0 <= lng <= 37.0)
    try:
        lat_f = float(lat)
        lng_f = float(lng)
        if not (22.0 <= lat_f <= 32.0 and 24.0 <= lng_f <= 37.0):
            return
    except (ValueError, TypeError):
        return

    # Cap radius to 15km to avoid massive queries
    radius_meters = min(int(float(radius_km) * 1000), 15000)
    url = "https://overpass-api.de/api/interpreter"
    
    if name_filter:
        query = f"""
        [out:json][timeout:15];
        (
          node["amenity"="pharmacy"]["name"~"{name_filter}",i](around:{radius_meters},{lat},{lng});
          way["amenity"="pharmacy"]["name"~"{name_filter}",i](around:{radius_meters},{lat},{lng});
        );
        out center;
        """
    else:
        query = f"""
        [out:json][timeout:15];
        (
          node["amenity"="pharmacy"](around:{radius_meters},{lat},{lng});
          way["amenity"="pharmacy"](around:{radius_meters},{lat},{lng});
        );
        out center;
        """
        
    headers = {"User-Agent": "MediScanApp/1.0 (contact: support@mediscan.com)"}
    try:
        response = requests.post(url, data={"data": query}, headers=headers, timeout=4)
        if response.status_code != 200:
            return
        data = response.json()
        elements = data.get("elements", [])
        
        all_meds = MedicineInfo.query.all()
        
        for elem in elements:
            tags = elem.get("tags", {})
            name = tags.get("name:en") or tags.get("name") or tags.get("brand") or tags.get("name:ar") or "Unnamed Pharmacy"
            name = transliterate_arabic_to_english(name)
            
            p_lat = elem.get("lat") or elem.get("center", {}).get("lat")
            p_lng = elem.get("lon") or elem.get("center", {}).get("lon")
            if not p_lat or not p_lng:
                continue
                
            try:
                p_lat_f = float(p_lat)
                p_lng_f = float(p_lng)
                if not (22.0 <= p_lat_f <= 32.0 and 24.0 <= p_lng_f <= 37.0):
                    continue
            except (ValueError, TypeError):
                continue
                
            # Check duplicate (within ~50m)
            existing = Pharmacy.query.filter(
                (Pharmacy.latitude.between(p_lat - 0.0005, p_lat + 0.0005)) &
                (Pharmacy.longitude.between(p_lng - 0.0005, p_lng + 0.0005))
            ).first()
            
            if existing:
                continue
                
            street = tags.get("addr:street")
            city = tags.get("addr:city") or tags.get("addr:suburb") or ""
            addr_parts = [street, city]
            address = ", ".join([p for p in addr_parts if p])
            if not address:
                address = f"Pharmacy near {p_lat:.4f}, {p_lng:.4f}"
            else:
                address = transliterate_arabic_to_english(address)
                
            phone = tags.get("phone") or tags.get("contact:phone") or f"+20 10 {random.randint(10000000, 99999999)}"
            
            new_p = Pharmacy(
                name=name,
                address=address,
                latitude=p_lat,
                longitude=p_lng,
                phone=phone,
                rating=round(random.uniform(4.0, 5.0), 1),
                delivery_available=random.choice([True, False]),
                is_active=True
            )
            db.session.add(new_p)
            db.session.flush()
            
            # seed inventory
            for med in all_meds:
                inv = MedicineInventory(
                    pharmacy_id=new_p.pharmacy_id,
                    medicine_name=med.medicine_name,
                    generic_name=med.generic_name,
                    batch_number=f"BAT-{random.randint(100, 999)}",
                    expiry_date=date.today() + timedelta(days=random.randint(180, 720)),
                    stock_quantity=random.randint(10, 50),
                    price=random.randint(10, 200),
                    is_prescription_required=random.choice([True, False])
                )
                db.session.add(inv)
                
        db.session.commit()
            
    except Exception as e:
        print(f"Error in fetch_and_register_osm_pharmacies: {e}")

def run_osm_fetch_bg(app, lat, lng, radius):
    with app.app_context():
        try:
            fetch_and_register_osm_pharmacies(lat, lng, radius)
        except Exception as e:
            print(f"Background OSM fetch failed: {e}")

# -------------------------------
# 2. NEARBY PHARMACIES (OSM INTEGRATED + GLOBAL)
# -------------------------------
@pharmacies_bp.route('/nearby', methods=['GET'])
@jwt_required()
def get_nearby_pharmacies():
    try:
        lat = float(request.args.get('lat', 0))
        lng = float(request.args.get('lng', 0))
        medicine = request.args.get('medicine', '')
        radius = float(request.args.get('radius', 10.0))
        # Limit radius to a reasonable maximum (10.0 km) to prevent showing distant Cairo pharmacies
        if radius > 10.0:
            radius = 10.0
        
        if lat == 0 or lng == 0:
            return jsonify({'success': False, 'message': 'Location is required'}), 400
        
        # Check Egypt geographic boundaries (22.0 <= lat <= 32.0 and 24.0 <= lng <= 37.0)
        if not (22.0 <= lat <= 32.0 and 24.0 <= lng <= 37.0):
            return jsonify({
                'success': True,
                'data': [],
                'message': 'Location is outside Egypt. Nearby pharmacies are restricted to Egypt only.'
            }), 200
        
        # Fetch from external source (OSM) in background thread so it doesn't block Flask request thread
        import threading
        from flask import current_app
        app_ctx = current_app._get_current_object()
        threading.Thread(target=run_osm_fetch_bg, args=(app_ctx, lat, lng, radius)).start()
        
        # Query database with group-by deduplication and direct distance calculation
        if medicine:
            # We want active pharmacies stocking this medicine
            query = text("""
                SELECT 
                    p.pharmacy_id,
                    p.name,
                    p.address,
                    p.phone,
                    p.rating,
                    p.delivery_available,
                    MIN(mi.price) as price,
                    SUM(mi.stock_quantity) as stock_quantity,
                    (6371 * ACOS(
                        LEAST(1.0, GREATEST(-1.0, 
                            COS(RADIANS(:lat)) * COS(RADIANS(p.latitude)) * COS(RADIANS(p.longitude) - RADIANS(:lng)) + 
                            SIN(RADIANS(:lat)) * SIN(RADIANS(p.latitude))
                        ))
                    )) AS distance_km,
                    p.latitude,
                    p.longitude
                FROM pharmacies p
                JOIN medicine_inventory mi ON p.pharmacy_id = mi.pharmacy_id
                WHERE p.is_active = 1
                  AND p.latitude BETWEEN 22.0 AND 32.0
                  AND p.longitude BETWEEN 24.0 AND 37.0
                  AND mi.medicine_name LIKE :med
                  AND mi.stock_quantity > 0
                  AND mi.expiry_date > CURDATE()
                GROUP BY p.pharmacy_id
                HAVING distance_km <= :radius
                ORDER BY distance_km
                LIMIT 25
            """)
            params = {'lat': lat, 'lng': lng, 'med': f'%{medicine}%', 'radius': radius}
        else:
            # We want all nearby active pharmacies
            query = text("""
                SELECT 
                    p.pharmacy_id,
                    p.name,
                    p.address,
                    p.phone,
                    p.rating,
                    p.delivery_available,
                    0.0 as price,
                    0 as stock_quantity,
                    (6371 * ACOS(
                        LEAST(1.0, GREATEST(-1.0, 
                            COS(RADIANS(:lat)) * COS(RADIANS(p.latitude)) * COS(RADIANS(p.longitude) - RADIANS(:lng)) + 
                            SIN(RADIANS(:lat)) * SIN(RADIANS(p.latitude))
                        ))
                    )) AS distance_km,
                    p.latitude,
                    p.longitude
                FROM pharmacies p
                WHERE p.is_active = 1
                  AND p.latitude BETWEEN 22.0 AND 32.0
                  AND p.longitude BETWEEN 24.0 AND 37.0
                GROUP BY p.pharmacy_id
                HAVING distance_km <= :radius
                ORDER BY distance_km
                LIMIT 25
            """)
            params = {'lat': lat, 'lng': lng, 'radius': radius}

        result = db.session.execute(query, params).fetchall()
        db.session.remove()
        
        results = []
        for row in result:
            p_id = row[0]
            p_name = row[1]
            p_address = row[2]
            p_phone = row[3]
            p_rating = float(row[4]) if row[4] else 0.0
            p_delivery = bool(row[5])
            p_price = float(row[6]) if row[6] else 0.0
            p_stock = row[7]
            p_distance = round(float(row[8]), 2) if row[8] else 0.0
            p_lat = float(row[9]) if row[9] else 0.0
            p_lng = float(row[10]) if row[10] else 0.0
            
            results.append({
                'id': p_id,
                'name': transliterate_arabic_to_english(p_name),
                'address': transliterate_arabic_to_english(p_address),
                'phone': p_phone,
                'rating': p_rating,
                'delivery_available': p_delivery,
                'price': p_price,
                'stock_quantity': p_stock,
                'distance': p_distance,
                'latitude': p_lat,
                'longitude': p_lng,
            })
        
        return jsonify({
            'success': True,
            'data': results
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


# -------------------------------
# 2.5 FALLBACK PHARMACIES
# -------------------------------
@pharmacies_bp.route('/fallback', methods=['GET'])
@jwt_required()
def get_fallback_pharmacies():
    try:
        # Query up to 20 active pharmacies inside Egypt, sorted by rating
        pharmacies = Pharmacy.query.filter(
            Pharmacy.is_active == 1,
            Pharmacy.latitude.between(22.0, 32.0),
            Pharmacy.longitude.between(24.0, 37.0)
        ).order_by(Pharmacy.rating.desc()).limit(20).all()
        
        results = []
        for p in pharmacies:
            results.append({
                'id': p.pharmacy_id,
                'name': transliterate_arabic_to_english(p.name),
                'address': transliterate_arabic_to_english(p.address),
                'phone': p.phone,
                'rating': float(p.rating) if p.rating else 0.0,
                'delivery_available': p.delivery_available,
                'price': 0.0,
                'stock_quantity': 0,
                'distance': None,  # Distance is null when GPS is unavailable
                'latitude': float(p.latitude) if p.latitude else 0.0,
                'longitude': float(p.longitude) if p.longitude else 0.0,
            })
            
        return jsonify({
            'success': True,
            'data': results
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


# -------------------------------
# 3. SEARCH PHARMACIES (GLOBAL)
# -------------------------------
def calculate_haversine(lat1, lon1, lat2, lon2):
    import math
    R = 6371.0  # Earth's radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.asin(min(1.0, math.sqrt(a)))
    return R * c

@pharmacies_bp.route('/search', methods=['GET'])
@jwt_required()
def search_pharmacies():
    try:
        name = request.args.get('name', '')
        lat_str = request.args.get('lat')
        lng_str = request.args.get('lng')
        
        if not name:
            return jsonify({'success': False, 'message': 'Pharmacy name required'}), 400
        
        user_lat = None
        user_lng = None
        if lat_str and lng_str:
            try:
                temp_lat = float(lat_str)
                temp_lng = float(lng_str)
                # Ensure the user coordinates are inside Egypt before using them for distance/sorting
                if 22.0 <= temp_lat <= 32.0 and 24.0 <= temp_lng <= 37.0:
                    user_lat = temp_lat
                    user_lng = temp_lng
            except ValueError:
                pass

        # OpenStreetMap integration disabled to prevent network errors and timeouts
        # if user_lat is not None and user_lng is not None and user_lat != 0 and user_lng != 0:
        #     fetch_and_register_osm_pharmacies(user_lat, user_lng, 10.0, name_filter=name)

        # Restrict pharmacy search results strictly to Egypt boundaries
        pharmacies = Pharmacy.query.filter(
            Pharmacy.is_active == 1,
            Pharmacy.name.ilike(f'%{name}%'),
            Pharmacy.latitude.between(22.0, 32.0),
            Pharmacy.longitude.between(24.0, 37.0)
        ).all()
        result = []
        for p in pharmacies:
            p_lat = float(p.latitude) if p.latitude else 0
            p_lng = float(p.longitude) if p.longitude else 0
            p_dict = p.to_dict()
            p_dict['name'] = transliterate_arabic_to_english(p_dict['name'])
            p_dict['address'] = transliterate_arabic_to_english(p_dict['address'])
            if user_lat is not None and user_lng is not None:
                dist = calculate_haversine(user_lat, user_lng, p_lat, p_lng)
                # Limit results to 10 km radius from user's current GPS location
                if dist > 10.0:
                    continue
                p_dict['distance'] = round(dist, 2)
            else:
                p_dict['distance'] = None
            result.append(p_dict)
        
        if user_lat is not None and user_lng is not None:
            result.sort(key=lambda x: x.get('distance') if x.get('distance') is not None else 999999.0)
            
        # Never display all matching pharmacies at once (cap to 20 results)
        result = result[:20]
            
        return jsonify({
            'success': True,
            'data': result
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


# -------------------------------
# 4. PHARMACY OWNER ROUTES
# -------------------------------
@pharmacies_bp.route('/my-pharmacy', methods=['GET'])
@jwt_required()
def get_my_pharmacy():
    try:
        user_id = get_jwt_identity()
        pharmacy = Pharmacy.query.filter_by(owner_id=user_id).first()
        if not pharmacy:
            return jsonify({'success': False, 'message': 'You do not own a pharmacy'}), 404
        return jsonify({'success': True, 'data': pharmacy.to_dict()}), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@pharmacies_bp.route('/my-pharmacy', methods=['PUT'])
@jwt_required()
def update_my_pharmacy():
    try:
        user_id = get_jwt_identity()
        pharmacy = Pharmacy.query.filter_by(owner_id=user_id).first()
        if not pharmacy:
            return jsonify({'success': False, 'message': 'You do not own a pharmacy'}), 404
            
        data = request.get_json()
        if 'name' in data: pharmacy.name = data['name']
        if 'phone' in data: pharmacy.phone = data['phone']
        if 'delivery_available' in data: pharmacy.delivery_available = data['delivery_available']
        
        db.session.commit()
        return jsonify({'success': True, 'message': 'Pharmacy updated', 'data': pharmacy.to_dict()}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@pharmacies_bp.route('/my-pharmacy/inventory', methods=['GET'])
@jwt_required()
def get_my_inventory():
    try:
        user_id = get_jwt_identity()
        pharmacy = Pharmacy.query.filter_by(owner_id=user_id).first()
        if not pharmacy:
            return jsonify({'success': False, 'message': 'You do not own a pharmacy'}), 404
            
        inventory = MedicineInventory.query.filter_by(pharmacy_id=pharmacy.pharmacy_id).all()
        return jsonify({
            'success': True,
            'data': [i.to_dict() for i in inventory]
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@pharmacies_bp.route('/my-pharmacy/inventory', methods=['POST'])
@jwt_required()
def update_my_inventory():
    try:
        user_id = get_jwt_identity()
        pharmacy = Pharmacy.query.filter_by(owner_id=user_id).first()
        if not pharmacy:
            return jsonify({'success': False, 'message': 'You do not own a pharmacy'}), 404
            
        data = request.get_json()
        inventory_id = data.get('id') or data.get('inventory_id')
        medicine_name = data.get('medicine_name')
        stock = data.get('stock_quantity')
        price = data.get('price')
        generic_name = data.get('generic_name')
        batch_number = data.get('batch_number')
        expiry_date_str = data.get('expiry_date')
        is_prescription_required = data.get('is_prescription_required')
        
        if not medicine_name:
            return jsonify({'success': False, 'message': 'Medicine name is required'}), 400
            
        inv = None
        if inventory_id:
            inv = MedicineInventory.query.filter_by(pharmacy_id=pharmacy.pharmacy_id, inventory_id=inventory_id).first()
        
        if not inv:
            inv = MedicineInventory.query.filter_by(pharmacy_id=pharmacy.pharmacy_id, medicine_name=medicine_name).first()
        
        parsed_expiry = None
        if expiry_date_str:
            from datetime import datetime
            for fmt in ['%Y-%m-%d', '%d/%m/%Y', '%d-%m-%Y']:
                try:
                    parsed_expiry = datetime.strptime(expiry_date_str, fmt).date()
                    break
                except ValueError:
                    continue
        
        if not parsed_expiry:
            from datetime import datetime, timedelta
            parsed_expiry = (datetime.utcnow() + timedelta(days=365)).date()
            
        # Check if the medicine is being restocked (went from out-of-stock to available)
        is_new_or_restocked = False
        if not inv:
            if stock is not None and int(stock) > 0:
                is_new_or_restocked = True
        else:
            if stock is not None and inv.stock_quantity == 0 and int(stock) > 0:
                is_new_or_restocked = True

        if not inv:
            inv = MedicineInventory(
                pharmacy_id=pharmacy.pharmacy_id,
                medicine_name=medicine_name,
                generic_name=generic_name if generic_name else '',
                batch_number=batch_number if batch_number else 'BATCH001',
                expiry_date=parsed_expiry,
                stock_quantity=int(stock) if stock is not None else 0,
                price=float(price) if price is not None else 0.0,
                is_prescription_required=bool(is_prescription_required) if is_prescription_required is not None else True
            )
            db.session.add(inv)
        else:
            if medicine_name is not None: inv.medicine_name = medicine_name
            if stock is not None: inv.stock_quantity = int(stock)
            if price is not None: inv.price = float(price)
            if generic_name is not None: inv.generic_name = generic_name
            if batch_number is not None: inv.batch_number = batch_number
            if expiry_date_str is not None: inv.expiry_date = parsed_expiry
            if is_prescription_required is not None: inv.is_prescription_required = bool(is_prescription_required)
            
        db.session.commit()

        # If restocked, notify all customers that this medicine is back in stock!
        if is_new_or_restocked:
            try:
                from models.notification import Notification
                from models.user import User
                customers = User.query.filter_by(role='patient').all()
                for customer in customers:
                    notif = Notification(
                        user_id=customer.user_id,
                        type='stock_update',
                        message=f"Good news! '{medicine_name}' is back in stock at '{pharmacy.name}'!"
                    )
                    db.session.add(notif)
                db.session.commit()
            except Exception as notif_err:
                print(f"Error creating restock notification: {notif_err}")

        return jsonify({'success': True, 'message': 'Inventory updated', 'data': inv.to_dict()}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 4.6. DELETE INVENTORY ITEM
# -------------------------------
@pharmacies_bp.route('/my-pharmacy/inventory/<string:inventory_id>', methods=['DELETE'])
@jwt_required()
def delete_inventory_item(inventory_id):
    try:
        user_id = get_jwt_identity()
        pharmacy = Pharmacy.query.filter_by(owner_id=user_id).first()
        if not pharmacy:
            return jsonify({'success': False, 'message': 'You do not own a pharmacy'}), 404
            
        inv = MedicineInventory.query.filter_by(pharmacy_id=pharmacy.pharmacy_id, inventory_id=inventory_id).first()
        if not inv:
            return jsonify({'success': False, 'message': 'Item not found in inventory'}), 404
            
        db.session.delete(inv)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Medicine removed from inventory'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 5. TEST ROUTE
# -------------------------------
@pharmacies_bp.route('/test', methods=['GET'])
def test():
    return jsonify({'success': True, 'message': 'Pharmacies routes working'}), 200