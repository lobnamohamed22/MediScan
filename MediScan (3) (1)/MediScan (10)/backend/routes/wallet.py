from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from extensions import db
from models.user import User
from models.wallet import WalletTransaction

wallet_bp = Blueprint('wallet', __name__)

@wallet_bp.route('', methods=['GET'])
@jwt_required()
def get_wallet():
    try:
        user_id = get_jwt_identity()
        user = User.query.filter_by(user_id=user_id).first()
        if not user:
            return jsonify({'success': False, 'message': 'User not found'}), 404
            
        pts = user.reward_points if user.reward_points is not None else 0
        bal = float(user.wallet_balance) if user.wallet_balance is not None else 0.0
        
        # Keep them synchronized (10 points = 1 EGP)
        calculated_bal = pts * 0.1
        if bal != calculated_bal:
            user.wallet_balance = calculated_bal
            db.session.commit()
            bal = calculated_bal
            
        return jsonify({
            'success': True,
            'data': {
                'reward_points': pts,
                'wallet_balance': bal
            }
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@wallet_bp.route('/transactions', methods=['GET'])
@jwt_required()
def get_transactions():
    try:
        user_id = get_jwt_identity()
        txs = WalletTransaction.query.filter_by(user_id=user_id).order_by(WalletTransaction.created_at.desc()).all()
        return jsonify({
            'success': True,
            'data': [tx.to_dict() for tx in txs]
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500
