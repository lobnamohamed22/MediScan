import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from extensions import db
from models.prescription import Prescription

app = create_app()

with app.app_context():
    prescs = Prescription.query.all()
    print(f"Total prescriptions in DB: {len(prescs)}")
    for p in prescs:
        # Check medicines list
        meds = [m.medicine_name for m in p.medicines_list]
        for m in meds:
            if 'venusen' in m.lower():
                print(f"ID: {p.prescription_id} | Image: {p.image_url} | Extracted Text: {p.extracted_text} | Medicines: {meds}")
