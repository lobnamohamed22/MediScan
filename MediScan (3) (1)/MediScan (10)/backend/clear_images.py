import sys
import os

# Add backend to python path
sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from app import create_app
from extensions import db
from models.medicine import MedicineInfo

app = create_app()

with app.app_context():
    print("Clearing generic medicine images from database...")
    
    all_meds = MedicineInfo.query.all()
    cleared_count = 0
    
    for m in all_meds:
        # Clear any generic/random image URLs
        if m.medicine_image is not None:
            m.medicine_image = None
            cleared_count += 1
            
    db.session.commit()
    print(f"\nSuccessfully cleared {cleared_count} medicine images to use the medical placeholder icon!")
