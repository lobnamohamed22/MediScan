import os
import sys
import io

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from extensions import db
from models.user import User
from flask_jwt_extended import create_access_token

app = create_app()

with app.app_context():
    patient = User.query.filter_by(role='patient').first()
    if not patient:
        print("No patient user found!")
        sys.exit(1)
    patient_token = create_access_token(identity=patient.user_id)

client = app.test_client()

# Use a real image from the directory
real_image_path = r"c:\Users\lenovo\Downloads\MediScan (4) (1) (1)\MediScan (3) (1)\MediScan (10)\backend\uploads\prescriptions\presc_58e4dfb2-a2e3-4ffe-b12e-6c8f530167ae.jpg"
if not os.path.exists(real_image_path):
    print(f"Error: Real image not found at {real_image_path}")
    sys.exit(1)

with open(real_image_path, 'rb') as f:
    real_image_bytes = f.read()

data = {
    'image': (io.BytesIO(real_image_bytes), 'presc_58e4dfb2-a2e3-4ffe-b12e-6c8f530167ae.jpg')
}

print("Triggering POST /api/prescriptions/upload with real image...")
res = client.post(
    '/api/prescriptions/upload',
    data=data,
    headers={'Authorization': f'Bearer {patient_token}'},
    content_type='multipart/form-data'
)

print(f"Status Code: {res.status_code}")
print("Response JSON/Body:")
try:
    print(res.get_json())
except Exception:
    print(res.data)
