import sys
import os

# Add backend to python path
sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from app import create_app
from extensions import db
from models.medicine import MedicineInfo

app = create_app()

with app.app_context():
    print("Enforcing strict medical placeholder icon fallback in database...")
    
    all_meds = MedicineInfo.query.all()
    healed_count = 0
    
    for m in all_meds:
        med_name_lower = m.medicine_name.lower()
        is_exact_medicine = (
            "convent" in med_name_lower or
            "recox" in med_name_lower or
            "recori" in med_name_lower or
            "sulf" in med_name_lower
        )
        if not is_exact_medicine and m.medicine_image is not None:
            m.medicine_image = None
            healed_count += 1
            
    db.session.commit()
    print(f"\nSuccessfully healed {healed_count} database medicine records (preserved custom exact package images)!")
