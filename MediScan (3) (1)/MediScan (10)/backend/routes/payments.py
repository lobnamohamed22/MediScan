from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity

payments_bp = Blueprint('payments', __name__)

# -------------------------------
# 1. PROCESS PAYMENT
# -------------------------------
@payments_bp.route('/process', methods=['POST'])
@jwt_required()
def process_payment():
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        order_id = data.get('order_id')
        amount = data.get('amount')
        payment_method = data.get('payment_method', 'cash')
        
        if not order_id or not amount:
            return jsonify({'success': False, 'message': 'order_id and amount are required'}), 400
        
        # Mock payment processing
        return jsonify({
            'success': True,
            'message': 'Payment processed successfully',
            'data': {
                'order_id': order_id,
                'amount': amount,
                'payment_method': payment_method,
                'status': 'completed'
            }
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 2. TEST ROUTE
# -------------------------------
@payments_bp.route('/test', methods=['GET'])
def test():
    return jsonify({'success': True, 'message': 'Payments routes working'}), 200