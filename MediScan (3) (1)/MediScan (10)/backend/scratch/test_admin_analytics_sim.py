import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from extensions import db
from flask_jwt_extended import create_access_token
from models.user import User

app = create_app()

with app.app_context():
    # Find or create an admin user for testing
    admin = User.query.filter_by(role='admin').first()
    if not admin:
        print("Creating a temporary admin user...")
        admin = User(
            email="admin_temp@mediscan.com",
            phone="01000000000",
            password_hash="temp_hash",
            full_name="Temp Admin",
            role="admin"
        )
        db.session.add(admin)
        db.session.commit()
        
    token = create_access_token(identity=str(admin.user_id))
    
    with app.test_client() as client:
        headers = {'Authorization': f'Bearer {token}'}
        res = client.get('/api/admin/analytics', headers=headers)
        print("Status Code:", res.status_code)
        print("Response JSON:")
        print(res.json)
        
        # Verify the assertion
        assert res.json['success'] is True
        assert res.json['data']['total_pharmacies'] == 50
        print("\nSUCCESS: total_pharmacies is exactly 50!")
