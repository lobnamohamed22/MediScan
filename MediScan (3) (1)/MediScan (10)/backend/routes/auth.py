from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity, get_jwt
from werkzeug.security import generate_password_hash, check_password_hash
from extensions import db
from models.user import User
from datetime import timedelta, datetime
import re

auth_bp = Blueprint('auth', __name__)

def check_user_password(password_hash, password):
    if not password_hash:
        return False
    try:
        if check_password_hash(password_hash, password):
            return True
    except Exception:
        pass
    
    if password_hash.startswith('$2y$') or password_hash.startswith('$2b$') or password_hash.startswith('$2a$'):
        try:
            import bcrypt
            return bcrypt.checkpw(password.encode('utf-8'), password_hash.encode('utf-8'))
        except Exception:
            pass
            
    return False

@auth_bp.route('/simple', methods=['GET'])
def simple():
    return {'success': True, 'message': 'simple works'}

@auth_bp.route('/ping', methods=['GET'])
def ping():
    return {'success': True, 'message': 'pong'}

@auth_bp.route('/test2', methods=['GET'])
def test2():
    return {'success': True}

@auth_bp.route('/test3', methods=['GET'])
def test3():
    return {'success': True, 'message': 'test3 works'}

@auth_bp.route('/public', methods=['GET'])
def public():
    return {'success': True, 'message': 'public works'}

@auth_bp.route('/hello', methods=['GET'])
def hello():
    return jsonify({'success': True, 'message': 'hello world'})

# -------------------------------
# 1. REGISTER
# -------------------------------
@auth_bp.route('/register', methods=['POST'])
def register():
    try:
        data = request.get_json()
        
        required = ['name', 'email', 'password', 'phone']
        for field in required:
            if field not in data:
                return jsonify({'success': False, 'message': f'{field} مطلوب'}), 400
        
        if not re.match(r'^[^\s@]+@[^\s@]+\.[^\s@]+$', data['email']):
            return jsonify({'success': False, 'message': 'إيميل غير صحيح'}), 400
        
        # Relax phone validation to accept any 8+ digit number for testing
        if not re.match(r'^\+?\d{8,15}$', data['phone']):
            return jsonify({'success': False, 'message': 'رقم هاتف غير صحيح'}), 400
        
        if User.query.filter_by(email=data['email']).first():
            return jsonify({'success': False, 'message': 'الإيميل موجود بالفعل'}), 400
        
        if User.query.filter_by(phone=data['phone']).first():
            return jsonify({'success': False, 'message': 'رقم الهاتف موجود بالفعل'}), 400
        
        hashed = generate_password_hash(data['password'])
        role = data.get('role', 'patient') # default to patient
        if role not in ['patient', 'pharmacist', 'pharmacy_owner', 'delivery', 'admin']:
            role = 'patient'

        user = User(
            full_name=data['name'],
            email=data['email'],
            phone=data['phone'],
            password_hash=hashed,
            role=role
        )
        
        db.session.add(user)
        db.session.commit()
        
        access_token = create_access_token(identity=str(user.user_id))
        
        return jsonify({
            'success': True,
            'token': access_token,
            'user': {
                'user_id': str(user.user_id),
                'email': user.email,
                'full_name': user.full_name,
                'name': user.full_name,
                'role': user.role,
                'phone': user.phone,
                'is_verified': user.is_verified
            }
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 2. LOGIN
# -------------------------------
@auth_bp.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        
        if not data.get('email') or not data.get('password'):
            return jsonify({'success': False, 'message': 'الإيميل وكلمة المرور مطلوبان'}), 400
        
        user = User.query.filter_by(email=data['email']).first()
        
        if not user or not check_user_password(user.password_hash, data['password']):
            return jsonify({'success': False, 'message': 'بيانات غير صحيحة'}), 401
        
        user.last_login = datetime.utcnow()
        db.session.commit()
        
        access_token = create_access_token(identity=str(user.user_id))
        
        return jsonify({
            'success': True,
            'token': access_token,
            'user': {
                'user_id': str(user.user_id),
                'email': user.email,
                'full_name': user.full_name,
                'name': user.full_name,
                'role': user.role,
                'phone': user.phone,
                'is_verified': user.is_verified
            }
        }), 200
        
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 3. GET CURRENT USER (/me)
# -------------------------------
@auth_bp.route('/me', methods=['GET'])
@jwt_required()
def get_me():
    try:
        user_id = get_jwt_identity()
        user = User.query.filter_by(user_id=user_id).first()
        
        if not user:
            return jsonify({'success': False, 'message': 'User not found'}), 404
            
        return jsonify({
            'success': True,
            'data': user.to_dict()
        }), 200
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# -------------------------------
# 3. LOGOUT
# -------------------------------
@auth_bp.route('/logout', methods=['POST'])
@jwt_required()
def logout():
    """تسجيل الخروج"""
    try:
        return jsonify({
            'success': True,
            'message': 'تم تسجيل الخروج'
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': str(e)
        }), 500

@auth_bp.route('/logout-test', methods=['GET'])
def logout_test():
    """route تجريبي للـ logout"""
    return jsonify({'success': True, 'message': 'logout test working'}), 200

# -------------------------------
# 4. FORGOT PASSWORD
# -------------------------------
@auth_bp.route('/forgot-password', methods=['POST'])
def forgot_password():
    """نسيت كلمة المرور"""
    try:
        data = request.get_json()
        email = data.get('email')
        
        if not email:
            return jsonify({
                'success': False,
                'message': 'الإيميل مطلوب'
            }), 400
        
        user = User.query.filter_by(email=email).first()
        
        if not user:
            return jsonify({
                'success': False,
                'message': 'لا يوجد مستخدم بهذا الإيميل'
            }), 404
        
        return jsonify({
            'success': True,
            'message': 'تم إرسال تعليمات إعادة تعيين كلمة المرور إلى بريدك الإلكتروني'
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': str(e)
        }), 500

# -------------------------------
# 5. RESET PASSWORD
# -------------------------------
@auth_bp.route('/reset-password', methods=['POST'])
def reset_password():
    """إعادة تعيين كلمة المرور"""
    try:
        data = request.get_json()
        
        email = data.get('email')
        new_password = data.get('new_password')
        confirm_password = data.get('confirm_password')
        
        if not email or not new_password or not confirm_password:
            return jsonify({
                'success': False,
                'message': 'جميع الحقول مطلوبة'
            }), 400
        
        if new_password != confirm_password:
            return jsonify({
                'success': False,
                'message': 'كلمة المرور غير متطابقة'
            }), 400
        
        user = User.query.filter_by(email=email).first()
        
        if not user:
            return jsonify({
                'success': False,
                'message': 'لا يوجد مستخدم بهذا الإيميل'
            }), 404
        
        user.password_hash = generate_password_hash(new_password)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'تم إعادة تعيين كلمة المرور بنجاح'
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': str(e)
        }), 500

# -------------------------------
# TEST ROUTE
# -------------------------------
@auth_bp.route('/test', methods=['GET'])
def test():
    return jsonify({'success': True, 'message': 'Auth routes working!'}), 200