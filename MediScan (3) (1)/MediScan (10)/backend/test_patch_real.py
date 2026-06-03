import sys
sys.path.append('c:/Users/lenovo/Downloads/MediScan (4) (1) (1)/MediScan (3) (1)/MediScan (10)/backend')

from app import create_app
from flask_jwt_extended import create_access_token
from models.user import User
from flask import json

app = create_app()

with app.app_context():
    users = User.query.all()
    client = app.test_client()
    
    for u in users:
        token = create_access_token(identity=u.user_id)
        headers = {
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {token}'
        }
        
        # We try to update their profile with their own existing details
        payload = {
            'name': u.full_name,
            'phone': u.phone,
            'email': u.email,
            'date_of_birth': u.date_of_birth.isoformat() if u.date_of_birth else '',
            'gender': u.gender or 'Male',
            'address': '',
            'city': '',
            'governorate': ''
        }
        
        response = client.patch(
            '/api/users/profile',
            data=json.dumps(payload),
            headers=headers
        )
        
        print(f"User ID: '{u.user_id}', Email: '{u.email}', Status: {response.status_code}")
        if response.status_code != 200:
            print("  FAIL Body:", json.dumps(response.get_json(), ensure_ascii=True))
