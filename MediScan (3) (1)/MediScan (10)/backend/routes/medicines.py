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
        from models.medicine import MedicineInfo, MedicineInventory

        resolved = []
        total_price = 0.0

        for raw_name in names:
            name_clean = raw_name.strip()
            qty = 1
            # Extract quantity if formatted as "Medicine Name x3"
            match = re.search(r'\s+x(\d+)$', name_clean, re.IGNORECASE)
            if match:
                qty = int(match.group(1))
                name_clean = name_clean[:match.start()].strip()

            # 1. Exact/Direct Match in Inventory first (extremely fast)
            inv_query = db.session.query(
                MedicineInventory.medicine_name,
                MedicineInventory.stock_quantity,
                MedicineInventory.price
            )
            if pharmacy_id:
                inv_query = inv_query.filter(
                    MedicineInventory.pharmacy_id == pharmacy_id,
                    MedicineInventory.medicine_name.ilike(name_clean)
                )
            else:
                inv_query = inv_query.filter(
                    MedicineInventory.medicine_name.ilike(name_clean)
                )

            inv_matches = inv_query.all()
            
            if inv_matches:
                # Direct match in inventory exists!
                matched_inventory_name = inv_matches[0][0]
                total_stock = sum(int(r[1]) if r[1] is not None else 0 for r in inv_matches)
                if pharmacy_id:
                    avg_price = float(inv_matches[0][2]) if inv_matches[0][2] is not None else 0.0
                else:
                    valid_prices = [float(r[2]) for r in inv_matches if r[2] is not None]
                    avg_price = sum(valid_prices) / len(valid_prices) if valid_prices else 0.0

                info_item = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(matched_inventory_name)).first()
                display_name = info_item.medicine_name if info_item else matched_inventory_name
                medicine_image = info_item.medicine_image if info_item else None
                
                # Format image URL
                if medicine_image and medicine_image.startswith('/'):
                    try:
                        medicine_image = request.host_url.rstrip('/') + medicine_image
                    except Exception:
                        pass

                available = total_stock > 0
                is_pending = info_item.status == 'Pending Verification' if info_item else False

                resolved.append({
                    'original_name': raw_name,
                    'name': display_name,
                    'medicine_image': medicine_image or '',
                    'quantity': qty,
                    'price': avg_price,
                    'matched': True,
                    'available': available,
                    'pending_verification': is_pending,
                    'stock': total_stock
                })
                if available:
                    total_price += avg_price * qty
                continue

            # 2. Exact/Direct Match in Catalog (MedicineInfo)
            info_item = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(name_clean)).first()
            if info_item:
                medicine_image = info_item.medicine_image
                if medicine_image and medicine_image.startswith('/'):
                    try:
                        medicine_image = request.host_url.rstrip('/') + medicine_image
                    except Exception:
                        pass
                resolved.append({
                    'original_name': raw_name,
                    'name': info_item.medicine_name,
                    'medicine_image': medicine_image or '',
                    'quantity': qty,
                    'price': 0.0,
                    'matched': True,
                    'available': False,
                    'pending_verification': info_item.status == 'Pending Verification',
                    'stock': 0
                })
                continue

            # 3. If direct match not found, do highly restricted fuzzy match (cutoff=0.85) to avoid duplicate entries
            first_char = name_clean[0] if name_clean else ''
            
            if first_char:
                if pharmacy_id:
                    fuzzy_candidates = db.session.query(
                        MedicineInventory.medicine_name,
                        MedicineInventory.stock_quantity,
                        MedicineInventory.price
                    ).filter(
                        MedicineInventory.pharmacy_id == pharmacy_id,
                        MedicineInventory.medicine_name.like(f"{first_char}%")
                    ).all()
                else:
                    fuzzy_candidates = db.session.query(
                        MedicineInventory.medicine_name,
                        db.func.sum(MedicineInventory.stock_quantity).label('total_stock'),
                        db.func.avg(MedicineInventory.price).label('avg_price')
                    ).filter(
                        MedicineInventory.medicine_name.like(f"{first_char}%")
                    ).group_by(MedicineInventory.medicine_name).all()
            else:
                fuzzy_candidates = []

            import difflib
            best_fuzzy_match = None
            best_ratio = 0.0
            best_fuzzy_info = None

            suffixes_pat = r'\b(?:\d+\.?\d*\s*)?(mg|g|ml|cream|gel|injection|inhaler|tablets|tablet|capsules|capsule)\b'
            clean_scanned = re.sub(suffixes_pat, '', name_clean.lower()).strip()

            for c in fuzzy_candidates:
                c_name = c[0]
                c_clean = re.sub(suffixes_pat, '', c_name.lower()).strip()
                ratio = difflib.SequenceMatcher(None, clean_scanned, c_clean).ratio()
                if ratio > best_ratio:
                    best_ratio = ratio
                    best_fuzzy_match = c_name
                    best_fuzzy_info = c

            if best_ratio >= 0.85 and best_fuzzy_match:
                # Highly confident fuzzy match exists in database! Reuse it to prevent duplicates
                total_stock = int(best_fuzzy_info[1]) if best_fuzzy_info[1] is not None else 0
                avg_price = float(best_fuzzy_info[2]) if best_fuzzy_info[2] is not None else 0.0

                info_item = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(best_fuzzy_match)).first()
                display_name = info_item.medicine_name if info_item else best_fuzzy_match
                medicine_image = info_item.medicine_image if info_item else None

                if medicine_image and medicine_image.startswith('/'):
                    try:
                        medicine_image = request.host_url.rstrip('/') + medicine_image
                    except Exception:
                        pass

                available = total_stock > 0
                is_pending = info_item.status == 'Pending Verification' if info_item else False

                resolved.append({
                    'original_name': raw_name,
                    'name': display_name,
                    'medicine_image': medicine_image or '',
                    'quantity': qty,
                    'price': avg_price,
                    'matched': True,
                    'available': available,
                    'pending_verification': is_pending,
                    'stock': total_stock
                })
                if available:
                    total_price += avg_price * qty
                continue

            # 4. Absolutely not found anywhere -> Self-learning auto-creation!
            # A. Create in MedicineInfo catalog
            import os
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
                print(f"Auto-created MedicineInfo catalog record: {name_clean} with image {resolved_image}")
            except Exception as ex:
                db.session.rollback()
                print(f"Error auto-creating catalog medicine: {ex}")
                info_item = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(name_clean)).first()
                if info_item:
                    resolved_image = info_item.medicine_image or resolved_image

            # B. Create in MedicineInventory
            try:
                from models.pharmacy import Pharmacy
                pharm = Pharmacy.query.first()
                default_pharm_id = pharm.pharmacy_id if pharm else '1'
                
                import datetime
                inv_item = MedicineInventory(
                    pharmacy_id=default_pharm_id,
                    medicine_name=name_clean,
                    generic_name='OCR Extracted',
                    expiry_date=datetime.date.today() + datetime.timedelta(days=365),
                    stock_quantity=0,
                    price=0.0,
                    is_prescription_required=True
                )
                db.session.add(inv_item)
                db.session.commit()
                print(f"Auto-created MedicineInventory record: {name_clean} (Pharmacy ID: {default_pharm_id})")
            except Exception as ex:
                db.session.rollback()
                print(f"Error auto-creating inventory medicine: {ex}")
                inv_item = MedicineInventory.query.filter(MedicineInventory.medicine_name.ilike(name_clean)).first()

            # Now resolve and return the newly created records immediately!
            img_url = resolved_image
            if img_url and img_url.startswith('/'):
                try:
                    img_url = request.host_url.rstrip('/') + img_url
                except Exception:
                    pass

            resolved.append({
                'original_name': raw_name,
                'name': name_clean,
                'medicine_image': img_url or '',
                'quantity': qty,
                'price': 0.0,
                'matched': True,
                'available': False,
                'pending_verification': True,
                'stock': 0
            })

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