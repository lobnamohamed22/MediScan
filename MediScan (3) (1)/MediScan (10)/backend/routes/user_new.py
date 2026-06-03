from flask import Blueprint, request, jsonify, current_app as app
from flask_jwt_extended import jwt_required, get_jwt_identity
from extensions import db
from models.user import User
import os
from werkzeug.utils import secure_filename
from datetime import datetime

user_bp = Blueprint('user', __name__)

@user_bp.route('/ping', methods=['GET'])
def ping():
    return jsonify({'success': True, 'message': 'pong'}), 200
    
# -------------------------------
# 1. GET PROFILE (عرض الملف الشخصي)
# -------------------------------
@user_bp.route('/profile', methods=['GET'])
@jwt_required()
def get_profile():
    """
    عرض الملف الشخصي للمستخدم الحالي
    """
    try:
        # جلب الـ user_id من التوكن
        user_id = get_jwt_identity()
        
        # تحويل لـ int إذا كان string
        if isinstance(user_id, str):
            user_id = int(user_id)
        elif isinstance(user_id, dict) and 'sub' in user_id:
            user_id = int(user_id['sub'])
        
        # البحث عن المستخدم
        user = User.query.get(user_id)
        
        if not user:
            return jsonify({'success': False, 'message': 'المستخدم غير موجود'}), 404
        
        return jsonify({
            'success': True,
            'data': user.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


# -------------------------------
# 2. UPDATE PROFILE (تحديث الملف الشخصي)
# -------------------------------
@user_bp.route('/profile', methods=['PUT'])
@jwt_required()
def update_profile():
    """
    تحديث بيانات الملف الشخصي (الاسم ورقم الهاتف)
    """
    try:
        # جلب الـ user_id من التوكن
        user_id = get_jwt_identity()
        if isinstance(user_id, str):
            user_id = int(user_id)
        elif isinstance(user_id, dict) and 'sub' in user_id:
            user_id = int(user_id['sub'])
        
        # البحث عن المستخدم
        user = User.query.get(user_id)
        if not user:
            return jsonify({'success': False, 'message': 'المستخدم غير موجود'}), 404
        
        # استقبال البيانات الجديدة
        data = request.get_json()
        
        # تحديث الاسم لو موجود
        if 'name' in data:
            user.name = data['name']
        
        # تحديث رقم الهاتف لو موجود
        if 'phone' in data:
            user.phone = data['phone']
        
        # حفظ التغييرات
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'تم تحديث الملف الشخصي',
            'data': user.to_dict()
        }), 200
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


# -------------------------------
# 3. CHANGE PASSWORD (تغيير كلمة المرور)
# -------------------------------
@user_bp.route('/change-password', methods=['PUT'])
@jwt_required()
def change_password():
    """
    تغيير كلمة المرور
    """
    try:
        from werkzeug.security import generate_password_hash
        from routes.auth import check_user_password
        
        user_id = get_jwt_identity()
        if isinstance(user_id, str):
            user_id = int(user_id)
        elif isinstance(user_id, dict) and 'sub' in user_id:
            user_id = int(user_id['sub'])
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({'success': False, 'message': 'المستخدم غير موجود'}), 404
        
        data = request.get_json()
        
        # التحقق من كلمة المرور الحالية
        if not check_user_password(user.password_hash, data['current_password']):
            return jsonify({'success': False, 'message': 'كلمة المرور الحالية غير صحيحة'}), 400
        
        # تحديث كلمة المرور
        user.password_hash = generate_password_hash(data['new_password'])
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'تم تغيير كلمة المرور'
        }), 200
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


# -------------------------------
# 4. UPLOAD PROFILE IMAGE (رفع صورة بروفايل)
# -------------------------------
@user_bp.route('/upload-image', methods=['POST'])
@jwt_required()
def upload_image():
    """
    رفع صورة للملف الشخصي
    """
    try:
        user_id = get_jwt_identity()
        if isinstance(user_id, str):
            user_id = int(user_id)
        elif isinstance(user_id, dict) and 'sub' in user_id:
            user_id = int(user_id['sub'])
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({'success': False, 'message': 'المستخدم غير موجود'}), 404
        
        # التحقق من وجود صورة
        if 'image' not in request.files:
            return jsonify({'success': False, 'message': 'لم يتم رفع صورة'}), 400
        
        file = request.files['image']
        
        if file.filename == '':
            return jsonify({'success': False, 'message': 'لم يتم اختيار صورة'}), 400
        
        # التأكد من نوع الملف
        allowed_extensions = {'png', 'jpg', 'jpeg', 'gif'}
        if '.' not in file.filename or file.filename.rsplit('.', 1)[1].lower() not in allowed_extensions:
            return jsonify({'success': False, 'message': 'نوع الملف غير مسموح. الأنواع المسموحة: png, jpg, jpeg, gif'}), 400
        
        # إنشاء مجلد رفع الصور لو مش موجود
        upload_folder = 'uploads/profiles'
        os.makedirs(upload_folder, exist_ok=True)
        
        # حفظ الصورة
        filename = secure_filename(f"user_{user_id}_{datetime.now().timestamp()}.jpg")
        filepath = os.path.join(upload_folder, filename)
        file.save(filepath)
        
        # تحديث مسار الصورة في قاعدة البيانات
        user.profile_image = filepath
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'تم رفع الصورة بنجاح',
            'data': {
                'profile_image': filepath
            }
        }), 200
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


# -------------------------------
# 5. UPDATE LOCATION (تحديث موقع المستخدم)
# -------------------------------
@user_bp.route('/location', methods=['PUT'])
@jwt_required()
def update_location():
    """
    تحديث موقع المستخدم (خط الطول والعرض)
    """
    try:
        user_id = get_jwt_identity()
        if isinstance(user_id, str):
            user_id = int(user_id)
        elif isinstance(user_id, dict) and 'sub' in user_id:
            user_id = int(user_id['sub'])
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({'success': False, 'message': 'المستخدم غير موجود'}), 404
        
        data = request.get_json()
        
        # تحديث الموقع
        if 'latitude' in data and 'longitude' in data:
            # لو عايزة تحفظي الموقع في جدول منفصل، هنحتاج نضيفه بعدين
            # دلوقتي بنرجع رسالة نجاح بس
            pass
        
        return jsonify({
            'success': True,
            'message': 'تم تحديث الموقع'
        }), 200
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


# -------------------------------
# DELETE ACCOUNT
# -------------------------------
@user_bp.route('/account', methods=['DELETE'])
@jwt_required()
def delete_account():
    """حذف حساب المستخدم نهائياً"""
    try:
        user_id = get_jwt_identity()
        if isinstance(user_id, str):
            user_id = int(user_id)
        
        user = User.query.get(user_id)
        if not user:
            return jsonify({
                'success': False,
                'message': 'المستخدم غير موجود'
            }), 404
        
        # حذف المستخدم من قاعدة البيانات
        db.session.delete(user)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'تم حذف الحساب بنجاح'
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': str(e)
        }), 500

# -------------------------------
# TEST ROUTE
# -------------------------------
@user_bp.route('/test', methods=['GET'])
def test():
    # جلب كل الـ routes المسجلة في هذا blueprint
    routes = []
    for rule in app.url_map.iter_rules():
        if rule.endpoint.startswith('user.'):
            routes.append(str(rule))
    
    return jsonify({
        'success': True,
        'message': 'User routes are working!',
        'endpoints': sorted(routes)
    }), 200