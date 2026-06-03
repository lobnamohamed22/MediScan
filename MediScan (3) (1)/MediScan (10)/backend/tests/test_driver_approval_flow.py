import sys
import json
import uuid

sys.path.append('c:/Users/lenovo/Downloads/MediScan (4) (1) (1)/MediScan (3) (1)/MediScan (10)/backend')

from app import create_app
from extensions import db
from models.user import User
from flask_jwt_extended import create_access_token

def run_driver_flow_test():
    app = create_app()
    client = app.test_client()
    
    with app.app_context():
        print("=== DRIVER APPROVAL FLOW TEST ===")
        
        # 1. Register a new delivery driver
        driver_email = f"driver_test_{uuid.uuid4().hex[:6]}@mediscan.com"
        driver_phone = f"015{str(uuid.uuid4().int)[:8]}"
        
        register_payload = {
            'name': 'Test Driver Approval Flow',
            'email': driver_email,
            'password': 'password123',
            'phone': driver_phone,
            'role': 'delivery'
        }
        
        res_register = client.post('/api/auth/register', json=register_payload)
        print(f"1. Registration request: Status {res_register.status_code}")
        assert res_register.status_code == 201
        
        reg_body = res_register.get_json()
        driver_id = reg_body['user'].get('user_id')
        print(f"   Registered Driver ID: {driver_id}")
        
        # 2. Verify driver is initially NOT verified in the database
        driver_db = User.query.get(driver_id)
        print(f"2. Database verification state: {driver_db.is_verified} (Expected: False)")
        assert driver_db.is_verified is False
        
        # 3. Verify pending driver login returns is_verified = False
        login_payload = {
            'email': driver_email,
            'password': 'password123'
        }
        res_login_pending = client.post('/api/auth/login', json=login_payload)
        print(f"3. Login request as pending driver: Status {res_login_pending.status_code}")
        assert res_login_pending.status_code == 200
        
        login_pending_body = res_login_pending.get_json()
        is_verified_login = login_pending_body['user'].get('is_verified')
        name_login = login_pending_body['user'].get('name')
        print(f"   Response attributes: is_verified = {is_verified_login} | name = {name_login}")
        assert is_verified_login is False
        assert name_login == 'Test Driver Approval Flow'
        
        # 4. Admin approval flow
        # Get admin user to generate token
        admin = User.query.filter_by(role='admin').first()
        if not admin:
            print("   ERROR: Admin user not found in database to authorize approval!")
            sys.exit(1)
            
        admin_token = create_access_token(identity=admin.user_id)
        
        # Patch user verified status as admin
        patch_payload = {
            'is_verified': True
        }
        res_patch = client.patch(
            f'/api/admin/users/{driver_id}',
            json=patch_payload,
            headers={'Authorization': f'Bearer {admin_token}'}
        )
        print(f"4. Admin PATCH /users/{driver_id}: Status {res_patch.status_code}")
        assert res_patch.status_code == 200
        
        # 5. Verify the database value changes correctly
        db.session.refresh(driver_db)
        print(f"5. Database verification state after Admin PATCH: {driver_db.is_verified} (Expected: True)")
        assert driver_db.is_verified is True
        
        # 6. Verify approved driver login returns is_verified = True
        res_login_approved = client.post('/api/auth/login', json=login_payload)
        print(f"6. Login request as approved driver: Status {res_login_approved.status_code}")
        assert res_login_approved.status_code == 200
        
        login_approved_body = res_login_approved.get_json()
        is_verified_approved = login_approved_body['user'].get('is_verified')
        print(f"   Response attributes: is_verified = {is_verified_approved} (Expected: True)")
        assert is_verified_approved is True
        
        # 7. Clean up test user
        db.session.delete(driver_db)
        db.session.commit()
        print("\n=== DRIVER APPROVAL FLOW TEST PASSED SUCCESSFULLY! ===")

if __name__ == '__main__':
    run_driver_flow_test()
