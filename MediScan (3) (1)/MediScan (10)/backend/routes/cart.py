from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from extensions import db
from models.cart import Cart, CartItem
from models.order import DeliveryOrder
from models.pharmacy import Pharmacy
from models.medicine import MedicineInfo, MedicineInventory
from sqlalchemy import text
import uuid

cart_bp = Blueprint('cart', __name__)

@cart_bp.route('', methods=['GET'])
@jwt_required()
def get_cart():
    try:
        user_id = get_jwt_identity()
        cart = Cart.query.filter_by(user_id=user_id).first()
        
        if not cart:
            return jsonify({'success': True, 'data': {'items': [], 'total_price': 0}}), 200
            
        if cart.pharmacy_id:
            query = text("""
                SELECT ci.cart_item_id, ci.quantity, ci.medicine_id,
                       m.medicine_name, m.generic_name, m.medicine_image AS image_url,
                       COALESCE(i.stock_quantity, 0) AS total_stock,
                       COALESCE(i.price, 0) AS avg_price
                FROM cart_items ci
                JOIN medicine_info m ON ci.medicine_id = m.id
                LEFT JOIN medicine_inventory i ON m.medicine_name = i.medicine_name AND i.pharmacy_id = :pharmacy_id
                WHERE ci.cart_id = :cart_id
            """)
            params = {'cart_id': cart.cart_id, 'pharmacy_id': cart.pharmacy_id}
        else:
            query = text("""
                SELECT ci.cart_item_id, ci.quantity, ci.medicine_id,
                       m.medicine_name, m.generic_name, m.medicine_image AS image_url,
                       COALESCE(SUM(i.stock_quantity), 0) AS total_stock,
                       COALESCE(AVG(i.price), 0) AS avg_price
                FROM cart_items ci
                JOIN medicine_info m ON ci.medicine_id = m.id
                LEFT JOIN medicine_inventory i ON m.medicine_name = i.medicine_name
                WHERE ci.cart_id = :cart_id
                GROUP BY ci.cart_item_id, ci.quantity, ci.medicine_id, m.medicine_name, m.generic_name, m.medicine_image
            """)
            params = {'cart_id': cart.cart_id}
        
        results = db.session.execute(query, params).fetchall()
        
        items = []
        total_cart_price = 0
        for r in results:
            item_price = float(r[7]) * r[1]
            total_cart_price += item_price
            items.append({
                'cart_item_id': r[0],
                'quantity': r[1],
                'medicine_id': r[2],
                'medicine': {
                    'id': r[2],
                    'medicine_name': r[3],
                    'generic_name': r[4],
                    'image_url': r[5] if r[5] else '',
                    'stock': int(r[6]),
                    'price': float(r[7]),
                    'brand_name': '',
                    'type': '',
                    'dosage_adult': '',
                    'form': '',
                    'description': '',
                    'side_effects': '',
                    'interactions': '',
                    'contraindications': ''
                }
            })

        return jsonify({
            'success': True,
            'data': {
                'cart_id': cart.cart_id,
                'pharmacy_id': cart.pharmacy_id,
                'items': items,
                'total_price': total_cart_price
            }
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@cart_bp.route('/add', methods=['POST'])
@jwt_required()
def add_to_cart():
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        medicine_id = data.get('medicine_id')
        quantity = data.get('quantity', 1)
        
        if not medicine_id:
            return jsonify({'success': False, 'message': 'medicine_id is required'}), 400
            
        cart = Cart.query.filter_by(user_id=user_id).first()
        if not cart:
            cart = Cart(user_id=user_id)
            db.session.add(cart)
            db.session.commit()
            
        existing_item = CartItem.query.filter_by(cart_id=cart.cart_id, medicine_id=medicine_id).first()
        if existing_item:
            existing_item.quantity += quantity
        else:
            new_item = CartItem(cart_id=cart.cart_id, medicine_id=medicine_id, quantity=quantity)
            db.session.add(new_item)
            
        db.session.commit()
        return jsonify({'success': True, 'message': 'Added to cart'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@cart_bp.route('/update/<string:item_id>', methods=['PUT'])
@jwt_required()
def update_cart_item(item_id):
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        quantity = data.get('quantity')
        
        if quantity is None or quantity < 1:
            return jsonify({'success': False, 'message': 'Invalid quantity'}), 400
            
        item = CartItem.query.join(Cart).filter(CartItem.cart_item_id == item_id, Cart.user_id == user_id).first()
        if not item:
            return jsonify({'success': False, 'message': 'Item not found in your cart'}), 404
            
        item.quantity = quantity
        db.session.commit()
        return jsonify({'success': True, 'message': 'Cart updated'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@cart_bp.route('/remove/<string:item_id>', methods=['DELETE'])
@jwt_required()
def remove_cart_item(item_id):
    try:
        user_id = get_jwt_identity()
        item = CartItem.query.join(Cart).filter(CartItem.cart_item_id == item_id, Cart.user_id == user_id).first()
        if not item:
            return jsonify({'success': False, 'message': 'Item not found'}), 404
            
        db.session.delete(item)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Item removed'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@cart_bp.route('/checkout', methods=['POST'])
@jwt_required()
def checkout():
    try:
        user_id = get_jwt_identity()
        cart = Cart.query.filter_by(user_id=user_id).first()
        
        if not cart or not cart.items:
            return jsonify({'success': False, 'message': 'Cart is empty'}), 400
            
        if cart.pharmacy_id:
            query = text("""
                SELECT SUM(ci.quantity) AS total_qty,
                       SUM(ci.quantity * COALESCE((SELECT i.price FROM medicine_inventory i JOIN medicine_info m2 ON i.medicine_name = m2.medicine_name WHERE m2.id = ci.medicine_id AND i.pharmacy_id = :pharmacy_id), 0)) AS total_price
                FROM cart_items ci
                WHERE ci.cart_id = :cart_id
            """)
            params = {'cart_id': cart.cart_id, 'pharmacy_id': cart.pharmacy_id}
        else:
            query = text("""
                SELECT SUM(ci.quantity) AS total_qty,
                       SUM(ci.quantity * COALESCE((SELECT AVG(i.price) FROM medicine_inventory i JOIN medicine_info m2 ON i.medicine_name = m2.medicine_name WHERE m2.id = ci.medicine_id), 0)) AS total_price
                FROM cart_items ci
                WHERE ci.cart_id = :cart_id
            """)
            params = {'cart_id': cart.cart_id}
            
        result = db.session.execute(query, params).fetchone()
        
        total_qty = int(result[0] or 0)
        total_price = float(result[1] or 0.0)
        
        if total_qty == 0:
            return jsonify({'success': False, 'message': 'Cart has no valid items'}), 400
            
        pharmacy = None
        if cart.pharmacy_id:
            pharmacy = Pharmacy.query.filter_by(pharmacy_id=cart.pharmacy_id).first()
        if not pharmacy:
            pharmacy = Pharmacy.query.first()
            
        if not pharmacy:
            return jsonify({'success': False, 'message': 'No pharmacies available to fulfill order'}), 400
            
        order_medicines = []
        for item in cart.items:
            m_info = db.session.execute(text("SELECT medicine_name FROM medicine_info WHERE id = :mid"), {'mid': item.medicine_id}).fetchone()
            m_name = m_info[0] if m_info else 'Unknown Medicine'
            order_medicines.append({'name': m_name, 'quantity': item.quantity})

        new_order = DeliveryOrder(
            user_id=user_id,
            pharmacy_id=pharmacy.pharmacy_id,
            quantity=total_qty,
            total_price=total_price,
            status='assigned',
            payment_status='pending',
            medicines=order_medicines
        )
        
        db.session.add(new_order)
        
        for item in cart.items:
            db.session.delete(item)
            
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Order created successfully from cart',
            'order_id': new_order.order_id,
            'pharmacy_name': pharmacy.name
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@cart_bp.route('/bulk_add_by_name', methods=['POST'])
@jwt_required()
def bulk_add_by_name():
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        names = data.get('names', [])
        pharmacy_id = data.get('pharmacy_id')
        
        if not names or not isinstance(names, list):
            return jsonify({'success': False, 'message': 'names list is required'}), 400
            
        cart = Cart.query.filter_by(user_id=user_id).first()
        if not cart:
            cart = Cart(user_id=user_id)
            db.session.add(cart)
            db.session.commit()
            
        if pharmacy_id:
            if cart.pharmacy_id and cart.pharmacy_id != pharmacy_id:
                CartItem.query.filter_by(cart_id=cart.cart_id).delete()
            cart.pharmacy_id = pharmacy_id
            db.session.commit()
            
        import re
        import difflib

        # Get all candidates in inventory (distinct name, stock, and price)
        if pharmacy_id:
            inventory_candidates = db.session.query(
                MedicineInventory.medicine_name,
                MedicineInventory.stock_quantity.label('total_stock'),
                MedicineInventory.price.label('avg_price')
            ).filter(MedicineInventory.pharmacy_id == pharmacy_id).all()
        else:
            inventory_candidates = db.session.query(
                MedicineInventory.medicine_name,
                db.func.sum(MedicineInventory.stock_quantity).label('total_stock'),
                db.func.avg(MedicineInventory.price).label('avg_price')
            ).group_by(MedicineInventory.medicine_name).all()
        
        # inventory_info = [(name, stock, price)]
        inventory_info = [(r[0], int(r[1]) if r[1] is not None else 0, float(r[2]) if r[2] is not None else 0.0) for r in inventory_candidates if r[0]]
        
        # Get all distinct catalog names
        info_names = [r[0] for r in db.session.query(MedicineInfo.medicine_name).distinct().all() if r[0]]

        # Highly robust fuzzy matching with tie-breaker
        def find_best_inventory_match(name, candidates_info, cutoff=0.6):
            if not candidates_info:
                return None
            name_lower = name.lower().strip()
            
            # 1. Exact match (case insensitive)
            for c_name, c_stock, c_price in candidates_info:
                if c_name.lower().strip() == name_lower:
                    return c_name
                    
            # 2. Perfect substring match
            for c_name, c_stock, c_price in candidates_info:
                c_lower = c_name.lower().strip()
                if name_lower in c_lower or c_lower in name_lower:
                    return c_name
                    
            # 3. Clean suffix matches
            suffixes_pat = r'\b(?:\d+\.?\d*\s*)?(mg|g|ml|cream|gel|injection|inhaler|tablets|tablet|capsules|capsule)\b'
            clean_name = re.sub(suffixes_pat, '', name_lower).strip()
            clean_name = re.sub(r'\s+', ' ', clean_name).strip()
            
            for c_name, c_stock, c_price in candidates_info:
                c_lower = c_name.lower().strip()
                c_clean = re.sub(suffixes_pat, '', c_lower).strip()
                c_clean = re.sub(r'\s+', ' ', c_clean).strip()
                if clean_name and c_clean:
                    if clean_name in c_clean or c_clean in clean_name:
                        return c_name
            
            # 4. SequenceMatcher fuzzy match with tie-breaker & performance pre-filtering
            first_char = name_lower[0] if name_lower else ''
            filtered_info = []
            for c_name, c_stock, c_price in candidates_info:
                c_lower = c_name.lower().strip()
                # Pre-filter for performance: same first character OR similar length within 4 chars
                if c_lower.startswith(first_char) or abs(len(c_lower) - len(name_lower)) <= 4:
                    filtered_info.append((c_name, c_stock, c_price))
                    
            best_match = None
            best_ratio = 0.0
            best_has_stock = False
            
            for c_name, c_stock, c_price in filtered_info:
                c_lower = c_name.lower().strip()
                c_clean = re.sub(suffixes_pat, '', c_lower).strip()
                c_clean = re.sub(r'\s+', ' ', c_clean).strip()
                ratio = difflib.SequenceMatcher(None, clean_name, c_clean).ratio()
                if ratio < cutoff:
                    continue
                    
                has_stock = (c_stock > 0) and (c_price > 0)
                
                # Tie-breaking logic:
                # - Prefer higher ratio by more than 0.01 margin
                # - Within 0.01 margin, prefer the one with valid stock & price
                is_better = False
                if ratio > best_ratio + 0.01:
                    is_better = True
                elif ratio >= best_ratio - 0.01:
                    if has_stock and not best_has_stock:
                        is_better = True
                    elif has_stock == best_has_stock and ratio > best_ratio:
                        is_better = True
                        
                if is_better or best_match is None:
                    best_ratio = ratio
                    best_match = c_name
                    best_has_stock = has_stock
                    
            return best_match

        def find_best_catalog_match(name, candidates, cutoff=0.6):
            if not candidates:
                return None
            name_lower = name.lower().strip()
            
            # 1. Exact match (case insensitive)
            for c in candidates:
                if c.lower().strip() == name_lower:
                    return c
                    
            # 2. Perfect substring match
            for c in candidates:
                c_lower = c.lower().strip()
                if name_lower in c_lower or c_lower in name_lower:
                    return c
                    
            # 3. Clean suffix matches
            suffixes_pat = r'\b(?:\d+\.?\d*\s*)?(mg|g|ml|cream|gel|injection|inhaler|tablets|tablet|capsules|capsule)\b'
            clean_name = re.sub(suffixes_pat, '', name_lower).strip()
            clean_name = re.sub(r'\s+', ' ', clean_name).strip()
            
            for c in candidates:
                c_lower = c.lower().strip()
                c_clean = re.sub(suffixes_pat, '', c_lower).strip()
                c_clean = re.sub(r'\s+', ' ', c_clean).strip()
                if clean_name and c_clean:
                    if clean_name in c_clean or c_clean in clean_name:
                        return c
            
            # 4. SequenceMatcher fuzzy match with performance pre-filtering
            first_char = name_lower[0] if name_lower else ''
            filtered = []
            for c in candidates:
                c_lower = c.lower().strip()
                if c_lower.startswith(first_char) or abs(len(c_lower) - len(name_lower)) <= 4:
                    filtered.append(c)
                    
            best_match = None
            best_ratio = 0.0
            for c in filtered:
                c_lower = c.lower().strip()
                c_clean = re.sub(suffixes_pat, '', c_lower).strip()
                c_clean = re.sub(r'\s+', ' ', c_clean).strip()
                ratio = difflib.SequenceMatcher(None, clean_name, c_clean).ratio()
                if ratio > best_ratio:
                    best_ratio = ratio
                    best_match = c
            if best_ratio >= cutoff:
                return best_match
            return None

        added_items = []
        for raw_name in names:
            name_clean = raw_name.strip()
            qty = 1
            match = re.search(r'\s+x(\d+)$', name_clean, re.IGNORECASE)
            if match:
                qty = int(match.group(1))
                name_clean = name_clean[:match.start()].strip()
                
            # A. Search inventory first
            matched_inventory_name = find_best_inventory_match(name_clean, inventory_info)
            
            if matched_inventory_name:
                # Query stock and price for matched inventory name
                if pharmacy_id:
                    inv_data = db.session.query(
                        MedicineInventory.stock_quantity.label('total_stock'),
                        MedicineInventory.price.label('avg_price')
                    ).filter(
                        MedicineInventory.medicine_name == matched_inventory_name,
                        MedicineInventory.pharmacy_id == pharmacy_id
                    ).first()
                else:
                    inv_data = db.session.query(
                        db.func.sum(MedicineInventory.stock_quantity).label('total_stock'),
                        db.func.avg(MedicineInventory.price).label('avg_price')
                    ).filter(
                        MedicineInventory.medicine_name == matched_inventory_name
                    ).first()
                
                avg_price = float(inv_data[1]) if inv_data and inv_data[1] is not None else 0.0
                
                # Fetch display name / ID from MedicineInfo catalog if available
                m_info = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(matched_inventory_name)).first()
                if not m_info:
                    # Create catalog info record if it somehow exists in inventory but not info
                    m_info = MedicineInfo(medicine_name=matched_inventory_name, generic_name='Fuzzy Matched')
                    db.session.add(m_info)
                    db.session.flush()
                
                medicine_id = m_info.id
                
                existing_item = CartItem.query.filter_by(cart_id=cart.cart_id, medicine_id=medicine_id).first()
                if existing_item:
                    existing_item.quantity += qty
                else:
                    new_item = CartItem(cart_id=cart.cart_id, medicine_id=medicine_id, quantity=qty)
                    db.session.add(new_item)
                    
                added_items.append({
                    'id': medicine_id,
                    'name': m_info.medicine_name,
                    'price': avg_price,
                    'quantity': qty,
                    'matched': True
                })
            else:
                # B. Search catalog info next
                matched_catalog_name = find_best_catalog_match(name_clean, info_names)
                if matched_catalog_name:
                    m_info = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(matched_catalog_name)).first()
                    medicine_id = m_info.id
                    
                    existing_item = CartItem.query.filter_by(cart_id=cart.cart_id, medicine_id=medicine_id).first()
                    if existing_item:
                        existing_item.quantity += qty
                    else:
                        new_item = CartItem(cart_id=cart.cart_id, medicine_id=medicine_id, quantity=qty)
                        db.session.add(new_item)
                        
                    added_items.append({
                        'id': medicine_id,
                        'name': m_info.medicine_name,
                        'price': 0.0,
                        'quantity': qty,
                        'matched': True
                    })
                else:
                    # C. Not found anywhere -> Check duplicate first!
                    existing = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(name_clean)).first()
                    if not existing:
                        new_med = MedicineInfo(
                            medicine_name=name_clean,
                            generic_name='OCR Extracted'
                        )
                        db.session.add(new_med)
                        db.session.flush()
                        medicine_id = new_med.id
                        info_names.append(name_clean)
                    else:
                        medicine_id = existing.id
                        
                    new_item = CartItem(cart_id=cart.cart_id, medicine_id=str(medicine_id), quantity=qty)
                    db.session.add(new_item)
                    
                    added_items.append({
                        'id': medicine_id,
                        'name': name_clean,
                        'price': 0.0,
                        'quantity': qty,
                        'matched': False
                    })
                
        db.session.commit()
        return jsonify({'success': True, 'data': added_items, 'message': 'Bulk added to cart'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500
