import sys
import os

# Add backend to python path
sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from app import create_app
from extensions import db
from models.medicine import MedicineInfo

app = create_app()

with app.app_context():
    print("--- Listing all medicines in medicine_info ---")
    meds = MedicineInfo.query.order_by(MedicineInfo.id).all()
    print(f"Total medicines: {len(meds)}")
    for m in meds:
        print(f"ID: {m.id:3d} | Name: '{m.medicine_name}' | Image: '{m.medicine_image}'")

