from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from extensions import db
from sqlalchemy import text
from models.medicine import MedicineInfo, MedicineInventory, MedicineAlternative, MedicineRecall

medicines_bp = Blueprint('medicines', __name__)

def normalize_name(name):
    # Returns (canonical_name, dosage)
    import re
    name_clean = name.strip().lower()
    
    # 1. Groupings of known medicines with OCR spelling mistakes
    if any(x in name_clean for x in ['venusen', 'venosen', 'veneson', 'venuson', 'veneseni']):
        return "Venusen Compression Stocking", "Class II"
        
    if any(x in name_clean for x in ['conventin', 'conventu', 'convenntu', 'conventus', 'convenia']):
        return "Conventin", "100mg"
        
    if any(x in name_clean for x in ['recoxibright', 'recoribright', 'pecoribright']):
        return "Recoxibright", "90mg"
        
    if any(x in name_clean for x in ['sulfax', 'sulfox', 'sulfiox', 'sulfoa', 'sulfora']):
        return "Sulfax Gel", "Gel"
        
    if "panadol extra" in name_clean:
        return "Panadol Extra", "500mg"
    if "panadol cold" in name_clean:
        return "Panadol Cold & Flu", "Cold & Flu"
    if "panadol" in name_clean:
        return "Panadol", "500mg"
    if "paracetamol" in name_clean:
        return "Paracetamol", "500mg"
        
    if "cataflam" in name_clean:
        return "Cataflam", "50mg"
    if "catafast" in name_clean:
        return "Catafast", "50mg"
        
    if "otrivin" in name_clean:
        return "Otrivin Nasal Spray", "Nasal Spray"
        
    if "augmentin" in name_clean:
        return "Augmentin", "1g"
        
    if "nexium" in name_clean:
        return "Nexium", "40mg"
        
    if "ventolin" in name_clean:
        return "Ventolin", "Inhaler"
        
    if "duphaston" in name_clean:
        return "Duphaston", "10mg"
        
    if "thiopro" in name_clean:
        return "Thiopro", "100mg"
        
    if "puravil" in name_clean:
        return "Puravil", "100mg"
        
    # 2. General parsing
    dosage_match = re.search(r'(\d+\s*(?:mg|g|mcg|ml|gm|%))', name, re.IGNORECASE)
    dosage = dosage_match.group(1) if dosage_match else "None"
    
    base_name = name
    if dosage_match:
        base_name = name.replace(dosage_match.group(1), "")
    
    base_name = re.sub(r'\s+', ' ', base_name).strip().strip(',').strip('-').strip()
    base_name = base_name.title()
    
    return base_name, dosage

# -------------------------------
# 1. SEARCH MEDICINES
# -------------------------------
@medicines_bp.route('/search', methods=['GET'])
@jwt_required()
def search_medicines():
    try:
        q = request.args.get('q', request.args.get('name', ''))
        if not q:
            return jsonify({'success': False, 'message': 'Search query is required'}), 400

        results = db.session.query(
            MedicineInfo,
            db.func.sum(MedicineInventory.stock_quantity).label('total_stock'),
            db.func.avg(MedicineInventory.price).label('avg_price')
        ).outerjoin(
            MedicineInventory, 
            MedicineInfo.medicine_name == MedicineInventory.medicine_name
        ).filter(
            (MedicineInfo.medicine_name.ilike(f'%{q}%')) | 
            (MedicineInfo.generic_name.ilike(f'%{q}%'))
        ).group_by(MedicineInfo.id).all()

        deduplicated = {}
        for m_info, total_stock, avg_price in results:
            name = m_info.medicine_name
            canonical_name, dosage = normalize_name(name)
            key = (canonical_name.lower(), dosage.lower())
            
            m_dict = m_info.to_dict()
            m_dict['stock'] = int(total_stock) if total_stock is not None else 0
            m_dict['price'] = float(avg_price) if avg_price is not None else 0.0
            
            # Format display name nicely
            display_name = canonical_name
            if dosage != "None" and dosage != "Gel" and dosage.lower() not in canonical_name.lower():
                display_name = f"{canonical_name} {dosage}"
            m_dict['medicine_name'] = display_name
            
            # Rate candidates based on verification status and image quality
            is_verified = m_dict.get('status') == 'Verified'
            has_real_image = m_dict.get('medicine_image') and 'generic_pill.png' not in m_dict.get('medicine_image', '')
            
            score = 0
            if is_verified:
                score += 10
            if has_real_image:
                score += 5
            if m_info.medicine_name.lower() == canonical_name.lower():
                score += 2
                
            if key not in deduplicated:
                deduplicated[key] = (score, m_dict)
            else:
                existing_score, existing_dict = deduplicated[key]
                if score > existing_score:
                    # Keep higher scored record, but merge inventory stock and price
                    m_dict['stock'] = max(m_dict['stock'], existing_dict['stock'])
                    if m_dict['price'] == 0.0 and existing_dict['price'] > 0.0:
                        m_dict['price'] = existing_dict['price']
                    deduplicated[key] = (score, m_dict)
                else:
                    # Accumulate stock and price in existing record
                    existing_dict['stock'] = max(existing_dict['stock'], m_dict['stock'])
                    if existing_dict['price'] == 0.0 and m_dict['price'] > 0.0:
                        existing_dict['price'] = m_dict['price']
                        
        data = [item for score, item in deduplicated.values()]
        data.sort(key=lambda x: x['medicine_name'])

        # Optional page-based pagination
        page = request.args.get('page')
        limit = request.args.get('limit')
        if page and limit:
            try:
                page = int(page)
                limit = int(limit)
                start_idx = (page - 1) * limit
                end_idx = start_idx + limit
                data = data[start_idx:end_idx]
            except ValueError:
                pass

        return jsonify({
            'success': True,
            'data': data
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 2. GET MEDICINE INFO (STORED PROCEDURE)
# -------------------------------
@medicines_bp.route('/info', methods=['GET'])
@jwt_required()
def get_medicine_info():
    try:
        name = request.args.get('name', '')
        if not name:
            return jsonify({'success': False, 'message': 'Medicine name is required'}), 400
            
        # Call stored procedure
        result = db.session.execute(
            text("CALL GetMedicineInfo(:name)"),
            {'name': name}
        ).fetchone()
        db.session.remove()
        
        if result:
            return jsonify({
                'success': True,
                'data': {
                    'medicine_name': result[0],
                    'generic_name': result[1],
                    'uses': result[2],
                    'dosage_adult': result[3],
                    'side_effects': result[4],
                    'interactions': result[5],
                    'contraindications': result[6]
                }
            }), 200
        else:
            return jsonify({'success': False, 'message': 'Medicine not found'}), 404
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 3. GET ALTERNATIVES
# -------------------------------
@medicines_bp.route('/alternatives', methods=['GET'])
@jwt_required()
def get_alternatives():
    try:
        name = request.args.get('name', '')
        if not name:
            return jsonify({'success': False, 'message': 'Medicine name is required'}), 400
            
        alternatives = MedicineAlternative.query.filter(MedicineAlternative.medicine_name.ilike(f'%{name}%')).all()
        return jsonify({
            'success': True,
            'data': [a.to_dict() for a in alternatives]
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 4. RESOLVE MEDICINE PRICES & AVAILABILITY
# -------------------------------
@medicines_bp.route('/resolve_prices', methods=['POST'])
@jwt_required()
def resolve_prices():
    try:
        data = request.get_json()
        names = data.get('names', [])
        pharmacy_id = data.get('pharmacy_id')
        
        if not names or not isinstance(names, list):
            return jsonify({'success': False, 'message': 'names list is required'}), 400
            
        import re
        import os
        import datetime
        from models.medicine import MedicineInfo, MedicineInventory
        from routes.prescriptions import calculate_similarity

        resolved = []
        total_price = 0.0

        # Helper function to get global average price > 0 for a medicine
        def get_global_avg_price(med_name):
            # direct match in other pharmacies
            g_prices = db.session.query(MedicineInventory.price).filter(
                MedicineInventory.medicine_name.ilike(med_name),
                MedicineInventory.price > 0
            ).all()
            if g_prices:
                return sum(float(p[0]) for p in g_prices) / len(g_prices)
            
            # fuzzy match in other pharmacies
            all_prices = db.session.query(
                MedicineInventory.medicine_name,
                db.func.avg(MedicineInventory.price)
            ).filter(
                MedicineInventory.price > 0
            ).group_by(MedicineInventory.medicine_name).all()
            
            best_ratio = 0.0
            best_price = 0.0
            for c in all_prices:
                ratio = calculate_similarity(med_name, c[0])
                if ratio > best_ratio:
                    best_ratio = ratio
                    best_price = float(c[1])
            if best_ratio >= 0.70:
                return best_price
            return 30.0  # default price fallback

        for raw_name in names:
            name_clean = raw_name.strip()
            qty = 1
            # Extract quantity if formatted as "Medicine Name x3"
            match = re.search(r'\s+x(\d+)$', name_clean, re.IGNORECASE)
            if match:
                qty = int(match.group(1))
                name_clean = name_clean[:match.start()].strip()

            matched_name = None
            avg_price = 0.0
            total_stock = 0
            available = False
            matched = False
            is_pending = False
            medicine_image = ''

            # 1. First, check if pharmacy_id is provided, and search there specifically
            if pharmacy_id:
                # 1a. Exact match in specific pharmacy inventory
                inv_matches = MedicineInventory.query.filter(
                    MedicineInventory.pharmacy_id == pharmacy_id,
                    MedicineInventory.medicine_name.ilike(name_clean)
                ).all()
                
                # 1b. Fuzzy match in specific pharmacy inventory
                if not inv_matches:
                    all_pharm_inv = MedicineInventory.query.filter(
                        MedicineInventory.pharmacy_id == pharmacy_id
                    ).all()
                    best_ratio = 0.0
                    pharmacy_match = None
                    for item in all_pharm_inv:
                        ratio = calculate_similarity(name_clean, item.medicine_name)
                        if ratio > best_ratio:
                            best_ratio = ratio
                            pharmacy_match = item
                    if best_ratio >= 0.70 and pharmacy_match:
                        inv_matches = [pharmacy_match]
                
                if inv_matches:
                    matched = True
                    matched_name = inv_matches[0].medicine_name
                    total_stock = sum(int(r.stock_quantity) if r.stock_quantity is not None else 0 for r in inv_matches)
                    
                    # Look for prices > 0 in matches
                    valid_prices = [float(r.price) for r in inv_matches if r.price is not None and r.price > 0]
                    if valid_prices:
                        avg_price = sum(valid_prices) / len(valid_prices)
                        available = total_stock > 0
                    else:
                        # Price in this pharmacy is 0/null, so fallback to global average
                        avg_price = get_global_avg_price(matched_name)
                        available = False
                        total_stock = 0
            else:
                # 2. No specific pharmacy_id, check globally
                # 2a. Exact match in all inventories
                inv_matches = MedicineInventory.query.filter(
                    MedicineInventory.medicine_name.ilike(name_clean)
                ).all()
                
                # 2b. Fuzzy match in all inventories
                if not inv_matches:
                    all_candidates = db.session.query(
                        MedicineInventory.medicine_name,
                        db.func.sum(MedicineInventory.stock_quantity).label('total_stock'),
                        db.func.avg(MedicineInventory.price).label('avg_price')
                    ).group_by(MedicineInventory.medicine_name).all()
                    best_ratio = 0.0
                    best_c = None
                    for c in all_candidates:
                        ratio = calculate_similarity(name_clean, c[0])
                        if ratio > best_ratio:
                            best_ratio = ratio
                            best_c = c
                    if best_ratio >= 0.70 and best_c:
                        matched = True
                        matched_name = best_c[0]
                        total_stock = int(best_c[1]) if best_c[1] is not None else 0
                        avg_price = float(best_c[2]) if best_c[2] is not None and best_c[2] > 0 else get_global_avg_price(matched_name)
                        available = total_stock > 0
                else:
                    matched = True
                    matched_name = inv_matches[0].medicine_name
                    total_stock = sum(int(r.stock_quantity) if r.stock_quantity is not None else 0 for r in inv_matches)
                    valid_prices = [float(r.price) for r in inv_matches if r.price is not None and r.price > 0]
                    if valid_prices:
                        avg_price = sum(valid_prices) / len(valid_prices)
                    else:
                        avg_price = get_global_avg_price(matched_name)
                    available = total_stock > 0

            # 3. If matched, get catalog info (image and pending status)
            if matched and matched_name:
                info_item = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(matched_name)).first()
                display_name = info_item.medicine_name if info_item else matched_name
                is_pending = info_item.status == 'Pending Verification' if info_item else False
                medicine_image = info_item.medicine_image if info_item else ''
            else:
                # 4. Not matched in inventory, check catalog directly
                info_item = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(name_clean)).first()
                if info_item:
                    matched = True
                    display_name = info_item.medicine_name
                    is_pending = info_item.status == 'Pending Verification'
                    medicine_image = info_item.medicine_image or ''
                    avg_price = get_global_avg_price(display_name)
                    total_stock = 0
                    available = False
                else:
                    # 5. Absolutely not found anywhere -> Self-learning auto-creation!
                    from utils.images import resolve_medicine_image_path
                    from flask import current_app
                    
                    cfg_uploads = current_app.config.get('UPLOAD_FOLDER', 'uploads')
                    if os.path.isabs(cfg_uploads):
                        uploads_dir = cfg_uploads
                    else:
                        app_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                        uploads_dir = os.path.join(app_dir, cfg_uploads)
                        
                    resolved_image = resolve_medicine_image_path(name_clean, uploads_dir)
                    
                    try:
                        info_item = MedicineInfo(
                            medicine_name=name_clean,
                            generic_name='OCR Extracted',
                            status='Pending Verification',
                            medicine_image=resolved_image
                        )
                        db.session.add(info_item)
                        db.session.commit()
                    except Exception as ex:
                        db.session.rollback()
                        info_item = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(name_clean)).first()
                        if info_item:
                            resolved_image = info_item.medicine_image or resolved_image
                    
                    display_name = name_clean
                    is_pending = True
                    medicine_image = resolved_image
                    avg_price = 30.0  # default price for new medicines
                    total_stock = 0
                    available = False
                    matched = True
                    
                    # Also create in inventory for the first pharmacy so it exists with a valid price
                    try:
                        from models.pharmacy import Pharmacy as PharmacyModel
                        pharm = PharmacyModel.query.first()
                        default_pharm_id = pharm.pharmacy_id if pharm else '1'
                        
                        inv_item = MedicineInventory(
                            pharmacy_id=default_pharm_id,
                            medicine_name=name_clean,
                            generic_name='OCR Extracted',
                            expiry_date=datetime.date.today() + datetime.timedelta(days=365),
                            stock_quantity=0,
                            price=30.0,  # Default price
                            is_prescription_required=True
                        )
                        db.session.add(inv_item)
                        db.session.commit()
                    except Exception as ex:
                        db.session.rollback()

            # Format image URL
            if medicine_image and medicine_image.startswith('/'):
                try:
                    medicine_image = request.host_url.rstrip('/') + medicine_image
                except Exception:
                    pass

            resolved.append({
                'original_name': raw_name,
                'name': display_name,
                'medicine_image': medicine_image or '',
                'quantity': qty,
                'price': avg_price,
                'matched': matched,
                'available': available,
                'pending_verification': is_pending,
                'stock': total_stock
            })
            total_price += avg_price * qty

        return jsonify({
            'success': True,
            'data': resolved,
            'total_price': total_price
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 5. TEST ROUTE
# -------------------------------
@medicines_bp.route('/test', methods=['GET'])
def test():
    return jsonify({'success': True, 'message': 'Medicines routes working'}), 200