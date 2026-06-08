from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from werkzeug.security import generate_password_hash
from extensions import db
from models.user import User
from models.order import DeliveryOrder
from models.pharmacy import Pharmacy
from models.medicine import MedicineInfo, MedicineInventory
from models.prescription import Prescription
from models.notification import Notification
from datetime import datetime

admin_bp = Blueprint('admin', __name__)

def is_admin(user_id):
    user = User.query.get(user_id)
    return user and user.role == 'admin'

# -------------------------------
# 1. ANALYTICS
# -------------------------------
@admin_bp.route('/analytics', methods=['GET'])
@jwt_required()
def get_analytics():
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        total_users = User.query.count()
        total_orders = DeliveryOrder.query.count()
        total_pharmacies = Pharmacy.query.count()
        
        from sqlalchemy import func
        revenue_query = db.session.query(func.sum(DeliveryOrder.total_price)).filter(DeliveryOrder.status == 'delivered').scalar()
        revenue = float(revenue_query) if revenue_query else 0.0

        return jsonify({
            'success': True,
            'data': {
                'total_users': total_users,
                'total_orders': total_orders,
                'total_pharmacies': total_pharmacies,
                'revenue': revenue
            }
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 2. USERS CRUD
# -------------------------------
@admin_bp.route('/users', methods=['GET'])
@jwt_required()
def get_users():
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        page = request.args.get('page')
        limit = request.args.get('limit')
        query = User.query
        if page and limit:
            try:
                page = int(page)
                limit = int(limit)
                query = query.limit(limit).offset((page - 1) * limit)
            except ValueError:
                pass
                
        users = query.all()
        return jsonify({
            'success': True,
            'data': [u.to_dict() for u in users]
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/users', methods=['POST'])
@jwt_required()
def create_user():
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        data = request.get_json()
        required = ['email', 'phone', 'password', 'full_name', 'role']
        for field in required:
            if not data.get(field):
                return jsonify({'success': False, 'message': f'{field} is required'}), 400
                
        # Check if email/phone exists
        if User.query.filter_by(email=data['email']).first():
            return jsonify({'success': False, 'message': 'Email already exists'}), 400
        if User.query.filter_by(phone=data['phone']).first():
            return jsonify({'success': False, 'message': 'Phone already exists'}), 400
            
        new_user = User(
            email=data['email'],
            phone=data['phone'],
            password_hash=generate_password_hash(data['password']),
            full_name=data['full_name'],
            role=data['role'],
            gender=data.get('gender', 'Other'),
            is_verified=data.get('is_verified', False)
        )
        if data.get('date_of_birth'):
            try:
                new_user.date_of_birth = datetime.strptime(data['date_of_birth'], '%Y-%m-%d').date()
            except ValueError:
                pass
                
        db.session.add(new_user)
        db.session.commit()
        return jsonify({'success': True, 'message': 'User created', 'data': new_user.to_dict()}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/users/<string:id>', methods=['PATCH'])
@jwt_required()
def update_user(id):
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        data = request.get_json()
        user = User.query.get(id)
        if not user:
            return jsonify({'success': False, 'message': 'User not found'}), 404
            
        if 'full_name' in data:
            user.full_name = data['full_name']
        if 'role' in data:
            user.role = data['role']
        if 'gender' in data:
            user.gender = data['gender']
        if 'is_verified' in data:
            user.is_verified = bool(data['is_verified'])
        if 'phone' in data:
            user.phone = data['phone']
        if 'email' in data:
            user.email = data['email']
        if 'password' in data and data['password']:
            user.password_hash = generate_password_hash(data['password'])
        if 'date_of_birth' in data:
            if data['date_of_birth']:
                try:
                    user.date_of_birth = datetime.strptime(data['date_of_birth'], '%Y-%m-%d').date()
                except ValueError:
                    pass
            else:
                user.date_of_birth = None
                
        db.session.commit()
        return jsonify({'success': True, 'message': 'User updated', 'data': user.to_dict()}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/users/<string:id>/role', methods=['PATCH'])
@jwt_required()
def update_user_role(id):
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        data = request.get_json()
        new_role = data.get('role')
        if not new_role:
            return jsonify({'success': False, 'message': 'role is required'}), 400
            
        user = User.query.get(id)
        if not user:
            return jsonify({'success': False, 'message': 'User not found'}), 404
            
        user.role = new_role
        db.session.commit()
        return jsonify({'success': True, 'message': 'User role updated'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/users/<string:id>', methods=['DELETE'])
@jwt_required()
def delete_user(id):
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        user = User.query.get(id)
        if not user:
            return jsonify({'success': False, 'message': 'User not found'}), 404
            
        db.session.delete(user)
        db.session.commit()
        return jsonify({'success': True, 'message': 'User deleted'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500


# -------------------------------
# 3. PHARMACIES CRUD
# -------------------------------
@admin_bp.route('/pharmacies', methods=['GET'])
@jwt_required()
def get_pharmacies():
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        page = request.args.get('page')
        limit = request.args.get('limit')
        query = Pharmacy.query
        if page and limit:
            try:
                page = int(page)
                limit = int(limit)
                query = query.limit(limit).offset((page - 1) * limit)
            except ValueError:
                pass
                
        pharmacies = query.all()
        return jsonify({
            'success': True,
            'data': [p.to_dict() for p in pharmacies]
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/pharmacies', methods=['POST'])
@jwt_required()
def create_pharmacy():
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        data = request.get_json()
        required = ['name', 'address']
        for field in required:
            if not data.get(field):
                return jsonify({'success': False, 'message': f'{field} is required'}), 400
                
        new_pharmacy = Pharmacy(
            name=data['name'],
            address=data['address'],
            latitude=data.get('latitude', 30.0),
            longitude=data.get('longitude', 31.0),
            phone=data.get('phone'),
            is_active=data.get('is_active', True),
            delivery_available=data.get('delivery_available', True),
            owner_id=data.get('owner_id')
        )
        db.session.add(new_pharmacy)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Pharmacy created', 'data': new_pharmacy.to_dict()}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/pharmacies/<string:id>', methods=['PATCH'])
@jwt_required()
def update_pharmacy(id):
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        data = request.get_json()
        pharmacy = Pharmacy.query.get(id)
        if not pharmacy:
            return jsonify({'success': False, 'message': 'Pharmacy not found'}), 404
            
        if 'name' in data:
            pharmacy.name = data['name']
        if 'address' in data:
            pharmacy.address = data['address']
        if 'latitude' in data:
            pharmacy.latitude = data['latitude']
        if 'longitude' in data:
            pharmacy.longitude = data['longitude']
        if 'phone' in data:
            pharmacy.phone = data['phone']
        if 'is_active' in data:
            pharmacy.is_active = bool(data['is_active'])
        if 'delivery_available' in data:
            pharmacy.delivery_available = bool(data['delivery_available'])
        if 'owner_id' in data:
            pharmacy.owner_id = data['owner_id'] if data['owner_id'] else None
            
        db.session.commit()
        return jsonify({'success': True, 'message': 'Pharmacy updated', 'data': pharmacy.to_dict()}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/pharmacies/<string:id>/approve', methods=['PATCH'])
@jwt_required()
def approve_pharmacy(id):
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        data = request.get_json()
        is_approved = data.get('is_approved', True)
        
        pharmacy = Pharmacy.query.get(id)
        if not pharmacy:
            return jsonify({'success': False, 'message': 'Pharmacy not found'}), 404
            
        pharmacy.is_active = is_approved
        db.session.commit()
        
        return jsonify({'success': True, 'message': f'Pharmacy {"approved" if is_approved else "disabled"}', 'data': pharmacy.to_dict()}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/pharmacies/<string:id>', methods=['DELETE'])
@jwt_required()
def delete_pharmacy(id):
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        pharmacy = Pharmacy.query.get(id)
        if not pharmacy:
            return jsonify({'success': False, 'message': 'Pharmacy not found'}), 404
            
        db.session.delete(pharmacy)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Pharmacy deleted'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500


# -------------------------------
# 4. MEDICINES CATALOG CRUD
# -------------------------------
@admin_bp.route('/medicines', methods=['GET'])
@jwt_required()
def get_medicines():
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        page = request.args.get('page')
        limit = request.args.get('limit')
        query = MedicineInfo.query
        if page and limit:
            try:
                page = int(page)
                limit = int(limit)
                query = query.limit(limit).offset((page - 1) * limit)
            except ValueError:
                pass
                
        medicines = query.all()
        return jsonify({
            'success': True,
            'data': [m.to_dict() for m in medicines]
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/medicines', methods=['POST'])
@jwt_required()
def create_medicine():
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        data = request.get_json()
        required = ['medicine_name']
        for field in required:
            if not data.get(field):
                return jsonify({'success': False, 'message': f'{field} is required'}), 400
                
        # Check unique
        if MedicineInfo.query.filter_by(medicine_name=data['medicine_name']).first():
            return jsonify({'success': False, 'message': 'Medicine name already exists'}), 400
            
        new_med = MedicineInfo(
            medicine_name=data['medicine_name'],
            generic_name=data.get('generic_name'),
            medicine_image=data.get('medicine_image'),
            uses=data.get('uses'),
            dosage_adult=data.get('dosage_adult'),
            dosage_child=data.get('dosage_child'),
            side_effects=data.get('side_effects'),
            interactions=data.get('interactions'),
            contraindications=data.get('contraindications')
        )
        db.session.add(new_med)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Medicine added to catalog', 'data': new_med.to_dict()}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/medicines/<int:id>', methods=['PATCH'])
@jwt_required()
def update_medicine(id):
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        data = request.get_json()
        med = MedicineInfo.query.get(id)
        if not med:
            return jsonify({'success': False, 'message': 'Medicine not found'}), 404
            
        if 'medicine_name' in data:
            med.medicine_name = data['medicine_name']
        if 'generic_name' in data:
            med.generic_name = data['generic_name']
        if 'medicine_image' in data:
            med.medicine_image = data['medicine_image']
        if 'uses' in data:
            med.uses = data['uses']
        if 'dosage_adult' in data:
            med.dosage_adult = data['dosage_adult']
        if 'dosage_child' in data:
            med.dosage_child = data['dosage_child']
        if 'side_effects' in data:
            med.side_effects = data['side_effects']
        if 'interactions' in data:
            med.interactions = data['interactions']
        if 'contraindications' in data:
            med.contraindications = data['contraindications']
            
        db.session.commit()
        return jsonify({'success': True, 'message': 'Medicine updated', 'data': med.to_dict()}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/medicines/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_medicine(id):
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        med = MedicineInfo.query.get(id)
        if not med:
            return jsonify({'success': False, 'message': 'Medicine not found'}), 404
            
        db.session.delete(med)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Medicine deleted from catalog'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500


# -------------------------------
# 5. INVENTORY CRUD
# -------------------------------
@admin_bp.route('/inventory', methods=['GET'])
@jwt_required()
def get_inventory():
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        page = request.args.get('page')
        limit = request.args.get('limit')
        query = MedicineInventory.query
        if page and limit:
            try:
                page = int(page)
                limit = int(limit)
                query = query.limit(limit).offset((page - 1) * limit)
            except ValueError:
                pass
                
        inv = query.all()
        return jsonify({
            'success': True,
            'data': [i.to_dict() for i in inv]
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/inventory', methods=['POST'])
@jwt_required()
def create_inventory():
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        data = request.get_json()
        required = ['pharmacy_id', 'medicine_name', 'price', 'stock_quantity']
        for field in required:
            if data.get(field) is None:
                return jsonify({'success': False, 'message': f'{field} is required'}), 400
                
        # Parse expiry date
        expiry = datetime.utcnow().date()
        if data.get('expiry_date'):
            try:
                expiry = datetime.strptime(data['expiry_date'], '%Y-%m-%d').date()
            except ValueError:
                pass
                
        new_inv = MedicineInventory(
            pharmacy_id=data['pharmacy_id'],
            medicine_name=data['medicine_name'],
            generic_name=data.get('generic_name'),
            batch_number=data.get('batch_number', 'B001'),
            expiry_date=expiry,
            stock_quantity=int(data['stock_quantity']),
            price=float(data['price']),
            is_prescription_required=bool(data.get('is_prescription_required', True))
        )
        db.session.add(new_inv)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Inventory item added', 'data': new_inv.to_dict()}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/inventory/<string:id>', methods=['PATCH'])
@jwt_required()
def update_inventory(id):
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        data = request.get_json()
        inv = MedicineInventory.query.get(id)
        if not inv:
            return jsonify({'success': False, 'message': 'Inventory item not found'}), 404
            
        if 'medicine_name' in data:
            inv.medicine_name = data['medicine_name']
        if 'generic_name' in data:
            inv.generic_name = data['generic_name']
        if 'stock_quantity' in data:
            inv.stock_quantity = int(data['stock_quantity'])
        if 'price' in data:
            inv.price = float(data['price'])
        if 'batch_number' in data:
            inv.batch_number = data['batch_number']
        if 'is_prescription_required' in data:
            inv.is_prescription_required = bool(data['is_prescription_required'])
        if 'expiry_date' in data:
            if data['expiry_date']:
                try:
                    inv.expiry_date = datetime.strptime(data['expiry_date'], '%Y-%m-%d').date()
                except ValueError:
                    pass
            else:
                inv.expiry_date = datetime.utcnow().date()
                
        db.session.commit()
        return jsonify({'success': True, 'message': 'Inventory updated', 'data': inv.to_dict()}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/inventory/<string:id>', methods=['DELETE'])
@jwt_required()
def delete_inventory(id):
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        inv = MedicineInventory.query.get(id)
        if not inv:
            return jsonify({'success': False, 'message': 'Inventory item not found'}), 404
            
        db.session.delete(inv)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Inventory item deleted'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500


# -------------------------------
# 6. PRESCRIPTIONS CRUD
# -------------------------------
@admin_bp.route('/prescriptions', methods=['GET'])
@jwt_required()
def get_prescriptions():
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        pres = Prescription.query.all()
        return jsonify({
            'success': True,
            'data': [p.to_dict() for p in pres]
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/prescriptions/<string:id>', methods=['PATCH'])
@jwt_required()
def update_prescription(id):
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        data = request.get_json()
        pres = Prescription.query.get(id)
        if not pres:
            return jsonify({'success': False, 'message': 'Prescription not found'}), 404
            
        if 'status' in data:
            pres.status = data['status']
        if 'extracted_text' in data:
            pres.extracted_text = data['extracted_text']
            
        db.session.commit()
        return jsonify({'success': True, 'message': 'Prescription updated', 'data': pres.to_dict()}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/prescriptions/<string:id>', methods=['DELETE'])
@jwt_required()
def delete_prescription(id):
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        pres = Prescription.query.get(id)
        if not pres:
            return jsonify({'success': False, 'message': 'Prescription not found'}), 404
            
        # Also clean up prescription medicines relationship
        from models.prescription import PrescriptionMedicine
        PrescriptionMedicine.query.filter_by(prescription_id=id).delete()
        
        db.session.delete(pres)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Prescription deleted'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500


# -------------------------------
# 7. ORDERS CRUD
# -------------------------------
@admin_bp.route('/orders', methods=['GET'])
@jwt_required()
def get_orders():
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        orders = DeliveryOrder.query.all()
        data = []
        for o in orders:
            o_dict = o.to_dict()
            
            # Enrich pharmacy name
            p = Pharmacy.query.get(o.pharmacy_id)
            o_dict['pharmacy_name'] = p.name if p else 'Unknown Pharmacy'
            
            # Enrich user details
            u = User.query.get(o.user_id)
            o_dict['customer_name'] = u.full_name if u else 'Unknown'
            o_dict['customer_phone'] = u.phone if u else ''
            
            # Enrich driver details
            if o.delivery_person_id:
                d = User.query.get(o.delivery_person_id)
                o_dict['driver_name'] = d.full_name if d else 'Unknown Driver'
                o_dict['driver_phone'] = d.phone if d else ''
            else:
                o_dict['driver_name'] = 'Not Assigned'
                o_dict['driver_phone'] = ''
                
            data.append(o_dict)
            
        return jsonify({
            'success': True,
            'data': data
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/orders/<string:id>', methods=['PATCH'])
@jwt_required()
def update_order(id):
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        data = request.get_json()
        order = DeliveryOrder.query.get(id)
        if not order:
            return jsonify({'success': False, 'message': 'Order not found'}), 404
            
        if 'status' in data:
            order.status = data['status']
        if 'payment_status' in data:
            order.payment_status = data['payment_status']
        if 'delivery_person_id' in data:
            order.delivery_person_id = data['delivery_person_id'] if data['delivery_person_id'] else None
        if 'total_price' in data:
            order.total_price = float(data['total_price'])
            
        db.session.commit()
        return jsonify({'success': True, 'message': 'Order updated', 'data': order.to_dict()}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

@admin_bp.route('/orders/<string:id>', methods=['DELETE'])
@jwt_required()
def delete_order(id):
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        order = DeliveryOrder.query.get(id)
        if not order:
            return jsonify({'success': False, 'message': 'Order not found'}), 404
            
        # Clean up related messages if any
        from models.order_message import OrderMessage
        OrderMessage.query.filter_by(order_id=id).delete()
        
        db.session.delete(order)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Order deleted'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500


# -------------------------------
# 8. NOTIFICATIONS API FOR ADMIN
# -------------------------------
@admin_bp.route('/notifications', methods=['GET'])
@jwt_required()
def get_all_notifications():
    try:
        user_id = get_jwt_identity()
        if not is_admin(user_id):
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        notifs = Notification.query.order_by(Notification.created_at.desc()).limit(100).all()
        
        # Enrich notifications with user names
        data = []
        for n in notifs:
            n_dict = n.to_dict()
            u = User.query.get(n.user_id)
            n_dict['user_name'] = u.full_name if u else 'System/Unknown'
            data.append(n_dict)
            
        return jsonify({
            'success': True,
            'data': data
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

