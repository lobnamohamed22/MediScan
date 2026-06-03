from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from extensions import db
from sqlalchemy import text
from models.pharmacy import Pharmacy
from models.medicine import MedicineInventory

pharmacies_bp = Blueprint('pharmacies', __name__)

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
        return jsonify({'success': True, 'data': pharmacy.to_dict()}), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 2. NEARBY PHARMACIES (SP + EGYPT FILTER)
# -------------------------------
@pharmacies_bp.route('/nearby', methods=['GET'])
@jwt_required()
def get_nearby_pharmacies():
    try:
        lat = float(request.args.get('lat', 0))
        lng = float(request.args.get('lng', 0))
        medicine = request.args.get('medicine', '')
        
        if lat == 0 or lng == 0:
            return jsonify({'success': False, 'message': 'Location is required'}), 400
        
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
                  AND mi.medicine_name LIKE :med
                  AND mi.stock_quantity > 0
                  AND mi.expiry_date > CURDATE()
                GROUP BY p.pharmacy_id
                ORDER BY distance_km
                LIMIT 15
            """)
            params = {'lat': lat, 'lng': lng, 'med': f'%{medicine}%'}
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
                ORDER BY distance_km
                LIMIT 15
            """)
            params = {'lat': lat, 'lng': lng}

        result = db.session.execute(query, params).fetchall()
        db.session.remove()
        
        egypt_results = []
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
            
            # Egypt bounds: lat 22-32, lng 25-37
            if 22.0 <= p_lat <= 32.0 and 25.0 <= p_lng <= 37.0:
                egypt_results.append({
                    'id': p_id,
                    'name': p_name,
                    'address': p_address,
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
            'data': egypt_results[:10]
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


# -------------------------------
# 3. SEARCH PHARMACIES
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
                user_lat = float(lat_str)
                user_lng = float(lng_str)
            except ValueError:
                pass

        pharmacies = Pharmacy.query.filter(Pharmacy.name.ilike(f'%{name}%')).all()
        result = []
        for p in pharmacies:
            p_lat = float(p.latitude) if p.latitude else 0
            p_lng = float(p.longitude) if p.longitude else 0
            # Egypt filter
            if 22 <= p_lat <= 32 and 25 <= p_lng <= 37:
                p_dict = p.to_dict()
                if user_lat is not None and user_lng is not None and user_lat != 0 and user_lng != 0:
                    dist = calculate_haversine(user_lat, user_lng, p_lat, p_lng)
                    p_dict['distance'] = round(dist, 2)
                else:
                    p_dict['distance'] = None
                result.append(p_dict)
        
        if user_lat is not None and user_lng is not None and user_lat != 0 and user_lng != 0:
            result.sort(key=lambda x: x.get('distance') if x.get('distance') is not None else 999999.0)
            
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