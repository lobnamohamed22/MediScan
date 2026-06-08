from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from extensions import db
from sqlalchemy import text
from models.reservation import Reservation
from models.prescription import PrescriptionMedicine

reservations_bp = Blueprint('reservations', __name__)

# -------------------------------
# 1. CREATE RESERVATION
# -------------------------------
@reservations_bp.route('/', methods=['POST'])
@jwt_required()
def create_reservation():
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        required = ['pharmacy_id', 'prescription_medicine_id']
        for field in required:
            if field not in data:
                return jsonify({'success': False, 'message': f'{field} is required'}), 400
        
        reservation = Reservation(
            user_id=user_id,
            pharmacy_id=data['pharmacy_id'],
            prescription_medicine_id=data['prescription_medicine_id'],
            status='pending'
        )
        
        db.session.add(reservation)
        
        # Award 10 loyalty points for reserving medicine
        from models.user import User
        from models.wallet import WalletTransaction
        user = User.query.filter_by(user_id=user_id).first()
        if user:
            user.reward_points = (user.reward_points or 0) + 10
            tx = WalletTransaction(
                user_id=user_id,
                transaction_type='earn',
                points=10,
                amount=0.0,
                description=f"Points earned for reservation"
            )
            db.session.add(tx)
            
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Reservation created',
            'data': reservation.to_dict()
        }), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 2. GET USER RESERVATIONS (STORED PROCEDURE)
# -------------------------------
@reservations_bp.route('/', methods=['GET'])
@jwt_required()
def get_reservations():
    try:
        user_id = get_jwt_identity()
        
        # Call stored procedure
        result = db.session.execute(
            text("CALL GetUserReservations(:uid)"),
            {'uid': user_id}
        ).fetchall()
        db.session.remove()
        
        reservations = []
        for row in result:
            reservations.append({
                'reservation_id': row[0],
                'pharmacy_name': row[1],
                'medicine_name': row[2],
                'status': row[3],
                'reserved_until': row[4].isoformat() if row[4] else None,
                'created_at': row[5].isoformat() if row[5] else None
            })
        
        return jsonify({
            'success': True,
            'data': reservations
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 3. UPDATE RESERVATION STATUS
# -------------------------------
@reservations_bp.route('/<string:id>/status', methods=['PATCH'])
@jwt_required()
def update_reservation_status(id):
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        new_status = data.get('status')
        
        reservation = Reservation.query.filter_by(reservation_id=id).first()
        if not reservation:
            return jsonify({'success': False, 'message': 'Reservation not found'}), 404
            
        # Permission check: patients can only cancel their own
        if reservation.user_id != user_id and new_status == 'cancelled':
             return jsonify({'success': False, 'message': 'Unauthorized'}), 403
        
        reservation.status = new_status
        db.session.commit()
        return jsonify({'success': True, 'message': f'Status updated to {new_status}'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 4. TEST ROUTE
# -------------------------------
@reservations_bp.route('/test', methods=['GET'])
def test():
    return jsonify({'success': True, 'message': 'Reservations routes working'}), 200