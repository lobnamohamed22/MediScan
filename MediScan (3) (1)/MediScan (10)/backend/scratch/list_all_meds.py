import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from extensions import db
from models.medicine import MedicineInfo

app = create_app()

with app.app_context():
    meds = MedicineInfo.query.all()
    print(f"Total medicines: {len(meds)}")
    for m in meds:
        print(f"ID: {m.id} | Name: {m.medicine_name} | Image: {m.medicine_image}")
