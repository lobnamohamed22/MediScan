import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from extensions import db
from models.user import User
from models.prescription import Prescription
from flask_jwt_extended import create_access_token

app = create_app()

with app.app_context():
    # Find the patient user to simulate the identity
    patient = User.query.filter_by(role='patient').first()
    if not patient:
        print("No patient user found!")
        sys.exit(1)
        
    patient_token = create_access_token(identity=patient.user_id)
    print(f"Simulating request as patient: {patient.email} ({patient.user_id})")

client = app.test_client()
res = client.get('/api/prescriptions', headers={'Authorization': f'Bearer {patient_token}'})
print(f"GET /api/prescriptions: Status {res.status_code}")
data = res.get_json()

with app.app_context():
    # Verify the target prescriptions in the DB
    target_images = [
        "/uploads/prescriptions/presc_58e4dfb2-a2e3-4ffe-b12e-6c8f530167ae.jpg",
        "/uploads/prescriptions/presc_664ff0c6-d1b6-4e51-a824-3db80a94f93d.jpg"
    ]
    for img in target_images:
        p = Prescription.query.filter_by(image_url=img, user_id=patient.user_id).first()
        if p:
            meds = [m.medicine_name for m in p.medicines_list]
            print(f"Image: {img} | Extracted Text: {p.extracted_text} | Medicines: {meds}")
        else:
            print(f"Image: {img} | NOT FOUND in DB!")
