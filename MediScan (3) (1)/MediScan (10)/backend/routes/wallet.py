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
        
        # Determine reward level
        level = "Bronze"
        if pts > 1500:
            level = "Platinum"
        elif pts > 500:
            level = "Gold"
        elif pts > 100:
            level = "Silver"
            
        return jsonify({
            'success': True,
            'data': {
                'reward_points': pts,
                'reward_level': level,
                'wallet_balance': 0.0
            }
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@wallet_bp.route('/share', methods=['POST'])
@jwt_required()
def share_app():
    try:
        user_id = get_jwt_identity()
        user = User.query.filter_by(user_id=user_id).first()
        if not user:
            return jsonify({'success': False, 'message': 'User not found'}), 404
            
        points_earned = 50
        user.reward_points = (user.reward_points or 0) + points_earned
        
        # Determine reward level
        pts = user.reward_points
        level = "Bronze"
        if pts > 1500:
            level = "Platinum"
        elif pts > 500:
            level = "Gold"
        elif pts > 100:
            level = "Silver"
            
        tx = WalletTransaction(
            user_id=user_id,
            transaction_type='earn',
            points=points_earned,
            amount=0.0,
            description="Bonus points earned for sharing the app / referral"
        )
        db.session.add(tx)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Points awarded for sharing the application!',
            'data': {
                'reward_points': user.reward_points,
                'reward_level': level
            }
        }), 200
    except Exception as e:
        db.session.rollback()
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
