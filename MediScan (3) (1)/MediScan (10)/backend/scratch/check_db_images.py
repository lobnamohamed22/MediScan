import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from extensions import db
from models.medicine import MedicineInfo

app = create_app()

drugs = [
    "Cozaar 50mg",
    "Januvia 100mg",
    "Prednisolone 5mg",
    "Spironolactone 25mg",
    "Ciprofloxacin 500mg"
]

with app.app_context():
    for d in drugs:
        m = MedicineInfo.query.filter(MedicineInfo.medicine_name.ilike(d)).first()
        if m:
            print(f"Name: {m.medicine_name} | Image: {m.medicine_image}")
        else:
            print(f"Name: {d} | Not Found in Database!")
