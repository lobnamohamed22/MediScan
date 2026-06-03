from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from extensions import db
from models.notification import Notification

notifications_bp = Blueprint('notifications', __name__)

# -------------------------------
# 1. GET ALL NOTIFICATIONS
# -------------------------------
@notifications_bp.route('', methods=['GET'])
@jwt_required()
def get_notifications():
    try:
        user_id = get_jwt_identity()
        notifications = Notification.query.filter_by(user_id=user_id).order_by(Notification.created_at.desc()).limit(50).all()
        return jsonify({
            'success': True,
            'data': [n.to_dict() for n in notifications]
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 2. GET UNREAD COUNT
# -------------------------------
@notifications_bp.route('/unread-count', methods=['GET'])
@jwt_required()
def get_unread_count():
    try:
        user_id = get_jwt_identity()
        count = Notification.query.filter_by(user_id=user_id, is_read=False).count()
        return jsonify({
            'success': True,
            'data': {'count': count}
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 3. MARK AS READ
# -------------------------------
@notifications_bp.route('/<string:id>/read', methods=['PATCH'])
@jwt_required()
def mark_as_read(id):
    try:
        user_id = get_jwt_identity()
        notification = Notification.query.filter_by(notification_id=id, user_id=user_id).first()
        if not notification:
            return jsonify({'success': False, 'message': 'Notification not found'}), 404
        notification.is_read = True
        db.session.commit()
        return jsonify({'success': True, 'message': 'Marked as read'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 4. MARK ALL AS READ
# -------------------------------
@notifications_bp.route('/read-all', methods=['PATCH'])
@jwt_required()
def mark_all_as_read():
    try:
        user_id = get_jwt_identity()
        Notification.query.filter_by(user_id=user_id, is_read=False).update({'is_read': True})
        db.session.commit()
        return jsonify({'success': True, 'message': 'All marked as read'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 5. DELETE NOTIFICATION
# -------------------------------
@notifications_bp.route('/<string:id>', methods=['DELETE'])
@jwt_required()
def delete_notification(id):
    try:
        user_id = get_jwt_identity()
        notification = Notification.query.filter_by(notification_id=id, user_id=user_id).first()
        if not notification:
            return jsonify({'success': False, 'message': 'Notification not found'}), 404
        db.session.delete(notification)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Notification deleted'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 6. TEST ROUTE
# -------------------------------
@notifications_bp.route('/test', methods=['GET'])
def test():
    return jsonify({'success': True, 'message': 'Notifications routes working'}), 200