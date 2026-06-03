from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from extensions import db
from models.user import User

settings_bp = Blueprint('settings', __name__)

# -------------------------------
# 1. GET SETTINGS
# -------------------------------
@settings_bp.route('/', methods=['GET'])
@jwt_required()
def get_settings():
    try:
        user_id = get_jwt_identity()
        user = User.query.filter_by(user_id=user_id).first()
        
        if not user:
            return jsonify({'success': False, 'message': 'User not found'}), 404
        
        settings = {
            'notifications_enabled': True,
            'dark_mode': False,
            'language': 'ar',
            'save_history': True,
            'auto_scan': True
        }
        
        return jsonify({
            'success': True,
            'data': settings
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 2. UPDATE SETTINGS
# -------------------------------
@settings_bp.route('/', methods=['PUT'])
@jwt_required()
def update_settings():
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        return jsonify({
            'success': True,
            'message': 'Settings updated',
            'data': data
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 3. TEST ROUTE
# -------------------------------
@settings_bp.route('/test', methods=['GET'])
def test():
    return jsonify({'success': True, 'message': 'Settings routes working'}), 200