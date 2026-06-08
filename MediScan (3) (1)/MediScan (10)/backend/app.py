from dotenv import load_dotenv
load_dotenv()
from flask import Flask, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager
from flask_cors import CORS
from config import Config
from extensions import db, jwt
import os

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)
    app.url_map.strict_slashes = False
    
    # إعدادات JWT إضافية
    app.config['JWT_IDENTITY_CLAIM'] = 'sub'
    app.config['JWT_TOKEN_LOCATION'] = ['headers']
    
    # تهيئة الإضافات
    db.init_app(app)
    jwt.init_app(app)
    CORS(app)
    
    # إنشاء مجلدات الرفع لو مش موجودة
    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
    os.makedirs(os.path.join(app.config['UPLOAD_FOLDER'], 'profiles'), exist_ok=True)
    os.makedirs(os.path.join(app.config['UPLOAD_FOLDER'], 'prescriptions'), exist_ok=True)
    
    # -------------------------------
    # تسجيل جميع الـ Blueprints (APIs)
    # -------------------------------
    
    # Auth APIs
    from routes.auth import auth_bp 
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    
    # User APIs
    from routes.user import user_bp
    app.register_blueprint(user_bp, url_prefix='/api/users')
    
    # Prescription APIs
    from routes.prescriptions import prescriptions_bp
    app.register_blueprint(prescriptions_bp, url_prefix='/api/prescriptions')
    
    # Pharmacy APIs
    from routes.pharmacies import pharmacies_bp
    app.register_blueprint(pharmacies_bp, url_prefix='/api/pharmacies')
    
    # Medicine APIs
    from routes.medicines import medicines_bp
    app.register_blueprint(medicines_bp, url_prefix='/api/medicines')
    
    # Reservation APIs
    from routes.reservations import reservations_bp
    app.register_blueprint(reservations_bp, url_prefix='/api/reservations')
    
    # Notification APIs
    from routes.notifications import notifications_bp
    app.register_blueprint(notifications_bp, url_prefix='/api/notifications')

    # Settings APIs
    from routes.settings import settings_bp
    app.register_blueprint(settings_bp, url_prefix='/api/settings')
    
    # Chatbot APIs 
    from routes.chatbot import chatbot_bp 
    app.register_blueprint(chatbot_bp, url_prefix='/api/chatbot')

    # Orders APIs
    from routes.orders import orders_bp
    app.register_blueprint(orders_bp, url_prefix='/api/orders')

    # Payments APIs
    from routes.payments import payments_bp
    app.register_blueprint(payments_bp, url_prefix='/api/payments')
    
    # Cart APIs
    from routes.cart import cart_bp
    app.register_blueprint(cart_bp, url_prefix='/api/cart')
    
    # Wallet APIs
    from routes.wallet import wallet_bp
    app.register_blueprint(wallet_bp, url_prefix='/api/wallet')
    
    # Admin APIs
    from routes.admin import admin_bp
    app.register_blueprint(admin_bp, url_prefix='/api/admin')
    
    # -------------------------------
    # الصفحة الرئيسية للتجربة
    # -------------------------------

    @app.route('/')
    def home():
        return jsonify({
            'message': 'Medi Scan Backend is running!',
            'status': 'success',
            'version': '1.0.0',
            'endpoints': {
                'auth': '/api/auth',
                'users': '/api/users',
                'prescriptions': '/api/prescriptions',
                'pharmacies': '/api/pharmacies',
                'medicines': '/api/medicines',
                'reservations': '/api/reservations',
                'notifications': '/api/notifications',
                'settings': '/api/settings',
                'chatbot': '/api/chatbot',
                'orders': '/api/orders',
                'admin': '/api/admin'
            }
        }), 200
    
    # -------------------------------
    # Serving Uploaded Files
    # -------------------------------
    @app.route('/uploads/<path:filename>')
    def serve_uploads(filename):
        from flask import send_from_directory
        return send_from_directory('uploads', filename)

    # -------------------------------
    # Serving Web Dashboards
    # -------------------------------
    @app.route('/admin')
    def admin_dashboard():
        from flask import send_from_directory
        return send_from_directory('static/admin', 'index.html')

    @app.route('/admin/<path:path>')
    def admin_static(path):
        from flask import send_from_directory
        return send_from_directory('static/admin', path)

    @app.route('/pharmacy')
    def pharmacy_dashboard():
        from flask import send_from_directory
        return send_from_directory('static/pharmacy', 'index.html')

    @app.route('/pharmacy/<path:path>')
    def pharmacy_static(path):
        from flask import send_from_directory
        return send_from_directory('static/pharmacy', path)

    @app.route('/delivery')
    def delivery_dashboard():
        from flask import send_from_directory
        return send_from_directory('static/delivery', 'index.html')

    @app.route('/delivery/<path:path>')
    def delivery_static(path):
        from flask import send_from_directory
        return send_from_directory('static/delivery', path)

    # -------------------------------
    # روابط اختبارية للتأكد
    # -------------------------------
    
    @app.route('/orders-test')
    def orders_test():
        return jsonify({'success': True, 'message': 'Orders test works directly'}), 200

    @app.route('/test-flask')
    def test_flask():
        return jsonify({'success': True, 'message': 'Flask is working!'}), 200

    @app.route('/simple')
    def simple():
        return jsonify({'success': True, 'message': 'Simple route works'}), 200
    
    @app.route('/ping')
    def ping():
        return "pong"

    # -------------------------------
    # إنشاء جداول قاعدة البيانات
    # -------------------------------
    with app.app_context():
        try:
            db.create_all()
            from sqlalchemy import text
            try:
                db.session.execute(text("ALTER TABLE users ADD COLUMN reward_points INT DEFAULT 0"))
                db.session.commit()
            except Exception:
                db.session.rollback()
            try:
                db.session.execute(text("ALTER TABLE users ADD COLUMN wallet_balance DECIMAL(10,2) DEFAULT 0.00"))
                db.session.commit()
            except Exception:
                db.session.rollback()
            try:
                db.session.execute(text("ALTER TABLE medicine_info ADD COLUMN status VARCHAR(50) DEFAULT 'Verified'"))
                db.session.commit()
            except Exception:
                db.session.rollback()
            try:
                db.session.execute(text("ALTER TABLE delivery_orders ADD COLUMN customer_lat DOUBLE NULL"))
                db.session.commit()
            except Exception:
                db.session.rollback()
            try:
                db.session.execute(text("ALTER TABLE delivery_orders ADD COLUMN customer_lng DOUBLE NULL"))
                db.session.commit()
            except Exception:
                db.session.rollback()
            try:
                db.session.execute(text("ALTER TABLE delivery_orders MODIFY COLUMN status ENUM('assigned', 'picked_up', 'in_transit', 'delivered', 'pending', 'preparing', 'ready', 'rejected') DEFAULT 'assigned'"))
                db.session.commit()
            except Exception:
                db.session.rollback()
            try:
                db.session.execute(text("ALTER TABLE family_profiles ADD COLUMN gender VARCHAR(10) NULL"))
                db.session.commit()
            except Exception:
                db.session.rollback()
            try:
                db.session.execute(text("ALTER TABLE family_profiles ADD COLUMN phone_number VARCHAR(20) NULL"))
                db.session.commit()
            except Exception:
                db.session.rollback()
            print(" Database tables created successfully!")
        except Exception as e:
            print(f" Warning: Could not connect to database on startup: {e}")
        
        print(" All blueprints registered:")
        print("   - /api/auth")
        print("   - /api/users")
        print("   - /api/prescriptions")
        print("   - /api/pharmacies")
        print("   - /api/medicines")
        print("   - /api/reservations")
        print("   - /api/notifications")
        print("   - /api/settings")
        print("   - /api/chatbot")
        print("   - /api/orders")
    
    return app

app = create_app()

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000, use_reloader=False)