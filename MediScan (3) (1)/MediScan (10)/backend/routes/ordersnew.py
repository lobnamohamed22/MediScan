from flask import Blueprint, jsonify

orders_bp = Blueprint('orders', __name__)

@orders_bp.route('/test', methods=['GET'])
def test():
    return jsonify({'success': True, 'message': 'Orders test works'}), 200